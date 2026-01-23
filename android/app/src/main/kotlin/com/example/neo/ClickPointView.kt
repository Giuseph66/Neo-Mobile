package com.example.neo

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.TextView

class ClickPointView(
    context: Context,
    private val index: Int,
    private val windowManager: WindowManager,
    private val onClick: (ClickPointView) -> Unit,
    private val onMove: (ClickPointView, Int, Int) -> Unit
) : FrameLayout(context) {

    private val params: WindowManager.LayoutParams = WindowManager.LayoutParams().apply {
        width = dp(40)
        height = dp(40)
        type = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
        format = android.graphics.PixelFormat.TRANSLUCENT
        gravity = Gravity.TOP or Gravity.START
    }

    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    private var isDragging: Boolean = false

    private val textView: TextView = TextView(context).apply {
        text = (index + 1).toString()
        setTextColor(Color.WHITE)
        textSize = 14f
        gravity = Gravity.CENTER
    }

    init {
        val background = GradientDrawable()
        background.shape = GradientDrawable.OVAL
        background.setColor(0x883B82F6.toInt()) // Blue with transparency
        background.setStroke(dp(2), Color.WHITE)
        this.background = background
        elevation = dp(4).toFloat()

        addView(textView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

        setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (!isDragging && (kotlin.math.abs(dx) > 10 || kotlin.math.abs(dy) > 10)) {
                        isDragging = true
                    }
                    params.x = initialX + dx
                    params.y = initialY + dy
                    windowManager.updateViewLayout(this, params)
                    onMove(this, params.x + width / 2, params.y + height / 2)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        onClick(this)
                    }
                    isDragging = false
                    true
                }
                else -> false
            }
        }
    }

    fun show(x: Int, y: Int) {
        params.x = x - dp(20)
        params.y = y - dp(20)
        windowManager.addView(this, params)
    }

    fun remove() {
        try {
            windowManager.removeView(this)
        } catch (e: Exception) {}
    }

    fun setInteractive(enabled: Boolean) {
        if (enabled) {
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE.inv()
        } else {
            params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        }
        try {
            windowManager.updateViewLayout(this, params)
        } catch (e: Exception) {}
    }
    
    fun highlight(enabled: Boolean) {
        val bg = background as? GradientDrawable ?: return
        if (enabled) {
            bg.setColor(0xFFFF0000.toInt()) // Red when active
            bg.setStroke(dp(4), Color.YELLOW)
        } else {
            bg.setColor(0x883B82F6.toInt()) // Back to normal
            bg.setStroke(dp(2), Color.WHITE)
        }
        invalidate()
    }

    fun updateIndex(newIndex: Int) {
        textView.text = (newIndex + 1).toString()
    }
    
    fun getPosition(): Pair<Int, Int> {
        val centerX = params.x + dp(20) // params.x é a posição do canto superior esquerdo
        val centerY = params.y + dp(20) // params.y é a posição do canto superior esquerdo
        return Pair(centerX, centerY)
    }
    
    fun hide() {
        remove()
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
