package com.example.neo

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class OverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private var bubbleView: FloatingBubbleView? = null
    private var menuView: LinearLayout? = null
    private var autoClickerView: AutoClickerView? = null
    private lateinit var bubbleParams: WindowManager.LayoutParams
    private var menuParams: WindowManager.LayoutParams? = null
    private val prefs by lazy { getSharedPreferences(PREFS_NAME, MODE_PRIVATE) }
    private var isInspectorActive = false
    private var showBoxes = true
    private var showTexts = false

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
        autoClickerView?.hide()
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
        removeMenu()
        val menu = LinearLayout(this)
        menu.orientation = LinearLayout.VERTICAL
        val background = GradientDrawable()
        background.cornerRadius = dp(16).toFloat()
        background.setColor(0xFF111827.toInt())
        background.setStroke(dp(1), 0xFF374151.toInt())
        menu.background = background
        menu.elevation = dp(12).toFloat()
        menu.setPadding(dp(4), dp(4), dp(4), dp(4))

        menu.addView(menuItem("Abrir App", android.R.drawable.ic_menu_edit) {
            openApp()
            removeMenu()
        })
        
        menu.addView(menuItem("Atalhos (AutoClicker)", android.R.drawable.ic_menu_compass) {
            toggleAutoClicker()
            removeMenu()
        })

        if (!isInspectorActive) {
            menu.addView(menuItem("Ativar Inspector", android.R.drawable.ic_menu_search) {
                activateInspector()
                showMenu() // Refresh menu to show sub-options
            })
        } else {
            menu.addView(menuItem("Configurações do Inspector", android.R.drawable.ic_menu_preferences) {
                showInspectorSettings()
            })
            menu.addView(menuItem("Desativar Inspector", android.R.drawable.ic_menu_close_clear_cancel) {
                deactivateInspector()
                showMenu()
            })
        }

        menu.addView(menuDivider())
        menu.addView(menuItem("Fechar Overlay", android.R.drawable.ic_menu_delete, 0xFFEF4444.toInt()) {
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

    private fun showInspectorSettings() {
        removeMenu()
        val menu = LinearLayout(this)
        menu.orientation = LinearLayout.VERTICAL
        val background = GradientDrawable()
        background.cornerRadius = dp(16).toFloat()
        background.setColor(0xFF1F2937.toInt())
        background.setStroke(dp(1), 0xFF3B82F6.toInt())
        menu.background = background
        menu.setPadding(dp(4), dp(4), dp(4), dp(4))

        menu.addView(menuItem(if (showBoxes) "Ocultar Boxes" else "Exibir Boxes", android.R.drawable.checkbox_on_background) {
            showBoxes = !showBoxes
            InspectorAccessibilityService.getInstance()?.setOverlayVisible(showBoxes)
            showInspectorSettings()
        })

        menu.addView(menuItem(if (showTexts) "Ocultar Textos" else "Exibir Textos", android.R.drawable.ic_menu_sort_alphabetically) {
            showTexts = !showTexts
            InspectorAccessibilityService.getInstance()?.setTextVisible(showTexts)
            showInspectorSettings()
        })

        menu.addView(menuDivider())
        menu.addView(menuItem("Voltar", android.R.drawable.ic_menu_revert) {
            showMenu()
        })

        menuView = menu
        menuParams = createLayoutParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.TOP or Gravity.START
            x = bubbleParams.x + dp(68)
            y = bubbleParams.y
        }
        windowManager.addView(menu, menuParams)
    }

    private fun activateInspector() {
        isInspectorActive = true
        InspectorAccessibilityService.getInstance()?.setInspectorEnabled(true)
        InspectorAccessibilityService.getInstance()?.setOverlayVisible(showBoxes)
        InspectorAccessibilityService.getInstance()?.setTextVisible(showTexts)
        removeMenu()
    }

    private fun deactivateInspector() {
        isInspectorActive = false
        InspectorAccessibilityService.getInstance()?.setInspectorEnabled(false)
        removeMenu()
    }

    private fun toggleAutoClicker() {
        if (autoClickerController == null) {
            val service = InspectorAccessibilityService.getInstance()
            if (service == null) {
                OverlayPlugin.emitEvent("error: accessibility_service_not_running")
                return
            }
            autoClickerController = AutoClickerController(service)
        }

        if (autoClickerView == null) {
            autoClickerView = AutoClickerView(this, autoClickerController!!, windowManager) {
                autoClickerView = null
            }
            autoClickerView?.show()
        } else {
            autoClickerView?.hide()
            autoClickerView = null
        }
    }

    private var autoClickerController: AutoClickerController? = null

    private fun removeMenu() {
        if (menuView == null) return
        try {
            windowManager.removeView(menuView)
        } catch (e: Exception) {
            // View might already be removed or detached
        } finally {
            menuView = null
            menuParams = null
        }
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

    private fun menuItem(title: String, iconRes: Int, color: Int = Color.WHITE, onClick: () -> Unit): View {
        val layout = LinearLayout(this)
        layout.orientation = LinearLayout.HORIZONTAL
        layout.gravity = Gravity.CENTER_VERTICAL
        layout.setPadding(dp(16), dp(12), dp(16), dp(12))
        layout.setOnClickListener { onClick() }

        val icon = ImageView(this)
        icon.setImageResource(iconRes)
        icon.setColorFilter(color)
        val iconParams = LinearLayout.LayoutParams(dp(20), dp(20))
        iconParams.marginEnd = dp(12)
        layout.addView(icon, iconParams)

        val textView = TextView(this)
        textView.text = title
        textView.setTextColor(color)
        textView.textSize = 14f
        layout.addView(textView)

        return layout
    }

    private fun menuDivider(): View {
        val divider = View(this)
        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(1)
        )
        params.setMargins(dp(8), dp(4), dp(8), dp(4))
        divider.layoutParams = params
        divider.setBackgroundColor(0xFF374151.toInt())
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
