package com.example.neo

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.security.MessageDigest

class InspectorAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        private var instance: InspectorAccessibilityService? = null

        fun getInstance(): InspectorAccessibilityService? = instance

        private const val THROTTLE_MS = 200L
        private const val MIN_SIZE_DP = 4
        private const val MAX_NODES = 50
        private const val MAX_DEPTH = 10
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastEventTime = 0L
    private var isInspectorEnabled = false
    private var overlayVisible = false
    private var overlayView: InspectorOverlayView? = null
    private var windowManager: android.view.WindowManager? = null
    private var currentNodes: List<UiNode> = emptyList()
    private var selectedNodeId: String? = null
    private var selectedNodeSelector: NodeSelector? = null // Armazenar seletor como fallback
    private var aimPosition: android.graphics.Point? = null
    
    // Cache para logging: armazena último texto logado por node ID
    private val loggedTexts = mutableMapOf<String, String>()
    private var lastLogTime = 0L
    private val LOG_THROTTLE_MS = 500L // Throttle de 500ms para logs

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        windowManager = getSystemService(WINDOW_SERVICE) as? android.view.WindowManager
    }

    override fun onDestroy() {
        instance = null
        removeOverlayView()
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!isInspectorEnabled) return

        val currentTime = System.currentTimeMillis()
        if (currentTime - lastEventTime < THROTTLE_MS) {
            return
        }
        lastEventTime = currentTime

        val rootNode = rootInActiveWindow ?: return
        try {
            val nodes = traverseTree(rootNode)
            currentNodes = nodes
            
            // Se temos um node selecionado, verificar se ainda existe na nova árvore
            if (selectedNodeId != null) {
                val stillExists = nodes.any { it.id == selectedNodeId }
                if (!stillExists && selectedNodeSelector != null) {
                    // Tentar encontrar pelo seletor na nova árvore
                    val found = nodes.firstOrNull { node ->
                        node.selector.className == selectedNodeSelector!!.className &&
                        node.selector.viewId == selectedNodeSelector!!.viewId
                    }
                    if (found != null) {
                        selectedNodeId = found.id
                        overlayView?.setSelectedNode(selectedNodeId)
                    } else {
                        // Node não existe mais, limpar seleção
                        selectedNodeId = null
                        selectedNodeSelector = null
                        overlayView?.setSelectedNode(null)
                    }
                } else if (!stillExists) {
                    selectedNodeId = null
                    selectedNodeSelector = null
                    overlayView?.setSelectedNode(null)
                }
            }
            
            updateOverlayNodes(nodes)
            // Enviar para Flutter via EventChannel será feito pelo AccessibilityPlugin
        } catch (e: Exception) {
            // Log error mas não crashar
        } finally {
            rootNode.recycle()
        }
    }

    override fun onInterrupt() {
        // Não fazer nada ou limpar recursos se necessário
    }

    private fun traverseTree(root: AccessibilityNodeInfo): List<UiNode> {
        val nodes = mutableListOf<UiNode>()
        val screenBounds = getScreenBounds()
        
        traverseNode(root, nodes, screenBounds, 0)
        
        // Priorizar: clickable > scrollable > focusable
        val sorted = nodes.sortedWith(compareBy(
            { !it.clickable },
            { !it.scrollable },
            { !it.enabled }
        ))
        
        return sorted.take(MAX_NODES)
    }

    private fun traverseNode(
        node: AccessibilityNodeInfo?,
        nodes: MutableList<UiNode>,
        screenBounds: Rect,
        depth: Int
    ) {
        if (node == null || depth > MAX_DEPTH) return

        try {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)

            // Filtrar: apenas visíveis, bounds válidos
            if (isNodeVisible(bounds, screenBounds)) {
                val uiNode = extractNodeData(node, bounds)
                if (uiNode != null) {
                    nodes.add(uiNode)
                }
            }

            // Recursão para filhos
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    traverseNode(child, nodes, screenBounds, depth + 1)
                    child.recycle()
                }
            }
        } catch (e: Exception) {
            // Ignorar erros em nodes individuais
        }
    }

    private fun isNodeVisible(bounds: Rect, screenBounds: Rect): Boolean {
        if (!Rect.intersects(bounds, screenBounds)) return false
        
        val width = bounds.width()
        val height = bounds.height()
        val minSizePx = dpToPx(MIN_SIZE_DP)
        
        return width >= minSizePx && height >= minSizePx
    }

    private fun extractNodeData(node: AccessibilityNodeInfo, bounds: Rect): UiNode? {
        try {
            val className = node.className?.toString() ?: "Unknown"
            val packageName = node.packageName?.toString() ?: ""
            val viewIdResourceName = node.viewIdResourceName
            
            // Gerar selector
            val selector = NodeSelector(
                viewId = viewIdResourceName,
                className = className,
                path = null
            )
            
            // Gerar ID estável
            val id = generateStableId(packageName, className, bounds, viewIdResourceName)
            
            // Verificar se é campo de texto
            val isTextField = node.isEditable || className.contains("EditText", ignoreCase = true)
            val isPassword = node.isPassword
            
            // Extrair texto: node.text ou contentDescription
            var extractedText: String? = null
            if (!isPassword) { // Não extrair texto de campos de senha
                val nodeText = node.text?.toString()
                val contentDesc = node.contentDescription?.toString()
                
                // Priorizar node.text, depois contentDescription
                extractedText = when {
                    !nodeText.isNullOrBlank() -> nodeText
                    !contentDesc.isNullOrBlank() -> contentDesc
                    else -> null
                }
                
                // Logging inteligente: só loga se o texto mudou ou é novo
                if (!extractedText.isNullOrBlank()) {
                    logTextIfChanged(id, bounds, extractedText)
                }
            }
            
            val uiNode = UiNode(
                id = id,
                selector = selector,
                bounds = Rect(bounds),
                className = className,
                packageName = packageName,
                viewIdResourceName = viewIdResourceName,
                clickable = node.isClickable,
                enabled = node.isEnabled,
                scrollable = node.isScrollable,
                isTextField = isTextField && !isPassword,
                text = extractedText
            )
            
            return uiNode
        } catch (e: Exception) {
            return null
        }
    }

    private fun generateStableId(
        packageName: String,
        className: String,
        bounds: Rect,
        viewId: String?
    ): String {
        val data = "$packageName|$className|${bounds.left},${bounds.top},${bounds.right},${bounds.bottom}|${viewId ?: ""}"
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(data.toByteArray())
        return hash.joinToString("") { "%02x".format(it) }.take(16)
    }

    private fun getScreenBounds(): Rect {
        val display = windowManager?.defaultDisplay ?: return Rect(0, 0, 1080, 2340) // Fallback
        val size = android.graphics.Point()
        // Usar getRealSize para incluir barra de status e áreas do sistema
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN_MR1) {
            display.getRealSize(size)
        } else {
            display.getSize(size)
        }
        return Rect(0, 0, size.x, size.y)
    }

    private fun getStatusBarHeight(): Int {
        var result = 0
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId > 0) {
            result = resources.getDimensionPixelSize(resourceId)
        }
        return result
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }

    /**
     * Loga texto apenas se mudou ou é novo, com throttle para evitar spam
     */
    private fun logTextIfChanged(nodeId: String, bounds: Rect, text: String) {
        val currentTime = System.currentTimeMillis()
        
        // Throttle: só permite logs a cada LOG_THROTTLE_MS
        if (currentTime - lastLogTime < LOG_THROTTLE_MS) {
            return
        }
        
        // Verificar se o texto mudou para este node
        val lastText = loggedTexts[nodeId]
        if (lastText != text) {
            // Texto mudou ou é novo - logar
            android.util.Log.d("InspectorAccessibility", 
                "Box: [${bounds.left}, ${bounds.top}, ${bounds.right}, ${bounds.bottom}] | Text: \"$text\"")
            
            // Atualizar cache
            loggedTexts[nodeId] = text
            lastLogTime = currentTime
            
            // Limpar cache antigo (manter apenas últimos 100 nodes para não consumir muita memória)
            if (loggedTexts.size > 100) {
                val keysToRemove = loggedTexts.keys.take(loggedTexts.size - 100)
                keysToRemove.forEach { loggedTexts.remove(it) }
            }
        }
    }

    // Métodos públicos para controle via Plugin

    fun setInspectorEnabled(enabled: Boolean) {
        isInspectorEnabled = enabled
        if (!enabled) {
            removeOverlayView()
            currentNodes = emptyList()
            selectedNodeId = null
            selectedNodeSelector = null
            // Limpar cache de logs quando desabilitar
            loggedTexts.clear()
        }
    }

    fun setOverlayVisible(visible: Boolean) {
        overlayVisible = visible
        if (visible) {
            createOverlayView()
        } else {
            removeOverlayView()
        }
    }

    fun setTextVisible(visible: Boolean) {
        overlayView?.setTextVisible(visible)
    }

    fun setAimPosition(x: Int, y: Int) {
        aimPosition = android.graphics.Point(x, y)
        overlayView?.setAimPosition(x, y)
        overlayView?.invalidate()
    }

    fun selectNode(nodeId: String) {
        selectedNodeId = nodeId
        // Armazenar o seletor do node selecionado para usar como fallback
        selectedNodeSelector = currentNodes.find { it.id == nodeId }?.selector
        overlayView?.setSelectedNode(nodeId)
        overlayView?.invalidate()
    }

    fun clickSelected(): Boolean {
        val nodeId = selectedNodeId ?: return false
        
        // Tentar encontrar pelo ID primeiro
        var node = findNodeById(nodeId)
        
        // Se não encontrar pelo ID (tela mudou), tentar pelo seletor
        if (node == null && selectedNodeSelector != null) {
            node = findNodeBySelector(selectedNodeSelector!!)
            // Se encontrou pelo seletor, atualizar o selectedNodeId
            if (node != null) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                val className = node.className?.toString() ?: ""
                val packageName = node.packageName?.toString() ?: ""
                val viewId = node.viewIdResourceName
                selectedNodeId = generateStableId(packageName, className, bounds, viewId)
            }
        }
        
        if (node == null) return false
        
        return try {
            if (!node.isClickable && !node.isEnabled) {
                node.recycle()
                return false
            }
            val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            node.recycle()
            result
        } catch (e: Exception) {
            try {
                node.recycle()
            } catch (ignored: Exception) {}
            false
        }
    }

    fun scrollForward(): Boolean {
        val nodeId = selectedNodeId ?: return false
        
        // Tentar encontrar pelo ID primeiro
        var node = findNodeById(nodeId)
        
        // Se não encontrar pelo ID (tela mudou), tentar pelo seletor
        if (node == null && selectedNodeSelector != null) {
            node = findNodeBySelector(selectedNodeSelector!!)
            if (node != null) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                val className = node.className?.toString() ?: ""
                val packageName = node.packageName?.toString() ?: ""
                val viewId = node.viewIdResourceName
                selectedNodeId = generateStableId(packageName, className, bounds, viewId)
            }
        }
        
        if (node == null) return false
        
        return try {
            if (!node.isScrollable) {
                node.recycle()
                return false
            }
            val result = node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
            node.recycle()
            result
        } catch (e: Exception) {
            try {
                node.recycle()
            } catch (ignored: Exception) {}
            false
        }
    }

    fun scrollBackward(): Boolean {
        val nodeId = selectedNodeId ?: return false
        
        // Tentar encontrar pelo ID primeiro
        var node = findNodeById(nodeId)
        
        // Se não encontrar pelo ID (tela mudou), tentar pelo seletor
        if (node == null && selectedNodeSelector != null) {
            node = findNodeBySelector(selectedNodeSelector!!)
            if (node != null) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                val className = node.className?.toString() ?: ""
                val packageName = node.packageName?.toString() ?: ""
                val viewId = node.viewIdResourceName
                selectedNodeId = generateStableId(packageName, className, bounds, viewId)
            }
        }
        
        if (node == null) return false
        
        return try {
            if (!node.isScrollable) {
                node.recycle()
                return false
            }
            val result = node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)
            node.recycle()
            result
        } catch (e: Exception) {
            try {
                node.recycle()
            } catch (ignored: Exception) {}
            false
        }
    }

    fun tap(x: Int, y: Int, durationMs: Int = 100) {
        val path = android.graphics.Path().apply {
            moveTo(x.toFloat(), y.toFloat())
        }
        val gesture = android.accessibilityservice.GestureDescription.Builder()
            .addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, durationMs.toLong()))
            .build()
        
        dispatchGesture(gesture, object : android.accessibilityservice.AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: android.accessibilityservice.GestureDescription?) {
                super.onCompleted(gestureDescription)
            }

            override fun onCancelled(gestureDescription: android.accessibilityservice.GestureDescription?) {
                super.onCancelled(gestureDescription)
            }
        }, null)
    }

    fun swipe(x1: Int, y1: Int, x2: Int, y2: Int, durationMs: Int = 300) {
        val path = android.graphics.Path().apply {
            moveTo(x1.toFloat(), y1.toFloat())
            lineTo(x2.toFloat(), y2.toFloat())
        }
        val gesture = android.accessibilityservice.GestureDescription.Builder()
            .addStroke(android.accessibilityservice.GestureDescription.StrokeDescription(path, 0, durationMs.toLong()))
            .build()
        
        dispatchGesture(gesture, object : android.accessibilityservice.AccessibilityService.GestureResultCallback() {
            override fun onCompleted(gestureDescription: android.accessibilityservice.GestureDescription?) {
                super.onCompleted(gestureDescription)
            }

            override fun onCancelled(gestureDescription: android.accessibilityservice.GestureDescription?) {
                super.onCancelled(gestureDescription)
            }
        }, null)
    }

    fun getCurrentNodes(): List<UiNode> = currentNodes

    private fun findNodeById(nodeId: String): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        return findNodeByIdRecursive(root, nodeId)
    }

    private fun findNodeBySelector(selector: NodeSelector): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        return findNodeBySelectorRecursive(root, selector)
    }

    private fun findNodeByIdRecursive(node: AccessibilityNodeInfo?, targetId: String): AccessibilityNodeInfo? {
        if (node == null) return null

        try {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            val className = node.className?.toString() ?: ""
            val packageName = node.packageName?.toString() ?: ""
            val viewId = node.viewIdResourceName
            
            val currentId = generateStableId(packageName, className, bounds, viewId)
            if (currentId == targetId) {
                // Retornar uma cópia do node para evitar que seja reciclado
                return AccessibilityNodeInfo.obtain(node)
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    val found = findNodeByIdRecursive(child, targetId)
                    child.recycle()
                    if (found != null) {
                        return found
                    }
                }
            }
        } catch (e: Exception) {
            // Ignorar
        }

        return null
    }

    private fun findNodeBySelectorRecursive(node: AccessibilityNodeInfo?, selector: NodeSelector): AccessibilityNodeInfo? {
        if (node == null) return null

        try {
            val className = node.className?.toString() ?: ""
            val viewId = node.viewIdResourceName
            
            // Verificar se o node corresponde ao seletor
            val classNameMatches = className == selector.className
            val viewIdMatches = when {
                selector.viewId == null -> viewId == null
                else -> viewId == selector.viewId
            }
            
            if (classNameMatches && viewIdMatches) {
                // Retornar uma cópia do node
                return AccessibilityNodeInfo.obtain(node)
            }

            // Buscar nos filhos
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    val found = findNodeBySelectorRecursive(child, selector)
                    child.recycle()
                    if (found != null) {
                        return found
                    }
                }
            }
        } catch (e: Exception) {
            // Ignorar
        }

        return null
    }

    private fun createOverlayView() {
        if (overlayView != null) return

        val wm = windowManager ?: return
        val statusBarHeight = getStatusBarHeight()
        overlayView = InspectorOverlayView(this).apply {
            setStatusBarHeight(statusBarHeight)
            setNodes(currentNodes)
            if (selectedNodeId != null) {
                setSelectedNode(selectedNodeId!!)
            }
            if (aimPosition != null) {
                setAimPosition(aimPosition!!.x, aimPosition!!.y)
            }
        }

        val overlayType = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            android.view.WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else {
            android.view.WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = android.view.WindowManager.LayoutParams(
            android.view.WindowManager.LayoutParams.MATCH_PARENT,
            android.view.WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT
        )
        params.x = 0
        params.y = 0
        params.gravity = android.view.Gravity.TOP or android.view.Gravity.START

        try {
            wm.addView(overlayView, params)
        } catch (e: Exception) {
            overlayView = null
        }
    }

    private fun removeOverlayView() {
        overlayView?.let { view ->
            windowManager?.removeView(view)
            overlayView = null
        }
    }

    private fun updateOverlayNodes(nodes: List<UiNode>) {
        overlayView?.setNodes(nodes)
        if (selectedNodeId != null) {
            overlayView?.setSelectedNode(selectedNodeId!!)
        }
        overlayView?.invalidate()
    }
}

