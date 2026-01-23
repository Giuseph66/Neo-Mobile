package com.example.neo

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.view.MotionEvent
import android.view.View

class InspectorOverlayView(context: Context) : View(context) {
    private val paintDefault = Paint().apply {
        color = 0xFF9333EA.toInt() // Roxo
        style = Paint.Style.STROKE
        strokeWidth = 4f
        isAntiAlias = true
    }

    private val paintSelected = Paint().apply {
        color = 0xFF10B981.toInt() // Verde
        style = Paint.Style.STROKE
        strokeWidth = 6f
        isAntiAlias = true
    }

    private val paintAimed = Paint().apply {
        color = 0xFFEF4444.toInt() // Vermelho
        style = Paint.Style.STROKE
        strokeWidth = 5f
        isAntiAlias = true
    }

    private val paintBackground = Paint().apply {
        color = 0x10000000.toInt() // Preto translúcido
        style = Paint.Style.FILL
    }

    private var nodes: List<UiNode> = emptyList()
    private var selectedNodeId: String? = null
    private var aimPosition: android.graphics.Point? = null
    private var aimedNodeId: String? = null
    private var statusBarHeight: Int = 0
    private var showText: Boolean = false

    private val paintText = Paint().apply {
        color = 0xFFFFFFFF.toInt() // Branco
        textSize = 28f
        typeface = Typeface.DEFAULT_BOLD
        isAntiAlias = true
    }

    private val paintTextBackground = Paint().apply {
        color = 0xCC000000.toInt() // Preto semi-transparente
        style = Paint.Style.FILL
    }

    fun setStatusBarHeight(height: Int) {
        statusBarHeight = height
        invalidate()
    }

    fun setNodes(newNodes: List<UiNode>) {
        nodes = newNodes
        invalidate()
    }

    fun setSelectedNode(nodeId: String?) {
        selectedNodeId = nodeId
        invalidate()
    }

    fun setAimPosition(x: Int, y: Int) {
        aimPosition = android.graphics.Point(x, y)
        // Encontrar node sob a mira (ajustar Y pela barra de status)
        aimedNodeId = null
        val adjustedY = y + statusBarHeight // Ajustar coordenada da mira
        for (node in nodes) {
            if (node.bounds.contains(x, adjustedY)) {
                aimedNodeId = node.id
                break
            }
        }
        invalidate()
    }

    fun setTextVisible(visible: Boolean) {
        showText = visible
        invalidate()
    }

    private val textWidthCache = mutableMapOf<String, Float>()
    private var lastNodesHash: Int = 0

    private var highlightedNodeId: String? = null

    fun setHighlightedNode(nodeId: String?) {
        highlightedNodeId = nodeId
        // Also center the aim position on this node if needed, or just repaint
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Clear cache if nodes changed significantly
        val currentNodesHash = nodes.hashCode()
        if (currentNodesHash != lastNodesHash) {
            textWidthCache.clear()
            lastNodesHash = currentNodesHash
        }

        for (node in nodes) {
            val paint = when {
                node.id == highlightedNodeId -> paintSelected // Green for list selection
                node.id == selectedNodeId -> paintDefault // Previously selected, keep standard
                else -> paintDefault
            }
            
            // If highlighted, increase stroke width
            if (node.id == highlightedNodeId) {
                paint.strokeWidth = 10f
            } else {
                paint.strokeWidth = 4f
            }
            
            val adjustedTop = node.bounds.top - statusBarHeight
            val adjustedBottom = node.bounds.bottom - statusBarHeight
            val left = node.bounds.left.toFloat()
            val right = node.bounds.right.toFloat()
            val top = adjustedTop.toFloat()
            val bottom = adjustedBottom.toFloat()
            
            canvas.drawRect(left, top, right, bottom, paint)
            
            // Only draw text for highlighted node to reduce clutter? Or all?
            // Let's draw text if enabled OR if highlighted
            if ((showText || node.id == highlightedNodeId) && !node.text.isNullOrBlank()) {
                 val text = node.text!!
                val cacheKey = "${node.id}_$text"
                
                // Measure only once or if changed
                val textWidth = textWidthCache.getOrPut(cacheKey) {
                    paintText.measureText(if (text.length > 50) text.substring(0, 47) + "..." else text)
                }
                
                val textHeight = paintText.descent() - paintText.ascent()
                val textX = left + 8f
                val textY = bottom - 8f
                
                val maxTextWidth = right - left - 16f
                if (maxTextWidth <= 0) continue

                val displayText = if (textWidth > maxTextWidth) {
                    // Still need to truncate if box is small, but let's at least cache basic width
                    var truncated = text
                    if (truncated.length > 50) truncated = truncated.substring(0, 47) + "..."
                    while (paintText.measureText(truncated) > maxTextWidth && truncated.isNotEmpty()) {
                        truncated = truncated.dropLast(1)
                    }
                    truncated
                } else {
                    if (text.length > 50) text.substring(0, 47) + "..." else text
                }
                
                val finalWidth = paintText.measureText(displayText)
                
                val padding = 4f
                val bgLeft = textX - padding
                val bgTop = textY - textHeight - padding
                val bgRight = textX + finalWidth + padding
                val bgBottom = textY + padding
                canvas.drawRect(bgLeft, bgTop, bgRight, bgBottom, paintTextBackground)
                canvas.drawText(displayText, textX, textY, paintText)
            }
        }

        // Desenhar indicador da mira (opcional)
        // A mira já vem com coordenadas relativas (sem barra de status), então não precisa ajustar
        aimPosition?.let { pos ->
            val radius = 20f
            canvas.drawCircle(pos.x.toFloat(), pos.y.toFloat(), radius, paintAimed.apply {
                style = Paint.Style.FILL
                alpha = 100
            })
            paintAimed.style = Paint.Style.STROKE
            paintAimed.alpha = 255
        }
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        if (event?.action == MotionEvent.ACTION_DOWN) {
            val x = event.x.toInt()
            val y = event.y.toInt()
            
            // Find top-most node at (x, y)
             val adjustedY = y + statusBarHeight
            // Iterate in reverse to find top-most
            for (i in nodes.indices.reversed()) {
                val node = nodes[i]
                if (node.bounds.contains(x, adjustedY)) {
                    val service = context as? InspectorAccessibilityService ?: InspectorAccessibilityService.getInstance()
                    service?.onNodePicked(node.id)
                    return true
                }
            }
            // If no node found, maybe cancel picker? Or just ignore.
            // Let's allow clicking "nowhere" to cancel if needed, or just do nothing.
             val service = context as? InspectorAccessibilityService ?: InspectorAccessibilityService.getInstance()
             service?.onNodePicked("") // Empty string to signal cancel/no selection
             return true
        }
        return true // Consume all events to prevent interacting with app below while picking
    }
}
