package com.example.neo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class AccessibilityPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var nodesStreamHandler: EventChannel.StreamHandler? = null
    private var isStreaming = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "inspector/actions")
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(binding.binaryMessenger, "inspector/nodesStream")
        nodesStreamHandler = object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                isStreaming = true
                startNodesStream()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                isStreaming = false
            }
        }
        eventChannel.setStreamHandler(nodesStreamHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        isStreaming = false
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val service = InspectorAccessibilityService.getInstance()
        
        when (call.method) {
            "isAccessibilityEnabled" -> {
                result.success(isAccessibilityServiceEnabled())
            }
            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }
            "setInspectorEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled && !isAccessibilityServiceEnabled()) {
                    result.error("NOT_ENABLED", "Accessibility service is not enabled", null)
                    return
                }
                service?.setInspectorEnabled(enabled)
                if (enabled) {
                    startNodesStream()
                }
                result.success(null)
            }
            "setOverlayVisible" -> {
                val visible = call.argument<Boolean>("visible") ?: false
                service?.setOverlayVisible(visible)
                result.success(null)
            }
            "setTextVisible" -> {
                val visible = call.argument<Boolean>("visible") ?: false
                service?.setTextVisible(visible)
                result.success(null)
            }
            "setAimPosition" -> {
                val x = call.argument<Int>("x") ?: 0
                val y = call.argument<Int>("y") ?: 0
                service?.setAimPosition(x, y)
                result.success(null)
            }
            "selectNode" -> {
                val nodeId = call.argument<String>("nodeId")
                if (nodeId != null) {
                    service?.selectNode(nodeId)
                    result.success(null)
                } else {
                    result.error("INVALID_ARG", "nodeId is required", null)
                }
            }
            "clickSelected" -> {
                val success = service?.clickSelected() ?: false
                result.success(success)
            }
            "scrollForward" -> {
                val success = service?.scrollForward() ?: false
                result.success(success)
            }
            "scrollBackward" -> {
                val success = service?.scrollBackward() ?: false
                result.success(success)
            }
            "tap" -> {
                val x = call.argument<Int>("x") ?: 0
                val y = call.argument<Int>("y") ?: 0
                val durationMs = call.argument<Int>("durationMs") ?: 100
                service?.tap(x, y, durationMs)
                result.success(null)
            }
            "swipe" -> {
                val x1 = call.argument<Int>("x1") ?: 0
                val y1 = call.argument<Int>("y1") ?: 0
                val x2 = call.argument<Int>("x2") ?: 0
                val y2 = call.argument<Int>("y2") ?: 0
                val durationMs = call.argument<Int>("durationMs") ?: 300
                service?.swipe(x1, y1, x2, y2, durationMs)
                result.success(null)
            }
            "navigateHome" -> {
                val success = service?.navigateHome() ?: false
                result.success(success)
            }
            "navigateBack" -> {
                val success = service?.navigateBack() ?: false
                result.success(success)
            }
            "navigateRecents" -> {
                val success = service?.navigateRecents() ?: false
                result.success(success)
            }
            "inputText" -> {
                val text = call.argument<String>("text") ?: ""
                val success = service?.inputText(text) ?: false
                result.success(success)
            }
            "setWebSocketUrl" -> {
                val url = call.argument<String>("url")
                if (url != null) {
                    service?.setWebSocketUrl(url)
                    result.success(null)
                } else {
                    result.error("INVALID_ARG", "url is required", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val context = context ?: return false
        val serviceName = "${context.packageName}/${InspectorAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""
        return enabledServices.contains(serviceName, ignoreCase = true)
    }

    private fun openAccessibilitySettings() {
        val context = context ?: return
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity?.startActivity(intent) ?: context.startActivity(intent)
    }

    private fun startNodesStream() {
        if (!isStreaming) return
        
        handler.postDelayed(object : Runnable {
            override fun run() {
                if (!isStreaming) return
                
                val service = InspectorAccessibilityService.getInstance()
                val nodes = service?.getCurrentNodes() ?: emptyList()
                
                try {
                    val jsonArray = JSONArray()
                    for (node in nodes) {
                        jsonArray.put(node.toJson())
                    }
                    
                    val snapshot = JSONObject().apply {
                        put("nodes", jsonArray)
                        put("timestamp", System.currentTimeMillis())
                    }
                    
                    eventSink?.success(snapshot.toString())
                } catch (e: Exception) {
                    // Ignorar erros de serialização
                }
                
                handler.postDelayed(this, 200) // Throttle de 200ms
            }
        }, 200)
    }
}
