package com.example.neo

import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import android.util.Log

class WebSocketManager(private val serverUrl: String) {
    private var client: OkHttpClient = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()
    private var webSocket: WebSocket? = null
    private var isConnected = false

    fun connect() {
        if (isConnected) return
        
        Log.d("WebSocketManager", "Connecting to $serverUrl")
        val request = Request.Builder()
            .url(serverUrl)
            .build()
        
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                isConnected = true
                Log.d("WebSocketManager", "WebSocket Connected")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d("WebSocketManager", "Received: $text")
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
                isConnected = false
                Log.d("WebSocketManager", "WebSocket Closing: $reason")
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                isConnected = false
                Log.e("WebSocketManager", "WebSocket Error: ${t.message}")
                // Try to reconnect after 5 seconds
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    connect()
                }, 5000)
            }
        })
    }

    fun sendNodes(nodes: List<UiNode>, width: Int, height: Int) {
        if (!isConnected) return
        
        try {
            val json = JSONObject().apply {
                put("type", "nodes")
                val nodesArray = JSONArray()
                nodes.forEach { nodesArray.put(it.toJson()) }
                put("nodes", nodesArray)
                put("width", width)
                put("height", height)
            }
            webSocket?.send(json.toString())
        } catch (e: Exception) {
            Log.e("WebSocketManager", "Error sending nodes: ${e.message}")
        }
    }

    fun sendSelection(nodeId: String?) {
        if (!isConnected) return
        
        try {
            val json = JSONObject().apply {
                put("type", "selection")
                put("nodeId", nodeId)
            }
            webSocket?.send(json.toString())
        } catch (e: Exception) {
            Log.e("WebSocketManager", "Error sending selection: ${e.message}")
        }
    }

    fun disconnect() {
        webSocket?.close(1000, "Goodbye")
        isConnected = false
    }
}
