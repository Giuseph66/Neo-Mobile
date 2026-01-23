package com.example.neo

import android.os.Handler
import android.os.Looper

enum class ActionType {
    CLICK, SCROLL_UP, SCROLL_DOWN, DRAG
}

data class AutoClickAction(
    val id: String,
    var x: Int,
    var y: Int,
    var x2: Int? = null,
    var y2: Int? = null,
    var type: ActionType = ActionType.CLICK,
    var delayMs: Long = 1000,
    var repeatCount: Int = 1,
    var targetNodeId: String? = null,
    var targetViewId: String? = null,
    var targetClassName: String? = null,
    var targetText: String? = null
)

class AutoClickerController(private val service: InspectorAccessibilityService) {
    private val handler = Handler(Looper.getMainLooper())
    private val actions = mutableListOf<AutoClickAction>()
    private var isRunning = false
    private var currentIndex = 0
    
    // Loop settings
    var isInfiniteLoop = true
    var targetLoopCount = 1
    private var currentLoopCount = 0
    var sequenceDelayMs = 500L
    
    // Execution state
    private var currentActionRepeatCount = 0

    var onUpdate: (() -> Unit)? = null
    var onActionStarted: ((Int) -> Unit)? = null
    var onActionFinished: (() -> Unit)? = null

    fun addAction(x: Int, y: Int) {
        val action = AutoClickAction(
            id = java.util.UUID.randomUUID().toString(),
            x = x,
            y = y
        )
        actions.add(action)
        onUpdate?.invoke()
    }

    fun removeLastAction() {
        if (actions.isNotEmpty()) {
            actions.removeAt(actions.size - 1)
            onUpdate?.invoke()
        }
    }

    fun removeActionAt(index: Int) {
        if (index >= 0 && index < actions.size) {
            actions.removeAt(index)
            onUpdate?.invoke()
        }
    }

    fun clearActions() {
        actions.clear()
        stop()
        onUpdate?.invoke()
    }

    fun getActions(): List<AutoClickAction> = actions

    fun start() {
        if (service == null || InspectorAccessibilityService.getInstance() == null) {
            android.widget.Toast.makeText(service, "Erro: Serviço de Acessibilidade não está ativo", android.widget.Toast.LENGTH_LONG).show()
            return
        }
        if (isRunning || actions.isEmpty()) return
        isRunning = true
        currentIndex = 0
        currentLoopCount = 0
        currentActionRepeatCount = 0
        executeNext()
    }

    fun stop() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
    }

    private fun executeNext() {
        if (!isRunning) return

        if (currentIndex >= actions.size) {
            currentLoopCount++
            if (isInfiniteLoop || currentLoopCount < targetLoopCount) {
                android.util.Log.d("AutoClicker", "Loop $currentLoopCount finished, restarting")
                currentIndex = 0
                currentActionRepeatCount = 0
                handler.postDelayed({ executeNext() }, sequenceDelayMs)
            } else {
                android.util.Log.d("AutoClicker", "All loops finished")
                isRunning = false
                handler.post { onActionFinished?.invoke() }
            }
            return
        }

        val action = actions[currentIndex]
        
        // Notify UI which point is active
        onPointStarted(currentIndex)

        android.util.Log.d("AutoClicker", "Executing action $currentIndex (repeat $currentActionRepeatCount): ${action.type}")
        
        // Execute action
        if (action.targetNodeId != null || action.targetViewId != null || action.targetText != null) {
            // Smart click: Try finding the node by attributes first (handles movement)
            val success = service.findAndClickNode(action.targetViewId, action.targetClassName, action.targetText)
            
            // Fallback: If smart search failed, try the specific coordinate or the old ID-based click
            if (!success) {
                val idClicked = service.clickElementById(action.targetNodeId ?: "")
                if (!idClicked) service.tap(action.x, action.y)
            }
        } else {
            when (action.type) {
                ActionType.CLICK -> service.tap(action.x, action.y)
                ActionType.SCROLL_UP -> service.swipe(action.x, action.y + 400, action.x, action.y - 400)
                ActionType.SCROLL_DOWN -> service.swipe(action.x, action.y - 400, action.x, action.y + 400)
                ActionType.DRAG -> {
                    if (action.x2 != null && action.y2 != null) {
                        service.swipe(action.x, action.y, action.x2!!, action.y2!!)
                    } else {
                        service.swipe(action.x, action.y, action.x, action.y - 300)
                    }
                }
            }
        }

        // Handle repeats for the same action
        currentActionRepeatCount++
        if (currentActionRepeatCount < action.repeatCount) {
            handler.postDelayed({ executeNext() }, action.delayMs + 200)
        } else {
            currentIndex++
            currentActionRepeatCount = 0
            handler.postDelayed({ executeNext() }, action.delayMs + 200)
        }
    }

    private fun onPointStarted(index: Int) {
        handler.post {
            onActionStarted?.invoke(index)
        }
    }

    fun saveSequence() {
        try {
            val jsonArray = org.json.JSONArray()
            actions.forEach { action ->
                val obj = org.json.JSONObject()
                obj.put("x", action.x)
                obj.put("y", action.y)
                obj.put("type", action.type.name)
                obj.put("delay", action.delayMs)
                obj.put("repeat", action.repeatCount)
                if (action.targetNodeId != null) obj.put("target", action.targetNodeId)
                if (action.targetViewId != null) obj.put("targetViewId", action.targetViewId)
                if (action.targetClassName != null) obj.put("targetClassName", action.targetClassName)
                if (action.targetText != null) obj.put("targetText", action.targetText)
                jsonArray.put(obj)
            }
            
            val prefs = service.getSharedPreferences("autoclicker_prefs", android.content.Context.MODE_PRIVATE)
            prefs.edit().putString("sequence_data", jsonArray.toString()).apply()
            
            // Save global settings too
            prefs.edit()
                .putBoolean("infinite", isInfiniteLoop)
                .putInt("target_loops", targetLoopCount)
                .putLong("loop_delay", sequenceDelayMs)
                .apply()
                
            android.widget.Toast.makeText(service, "Sequência Salva", android.widget.Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            android.util.Log.e("AutoClicker", "Error saving", e)
        }
    }

    fun loadSequence(): Boolean {
        try {
            val prefs = service.getSharedPreferences("autoclicker_prefs", android.content.Context.MODE_PRIVATE)
            val data = prefs.getString("sequence_data", null) ?: return false
            
            isInfiniteLoop = prefs.getBoolean("infinite", true)
            targetLoopCount = prefs.getInt("target_loops", 1)
            sequenceDelayMs = prefs.getLong("loop_delay", 500L)
            
            val jsonArray = org.json.JSONArray(data)
            actions.clear()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                actions.add(AutoClickAction(
                    id = java.util.UUID.randomUUID().toString(),
                    x = obj.getInt("x"),
                    y = obj.getInt("y"),
                    type = ActionType.valueOf(obj.getString("type")),
                    delayMs = obj.getLong("delay"),
                    repeatCount = obj.getInt("repeat"),
                    targetNodeId = if (obj.has("target")) obj.getString("target") else null,
                    targetViewId = if (obj.has("targetViewId")) obj.getString("targetViewId") else null,
                    targetClassName = if (obj.has("targetClassName")) obj.getString("targetClassName") else null,
                    targetText = if (obj.has("targetText")) obj.getString("targetText") else null
                ))
            }
            onUpdate?.invoke()
            return true
        } catch (e: Exception) {
            android.util.Log.e("AutoClicker", "Error loading", e)
            return false
        }
    }
}
