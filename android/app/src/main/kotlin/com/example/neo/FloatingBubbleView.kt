package com.example.neo

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.FrameLayout
import android.widget.ImageView
import kotlin.math.abs

class FloatingBubbleView(context: Context) : FrameLayout(context) {
    var onMove: ((Int, Int) -> Unit)? = null
    var onDragEnd: ((Int, Int) -> Unit)? = null
    var onClick: (() -> Unit)? = null

    private var currentX: Int = 0
    private var currentY: Int = 0
    private var startX: Int = 0
    private var startY: Int = 0
    private var startTouchX: Float = 0f
    private var startTouchY: Float = 0f
    private var isDragging: Boolean = false
    private val touchSlop: Int = ViewConfiguration.get(context).scaledTouchSlop

    init {
        val size = dp(56)
        layoutParams = LayoutParams(size, size)
        val background = GradientDrawable()
        background.shape = GradientDrawable.OVAL
        background.setColor(0xFF1F2937.toInt())
        background.setStroke(dp(2), 0xFF3B82F6.toInt())
        this.background = background
        elevation = dp(6).toFloat()

        val icon = ImageView(context)
        icon.setImageResource(android.R.drawable.ic_dialog_info)
        icon.setColorFilter(0xFFFFFFFF.toInt())
        val iconParams = LayoutParams(dp(28), dp(28))
        iconParams.gravity = android.view.Gravity.CENTER
        addView(icon, iconParams)

        setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = currentX
                    startY = currentY
                    startTouchX = event.rawX
                    startTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - startTouchX).toInt()
                    val dy = (event.rawY - startTouchY).toInt()
                    if (!isDragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        isDragging = true
                    }
                    val newX = startX + dx
                    val newY = startY + dy
                    currentX = newX
                    currentY = newY
                    onMove?.invoke(newX, newY)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        onClick?.invoke()
                    } else {
                        onDragEnd?.invoke(currentX, currentY)
                    }
                    isDragging = false
                    true
                }
                else -> false
            }
        }
    }

    fun setPosition(x: Int, y: Int) {
        currentX = x
        currentY = y
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }
}
