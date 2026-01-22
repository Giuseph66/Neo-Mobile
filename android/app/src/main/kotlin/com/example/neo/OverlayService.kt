package com.example.neo

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class OverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private var bubbleView: FloatingBubbleView? = null
    private var menuView: LinearLayout? = null
    private lateinit var bubbleParams: WindowManager.LayoutParams
    private var menuParams: WindowManager.LayoutParams? = null
    private val prefs by lazy { getSharedPreferences(PREFS_NAME, MODE_PRIVATE) }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createBubble()
        OverlayPlugin.emitEvent("service_started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(
            OverlayNotification.NOTIFICATION_ID,
            OverlayNotification.buildNotification(this)
        )
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        removeBubble()
        removeMenu()
        OverlayPlugin.emitEvent("service_stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createBubble() {
        val startX = prefs.getInt(KEY_POS_X, dp(24))
        val startY = prefs.getInt(KEY_POS_Y, dp(120))
        bubbleParams = createLayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        bubbleParams.gravity = Gravity.TOP or Gravity.START
        bubbleParams.x = startX
        bubbleParams.y = startY

        bubbleView = FloatingBubbleView(this).apply {
            setPosition(startX, startY)
            onMove = { x, y ->
                bubbleParams.x = x
                bubbleParams.y = y
                windowManager.updateViewLayout(this, bubbleParams)
                if (menuView != null) {
                    updateMenuPosition(x, y)
                }
            }
            onDragEnd = { x, y ->
                savePosition(x, y)
            }
            onClick = {
                toggleMenu()
            }
        }

        windowManager.addView(bubbleView, bubbleParams)
    }

    private fun removeBubble() {
        bubbleView?.let { view ->
            windowManager.removeView(view)
        }
        bubbleView = null
    }

    private fun toggleMenu() {
        if (menuView == null) {
            showMenu()
        } else {
            removeMenu()
        }
    }

    private fun showMenu() {
        val menu = LinearLayout(this)
        menu.orientation = LinearLayout.VERTICAL
        val background = GradientDrawable()
        background.cornerRadius = dp(12).toFloat()
        background.setColor(0xFF111827.toInt())
        background.setStroke(dp(1), 0xFF374151.toInt())
        menu.background = background
        menu.elevation = dp(8).toFloat()

        menu.addView(menuItem("Abrir App") {
            openApp()
            removeMenu()
        })
        menu.addView(menuDivider())
        menu.addView(menuItem("Atalhos") {
            OverlayPlugin.emitEvent("open_shortcuts")
            openApp()
            removeMenu()
        })
        menu.addView(menuDivider())
        menu.addView(menuItem("Ativar Inspector") {
            OverlayPlugin.emitEvent("activate_inspector")
            openApp()
            removeMenu()
        })
        menu.addView(menuDivider())
        menu.addView(menuItem("Desativar Overlay") {
            removeMenu()
            stopSelf()
        })

        val params = createLayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        menuParams = params
        menuView = menu

        val startX = bubbleParams.x
        val startY = bubbleParams.y
        params.x = startX + dp(68)
        params.y = startY

        windowManager.addView(menu, menuParams)
    }

    private fun removeMenu() {
        menuView?.let { view ->
            try {
                windowManager.removeView(view)
            } catch (ignored: IllegalArgumentException) {
                // View already removed.
            }
        }
        menuView = null
        menuParams = null
    }

    private fun updateMenuPosition(bubbleX: Int, bubbleY: Int) {
        val params = menuParams ?: return
        val view = menuView ?: return
        if (!view.isAttachedToWindow) {
            return
        }
        params.x = bubbleX + dp(68)
        params.y = bubbleY
        try {
            windowManager.updateViewLayout(view, params)
        } catch (ignored: IllegalArgumentException) {
            // View detached between checks.
        }
    }

    private fun menuItem(title: String, onClick: () -> Unit): View {
        val textView = TextView(this)
        textView.text = title
        textView.setTextColor(0xFFFFFFFF.toInt())
        textView.textSize = 14f
        textView.setPadding(dp(16), dp(12), dp(16), dp(12))
        textView.setOnClickListener { onClick() }
        return textView
    }

    private fun menuDivider(): View {
        val divider = View(this)
        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(1)
        )
        divider.layoutParams = params
        divider.setBackgroundColor(0xFF1F2937.toInt())
        return divider
    }

    private fun openApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        launchIntent?.let { startActivity(it) }
    }

    private fun savePosition(x: Int, y: Int) {
        prefs.edit().putInt(KEY_POS_X, x).putInt(KEY_POS_Y, y).apply()
    }

    private fun createLayoutParams(width: Int, height: Int): WindowManager.LayoutParams {
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        return WindowManager.LayoutParams(
            width,
            height,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        private const val PREFS_NAME = "overlay_prefs"
        private const val KEY_POS_X = "bubble_x"
        private const val KEY_POS_Y = "bubble_y"
    }
}
