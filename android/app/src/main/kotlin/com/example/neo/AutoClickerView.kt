package com.example.neo

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class AutoClickerView(
    context: Context,
    private val controller: AutoClickerController,
    private val windowManager: WindowManager,
    private val onClose: () -> Unit
) : LinearLayout(context) {

    private val params: WindowManager.LayoutParams = WindowManager.LayoutParams().apply {
        width = WindowManager.LayoutParams.WRAP_CONTENT
        height = WindowManager.LayoutParams.WRAP_CONTENT
        type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        format = android.graphics.PixelFormat.TRANSLUCENT
        gravity = Gravity.TOP or Gravity.START
        x = dp(24)
        y = dp(200)
    }

    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    private var isPlaying = false
    private val pointViews = mutableListOf<ClickPointView>()
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    init {
        orientation = HORIZONTAL
        val background = GradientDrawable()
        background.cornerRadius = dp(24).toFloat()
        background.setColor(0xFF111827.toInt())
        background.setStroke(dp(1), 0xFF374151.toInt())
        this.background = background
        elevation = dp(8).toFloat()
        setPadding(dp(8), dp(4), dp(8), dp(4))

        // Minimize Button
        var isMinimized = false
        val contentContainer = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        
        val minBtn = createButton(android.R.drawable.presence_video_online, Color.WHITE) {
            isMinimized = !isMinimized
            if (isMinimized) {
                contentContainer.visibility = GONE
                (it as ImageView).setImageResource(android.R.drawable.presence_video_busy)
            } else {
                contentContainer.visibility = VISIBLE
                (it as ImageView).setImageResource(android.R.drawable.presence_video_online)
            }
        }
        addView(minBtn)
        addView(contentContainer)
        
        // Armazenar posições dos pontos para restaurar depois
        val pointPositions = mutableMapOf<ClickPointView, Pair<Int, Int>>()
        
        // Função para minimizar/maximizar durante execução
        fun minimizeForExecution() {
            contentContainer.visibility = GONE
            minBtn.visibility = GONE
            // Armazenar posições e remover pontos da tela
            pointViews.forEach { pointView ->
                val position = pointView.getPosition()
                pointPositions[pointView] = position
                pointView.hide()
            }
        }
        
        fun restoreFromExecution() {
            contentContainer.visibility = VISIBLE
            minBtn.visibility = VISIBLE
            // Restaurar pontos nas posições armazenadas
            pointViews.forEach { pointView ->
                val position = pointPositions[pointView]
                if (position != null) {
                    pointView.show(position.first, position.second)
                }
            }
            pointPositions.clear()
        }

        // Drag handle / Move icon
        contentContainer.addView(createButton(android.R.drawable.ic_menu_sort_by_size, Color.GRAY) {
            // Drag logic handled in touch listener
        }.apply {
            setOnTouchListener { _, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager.updateViewLayout(this@AutoClickerView, params)
                        true
                    }
                    else -> false
                }
            }
        })

        // Play / Pause - Movido para fora do contentContainer para ficar sempre visível durante execução
        val playBtn = createButton(android.R.drawable.ic_media_play, Color.GREEN) {
            isPlaying = !isPlaying
            if (isPlaying) {
                (it as ImageView).setImageResource(android.R.drawable.ic_media_pause)
                it.setColorFilter(Color.YELLOW)
                android.widget.Toast.makeText(context, "AutoClicker Iniciado", android.widget.Toast.LENGTH_SHORT).show()
                pointViews.forEach { v -> v.setInteractive(false) }
                // Minimizar tudo antes de iniciar
                minimizeForExecution()
                controller.start()
            } else {
                (it as ImageView).setImageResource(android.R.drawable.ic_media_play)
                it.setColorFilter(Color.GREEN)
                android.widget.Toast.makeText(context, "AutoClicker Parado", android.widget.Toast.LENGTH_SHORT).show()
                pointViews.forEach { v -> v.setInteractive(true) }
                controller.stop()
                // Restaurar tudo ao pausar
                restoreFromExecution()
            }
        }
        // Adicionar playBtn diretamente ao layout principal (fora do contentContainer)
        addView(playBtn)

        // Add (+)
        contentContainer.addView(createButton(android.R.drawable.ic_input_add, Color.CYAN) {
            val screenWidth = resources.displayMetrics.widthPixels
            val screenHeight = resources.displayMetrics.heightPixels
            val x = screenWidth / 2
            val y = screenHeight / 2
            
            val pointView = ClickPointView(context, pointViews.size, windowManager, { v ->
                showPointSettings(pointViews.indexOf(v))
            }, { v, nx, ny ->
                val action = controller.getActions()[pointViews.indexOf(v)]
                action.x = nx
                action.y = ny
            })
            pointView.show(x, y)
            pointViews.add(pointView)
            controller.addAction(x, y)
        })

        // Back / Undo
        contentContainer.addView(createButton(android.R.drawable.ic_menu_revert, Color.WHITE) {
            if (pointViews.isNotEmpty()) {
                val last = pointViews.removeAt(pointViews.size - 1)
                last.remove()
                controller.removeLastAction()
                updateIndices()
            }
        })

        // Settings
        contentContainer.addView(createButton(android.R.drawable.ic_menu_preferences, Color.GRAY) {
            showGlobalSettings()
        })

        // Close (X)
        contentContainer.addView(createButton(android.R.drawable.ic_menu_close_clear_cancel, Color.RED) {
            hide()
            pointViews.forEach { it.remove() }
            pointViews.clear()
            controller.clearActions()
            onClose()
        })

        // Setup controller callbacks
        controller.onActionStarted = { index ->
            // Remove highlight from all, then highlight current
            pointViews.forEachIndexed { i, v -> v.highlight(i == index) }
        }
        controller.onActionFinished = {
            isPlaying = false
            playBtn.setImageResource(android.R.drawable.ic_media_play)
            playBtn.setColorFilter(Color.GREEN)
            pointViews.forEach { v ->
                v.highlight(false)
                v.setInteractive(true)
            }
            // Restaurar tudo quando a execução terminar
            restoreFromExecution()
            android.widget.Toast.makeText(context, "Sequência Finalizada", android.widget.Toast.LENGTH_SHORT).show()
        }
    }

    private fun showGlobalSettings() {
        val menu = LinearLayout(context)
        menu.orientation = VERTICAL
        val background = GradientDrawable()
        background.cornerRadius = dp(16).toFloat()
        background.setColor(0xFF111827.toInt())
        background.setStroke(dp(2), 0xFF3B82F6.toInt())
        menu.background = background
        menu.setPadding(dp(20), dp(20), dp(20), dp(20))

        val title = TextView(context)
        title.text = "CONFIGURAÇÕES GERAIS"
        title.setTextColor(Color.WHITE)
        title.textSize = 18f
        title.typeface = android.graphics.Typeface.DEFAULT_BOLD
        title.gravity = Gravity.CENTER
        title.setPadding(0, 0, 0, dp(16))
        menu.addView(title)

        // Infinite Loop Toggle
        val loopToggle = createStyledTextButton(
            if (controller.isInfiniteLoop) "LOOP INFINITO: LIGADO" else "LOOP INFINITO: DESLIGADO",
            if (controller.isInfiniteLoop) 0xFF059669.toInt() else 0xFF4B5563.toInt()
        ) {
            controller.isInfiniteLoop = !controller.isInfiniteLoop
            try { windowManager.removeView(menu) } catch (e: Exception) {}
            showGlobalSettings()
        }
        menu.addView(loopToggle)

        if (!controller.isInfiniteLoop) {
            val loopCountRow = LinearLayout(context)
            loopCountRow.orientation = HORIZONTAL
            loopCountRow.gravity = Gravity.CENTER_VERTICAL
            loopCountRow.setPadding(0, dp(8), 0, dp(8))
            
            val label = TextView(context)
            label.text = "QUANTIDADE:"
            label.setTextColor(Color.GRAY)
            label.layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
            
            val minus = createSmallBtn("-", Color.WHITE) {
                controller.targetLoopCount = kotlin.math.max(1, controller.targetLoopCount - 1)
                try { windowManager.removeView(menu) } catch (e: Exception) {}
                showGlobalSettings()
            }
            val count = TextView(context)
            count.text = controller.targetLoopCount.toString()
            count.setTextColor(Color.WHITE)
            count.textSize = 18f
            count.setPadding(dp(8), 0, dp(8), 0)
            
            val plus = createSmallBtn("+", Color.WHITE) {
                controller.targetLoopCount++
                try { windowManager.removeView(menu) } catch (e: Exception) {}
                showGlobalSettings()
            }
            
            loopCountRow.addView(label)
            loopCountRow.addView(minus)
            loopCountRow.addView(count)
            loopCountRow.addView(plus)
            menu.addView(loopCountRow)
        }

        // Sequence Delay
        val delayLabel = TextView(context)
        delayLabel.text = "ATRASO ENTRE LOOPS (ms)"
        delayLabel.setTextColor(Color.GRAY)
        delayLabel.textSize = 12f
        delayLabel.setPadding(0, dp(8), 0, 0)
        menu.addView(delayLabel)

        val delayRow = LinearLayout(context)
        delayRow.orientation = HORIZONTAL
        delayRow.gravity = Gravity.CENTER_VERTICAL
        
        val dMinus = createSmallBtn("-", Color.WHITE) {
            controller.sequenceDelayMs = kotlin.math.max(0L, controller.sequenceDelayMs - 100L)
            try { windowManager.removeView(menu) } catch (e: Exception) {}
            showGlobalSettings()
        }
        val dText = TextView(context)
        dText.text = "${controller.sequenceDelayMs}ms"
        dText.setTextColor(Color.WHITE)
        dText.gravity = Gravity.CENTER
        dText.layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        
        val dPlus = createSmallBtn("+", Color.WHITE) {
            controller.sequenceDelayMs += 100L
            try { windowManager.removeView(menu) } catch (e: Exception) {}
            showGlobalSettings()
        }
        delayRow.addView(dMinus)
        delayRow.addView(dText)
        delayRow.addView(dPlus)
        menu.addView(delayRow)

        addDivider(menu)

        // Save / Load Buttons
        val rowSaveLoad = LinearLayout(context)
        rowSaveLoad.orientation = HORIZONTAL
        rowSaveLoad.gravity = Gravity.CENTER
        
        val saveBtn = createStyledTextButton("SALVAR", 0xFF059669.toInt()) {
            controller.saveSequence()
        }.apply { layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(0, 0, dp(4), 0) } }
        
        val loadBtn = createStyledTextButton("CARREGAR", 0xFF7C3AED.toInt()) {
            if (controller.loadSequence()) {
                refreshPointsUI()
                try { windowManager.removeView(menu) } catch (e: Exception) {}
                android.widget.Toast.makeText(context, "Sequência Carregada", android.widget.Toast.LENGTH_SHORT).show()
            }
        }.apply { layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(dp(4), 0, 0, 0) } }
        
        rowSaveLoad.addView(saveBtn)
        rowSaveLoad.addView(loadBtn)
        menu.addView(rowSaveLoad)

        addDivider(menu)

        val closeBtn = createStyledTextButton("FECHAR", Color.RED) {
            try { windowManager.removeView(menu) } catch (e: Exception) {}
        }
        menu.addView(closeBtn)

        val menuParams = WindowManager.LayoutParams().apply {
            width = dp(300)
            height = WindowManager.LayoutParams.WRAP_CONTENT
            type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = android.graphics.PixelFormat.TRANSLUCENT
            gravity = Gravity.CENTER
        }
        windowManager.addView(menu, menuParams)
    }

    private fun showPointSettings(index: Int) {
        if (index < 0 || index >= controller.getActions().size) return
        
        val action = controller.getActions()[index]
        val menu = LinearLayout(context)
        menu.orientation = VERTICAL
        val background = GradientDrawable()
        background.cornerRadius = dp(16).toFloat()
        background.setColor(0xFF1F2937.toInt())
        background.setStroke(dp(2), 0xFF3B82F6.toInt())
        menu.background = background
        menu.setPadding(dp(20), dp(20), dp(20), dp(20))

        // Title
        val title = LinearLayout(context)
        title.orientation = HORIZONTAL
        title.gravity = Gravity.CENTER_VERTICAL
        val titleText = TextView(context)
        titleText.text = "PONTO ${index + 1}"
        titleText.setTextColor(Color.WHITE)
        titleText.textSize = 18f
        titleText.typeface = android.graphics.Typeface.DEFAULT_BOLD
        titleText.layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        title.addView(titleText)
        
        val delBtn = ImageView(context)
        delBtn.setImageResource(android.R.drawable.ic_menu_delete)
        delBtn.setColorFilter(Color.RED)
        delBtn.setOnClickListener {
            try { windowManager.removeView(menu) } catch (e: Exception) {}
            // Remove this specific point
            pointViews.getOrNull(index)?.let {
                it.remove()
                pointViews.removeAt(index)
                controller.removeActionAt(index)
                updateIndices()
            }
        }
        title.addView(delBtn)
        menu.addView(title)

        addDivider(menu)

        // Action Type Label
        val typeLabel = TextView(context)
        typeLabel.text = "TIPO DE GESTO"
        typeLabel.setTextColor(Color.CYAN)
        typeLabel.textSize = 12f
        typeLabel.setPadding(0, dp(8), 0, dp(4))
        menu.addView(typeLabel)

        // Gesture Selector (Horizontal bar of icons)
        val typeContainer = LinearLayout(context)
        typeContainer.orientation = HORIZONTAL
        typeContainer.gravity = Gravity.CENTER
        
        ActionType.values().forEach { type ->
            val isSelected = action.type == type
            val btnContainer = FrameLayout(context)
            val btnBg = GradientDrawable()
            btnBg.cornerRadius = dp(8).toFloat()
            if (isSelected) {
                btnBg.setColor(0xFF3B82F6.toInt()) // Blue
                btnBg.setStroke(dp(1), 0xFF60A5FA.toInt())
            } else {
                btnBg.setColor(0xFF374151.toInt()) // Dark gray
                btnBg.setStroke(dp(1), 0xFF4B5563.toInt())
            }
            btnContainer.background = btnBg
            
            val icon = ImageView(context)
            val iconRes = when(type) {
                ActionType.CLICK -> android.R.drawable.ic_menu_add // Placeholder for Click
                ActionType.SCROLL_UP -> android.R.drawable.arrow_up_float // Placeholder for Scroll Up
                ActionType.SCROLL_DOWN -> android.R.drawable.arrow_down_float // Placeholder for Scroll Down
                ActionType.DRAG -> android.R.drawable.ic_menu_directions // Placeholder for Drag
            }
            // Ideally we should use better vector drawables, but using standard android resources for now
            // Just tinting them white
            icon.setImageResource(iconRes)
            icon.setColorFilter(Color.WHITE)
            icon.setPadding(dp(8), dp(8), dp(8), dp(8))
            
            btnContainer.addView(icon, LayoutParams(dp(40), dp(40)))
            
            val params = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
            params.setMargins(dp(4), 0, dp(4), 0)
            btnContainer.layoutParams = params
            
            btnContainer.setOnClickListener {
                action.type = type
                try { windowManager.removeView(menu) } catch (e: Exception) {}
                showPointSettings(index)
            }
            typeContainer.addView(btnContainer)
        }
        menu.addView(typeContainer)

        addDivider(menu)

        // Delay Label
        val delayLabel = TextView(context)
        delayLabel.text = "ATRASO (MILLISEGUNDOS)"
        delayLabel.setTextColor(Color.CYAN)
        delayLabel.textSize = 12f
        delayLabel.setPadding(0, dp(8), 0, dp(4))
        menu.addView(delayLabel)

        // Delay Controller
        val delayRow = LinearLayout(context)
        delayRow.orientation = HORIZONTAL
        delayRow.gravity = Gravity.CENTER_VERTICAL
        
        val minusBtn = createSmallBtn("-", Color.WHITE) {
            action.delayMs = kotlin.math.max(100L, action.delayMs - 100L)
            updateDelayText(index, action.delayMs)
        }
        val delayText = TextView(context)
        delayText.id = View.generateViewId()
        delayText.text = "${action.delayMs}ms"
        delayText.setTextColor(Color.WHITE)
        delayText.textSize = 20f
        delayText.gravity = Gravity.CENTER
        delayText.layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        val plusBtn = createSmallBtn("+", Color.WHITE) {
            action.delayMs += 100L
            updateDelayText(index, action.delayMs)
        }
        
        delayRow.addView(minusBtn)
        delayRow.addView(delayText)
        delayRow.addView(plusBtn)
        menu.addView(delayRow)

        addDivider(menu)

        // Repeat Count Label
        val repeatLabel = TextView(context)
        repeatLabel.text = "REPETIÇÕES"
        repeatLabel.setTextColor(Color.CYAN)
        repeatLabel.textSize = 12f
        repeatLabel.setPadding(0, dp(8), 0, dp(4))
        menu.addView(repeatLabel)

        // Repeat Controller
        val repeatRow = LinearLayout(context)
        repeatRow.orientation = HORIZONTAL
        repeatRow.gravity = Gravity.CENTER_VERTICAL
        
        val rMinus = createSmallBtn("-", Color.WHITE) {
            action.repeatCount = kotlin.math.max(1, action.repeatCount - 1)
            try { windowManager.removeView(menu) } catch (e: Exception) {}
            showPointSettings(index)
        }
        val rText = TextView(context)
        rText.text = "${action.repeatCount}"
        rText.setTextColor(Color.WHITE)
        rText.textSize = 20f
        rText.gravity = Gravity.CENTER
        rText.layoutParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f)
        val rPlus = createSmallBtn("+", Color.WHITE) {
            action.repeatCount++
            try { windowManager.removeView(menu) } catch (e: Exception) {}
            showPointSettings(index)
        }
        
        repeatRow.addView(rMinus)
        repeatRow.addView(rText)
        repeatRow.addView(rPlus)
        menu.addView(repeatRow)

        addDivider(menu)

        // Snap to Element (Node Picker)
        val snapBtn = createStyledTextButton(
            if (action.targetNodeId != null) "ELEMENTO VINCULADO ✓" else "SELECIONAR ELEMENTO NA TELA",
            if (action.targetNodeId != null) 0xFF059669.toInt() else 0xFF2563EB.toInt()
        ) {
            val service = InspectorAccessibilityService.getInstance()
            if (service != null) {
                // Hide everything
                try { windowManager.removeView(menu) } catch (e: Exception) {}
                hide() 
                
                // Start picker
                service.startNodePicker { pickedNode ->
                    if (pickedNode != null) {
                        action.targetNodeId = pickedNode.id
                        action.targetViewId = pickedNode.viewIdResourceName
                        action.targetClassName = pickedNode.className
                        action.targetText = pickedNode.text
                        
                        handler.post {
                            show() // Restore main bar
                            showPointSettings(index) // Restore settings
                            android.widget.Toast.makeText(context, "Elemento vinculado: ${pickedNode.text ?: "Box"}", android.widget.Toast.LENGTH_SHORT).show()
                        }
                    } else {
                        handler.post {
                            show()
                            showPointSettings(index)
                            android.widget.Toast.makeText(context, "Seleção cancelada", android.widget.Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            } else {
                android.widget.Toast.makeText(context, "Erro: Serviço Inativo", android.widget.Toast.LENGTH_SHORT).show()
            }
        }
        menu.addView(snapBtn)

        // Link Info (Optional, shows ID or Clear option)
        if (action.targetNodeId != null) {
            val clearLinkBtn = TextView(context)
            clearLinkBtn.text = "Desvincular Elemento"
            clearLinkBtn.setTextColor(Color.RED)
            clearLinkBtn.gravity = Gravity.CENTER
            clearLinkBtn.setPadding(0, dp(8), 0, dp(8))
            clearLinkBtn.setOnClickListener {
                action.targetNodeId = null
                try { windowManager.removeView(menu) } catch (e: Exception) {}
                showPointSettings(index)
            }
            menu.addView(clearLinkBtn)
        }

        addDivider(menu)

        // Close
        val finishBtn = createStyledTextButton("PRONTO", 0xFF3B82F6.toInt()) {
            try { windowManager.removeView(menu) } catch (e: Exception) {}
        }
        menu.addView(finishBtn)

        val menuParams = WindowManager.LayoutParams().apply {
            width = dp(320)
            height = WindowManager.LayoutParams.WRAP_CONTENT
            type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            format = android.graphics.PixelFormat.TRANSLUCENT
            gravity = Gravity.CENTER
        }
        windowManager.addView(menu, menuParams)
    }

    private fun updateDelayText(index: Int, delay: Long) {
        // Since we refresh the menu on some clicks, this is just for instant feedback if we didn't refresh
    }

    private fun createStyledTextButton(text: String, color: Int, onClick: () -> Unit): TextView {
        val btn = TextView(context)
        btn.text = text
        btn.setTextColor(Color.WHITE)
        btn.gravity = Gravity.CENTER
        btn.setPadding(dp(16), dp(12), dp(16), dp(12))
        val bg = GradientDrawable()
        bg.cornerRadius = dp(8).toFloat()
        bg.setColor(color)
        btn.background = bg
        val params = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
        params.setMargins(0, dp(12), 0, 0)
        btn.layoutParams = params
        btn.setOnClickListener { onClick() }
        return btn
    }

    private fun createSmallBtn(text: String, color: Int, onClick: () -> Unit): TextView {
        val btn = TextView(context)
        btn.text = text
        btn.setTextColor(color)
        btn.textSize = 24f
        btn.gravity = Gravity.CENTER
        btn.setPadding(dp(16), dp(4), dp(16), dp(4))
        btn.setOnClickListener { onClick() }
        return btn
    }

    private fun addDivider(parent: LinearLayout) {
        val div = View(context)
        div.setBackgroundColor(0x33FFFFFF)
        val params = LayoutParams(LayoutParams.MATCH_PARENT, dp(1))
        params.setMargins(0, dp(12), 0, dp(12))
        div.layoutParams = params
        parent.addView(div)
    }

    private fun createButton(iconRes: Int, color: Int, onClick: (View) -> Unit): ImageView {
        val imageView = ImageView(context)
        imageView.setImageResource(iconRes)
        imageView.setColorFilter(color)
        imageView.setPadding(dp(12), dp(12), dp(12), dp(12))
        imageView.layoutParams = LayoutParams(dp(48), dp(48))
        imageView.setOnClickListener { onClick(it) }
        return imageView
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    fun show() {
        windowManager.addView(this, params)
    }

    fun hide() {
        try {
            windowManager.removeView(this)
        } catch (e: Exception) {}
    }

    private fun updateIndices() {
        pointViews.forEachIndexed { i, v -> v.updateIndex(i) }
    }

    private fun refreshPointsUI() {
        pointViews.forEach { it.remove() }
        pointViews.clear()
        
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels

        controller.getActions().forEachIndexed { index, action ->
            val pointView = ClickPointView(context, index, windowManager, { v ->
                showPointSettings(pointViews.indexOf(v))
            }, { v, nx, ny ->
                val act = controller.getActions()[pointViews.indexOf(v)]
                act.x = nx
                act.y = ny
            })
            pointView.show(action.x, action.y)
            pointViews.add(pointView)
        }
    }
}
