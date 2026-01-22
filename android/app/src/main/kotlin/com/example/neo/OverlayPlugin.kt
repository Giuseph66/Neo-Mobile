package com.example.neo

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class OverlayPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "overlay_control")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "overlay_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val safeContext = context
        if (safeContext == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        when (call.method) {
            "checkOverlayPermission" -> {
                result.success(Settings.canDrawOverlays(safeContext))
            }
            "requestOverlayPermission" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${safeContext.packageName}")
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity?.startActivity(intent) ?: safeContext.startActivity(intent)
                result.success(null)
            }
            "startOverlayService" -> {
                if (!Settings.canDrawOverlays(safeContext)) {
                    result.success(false)
                    return
                }
                val intent = Intent(safeContext, OverlayService::class.java)
                ContextCompat.startForegroundService(safeContext, intent)
                result.success(true)
            }
            "stopOverlayService" -> {
                val intent = Intent(safeContext, OverlayService::class.java)
                val stopped = safeContext.stopService(intent)
                result.success(stopped)
            }
            "openAppFromOverlay" -> {
                val launchIntent =
                    safeContext.packageManager.getLaunchIntentForPackage(safeContext.packageName)
                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                launchIntent?.let { safeContext.startActivity(it) }
                result.success(null)
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

    companion object {
        private var eventSink: EventChannel.EventSink? = null

        fun emitEvent(event: String) {
            eventSink?.success(event)
        }
    }
}
