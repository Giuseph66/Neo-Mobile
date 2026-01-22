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

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        // Desenhar fundo translúcido (opcional)
        // canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paintBackground)

        // Desenhar bounding boxes
        // Ajustar bounds subtraindo a altura da barra de status
        for (node in nodes) {
            val paint = when {
                node.id == selectedNodeId -> paintSelected
                node.id == aimedNodeId -> paintAimed
                else -> paintDefault
            }
            // Subtrair altura da barra de status para corrigir offset
            val adjustedTop = node.bounds.top - statusBarHeight
            val adjustedBottom = node.bounds.bottom - statusBarHeight
            val left = node.bounds.left.toFloat()
            val right = node.bounds.right.toFloat()
            val top = adjustedTop.toFloat()
            val bottom = adjustedBottom.toFloat()
            
            canvas.drawRect(left, top, right, bottom, paint)
            
            // Desenhar texto se habilitado e se o node tiver texto
            if (showText && !node.text.isNullOrBlank()) {
                var text = node.text ?: ""
                // Limitar tamanho do texto para não poluir a tela (máximo 50 caracteres)
                if (text.length > 50) {
                    text = text.substring(0, 47) + "..."
                }
                
                val textWidth = paintText.measureText(text)
                val textHeight = paintText.descent() - paintText.ascent()
                
                // Calcular posição: parte inferior interna do box
                val textX = left + 8f // Margem esquerda
                val textY = bottom - 8f // Margem inferior
                
                // Garantir que o texto não ultrapasse o box
                val maxTextWidth = right - left - 16f // Margem de 8px de cada lado
                val displayText = if (textWidth > maxTextWidth) {
                    // Truncar texto se necessário
                    var truncated = text
                    while (paintText.measureText(truncated + "...") > maxTextWidth && truncated.isNotEmpty()) {
                        truncated = truncated.dropLast(1)
                    }
                    truncated + "..."
                } else {
                    text
                }
                
                val finalTextWidth = paintText.measureText(displayText)
                
                // Desenhar fundo do texto (retângulo semi-transparente)
                val padding = 4f
                val bgLeft = textX - padding
                val bgTop = textY - textHeight - padding
                val bgRight = textX + finalTextWidth + padding
                val bgBottom = textY + padding
                canvas.drawRect(bgLeft, bgTop, bgRight, bgBottom, paintTextBackground)
                
                // Desenhar texto
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
        // Retornar false para permitir que toques passem através do overlay
        return false
    }
}
