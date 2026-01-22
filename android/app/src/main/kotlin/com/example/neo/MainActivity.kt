package com.example.neo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.neo.llm.LocalLlmPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(OverlayPlugin())
        flutterEngine.plugins.add(AccessibilityPlugin())
        flutterEngine.plugins.add(LocalLlmPlugin())
    }
}
