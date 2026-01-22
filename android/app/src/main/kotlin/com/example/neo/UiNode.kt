package com.example.neo

import android.graphics.Rect
import org.json.JSONObject

data class NodeSelector(
    val viewId: String?,
    val className: String,
    val path: String?
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            if (viewId != null) put("viewId", viewId)
            put("className", className)
            if (path != null) put("path", path)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): NodeSelector {
            return NodeSelector(
                viewId = if (json.has("viewId")) json.getString("viewId") else null,
                className = json.getString("className"),
                path = if (json.has("path")) json.getString("path") else null
            )
        }
    }

    override fun toString(): String {
        return buildString {
            if (viewId != null) append("viewId=$viewId, ")
            append("class=$className")
            if (path != null) append(", path=$path")
        }
    }
}

data class UiNode(
    val id: String,
    val selector: NodeSelector,
    val bounds: Rect,
    val className: String,
    val packageName: String,
    val viewIdResourceName: String?,
    val clickable: Boolean,
    val enabled: Boolean,
    val scrollable: Boolean,
    val isTextField: Boolean,
    val text: String? = null
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("selector", selector.toJson())
            put("bounds", JSONObject().apply {
                put("left", bounds.left)
                put("top", bounds.top)
                put("right", bounds.right)
                put("bottom", bounds.bottom)
            })
            put("className", className)
            put("packageName", packageName)
            if (viewIdResourceName != null) put("viewIdResourceName", viewIdResourceName)
            put("clickable", clickable)
            put("enabled", enabled)
            put("scrollable", scrollable)
            put("isTextField", isTextField)
            if (text != null) put("text", text)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): UiNode {
            val boundsJson = json.getJSONObject("bounds")
            val bounds = Rect(
                boundsJson.getInt("left"),
                boundsJson.getInt("top"),
                boundsJson.getInt("right"),
                boundsJson.getInt("bottom")
            )
            return UiNode(
                id = json.getString("id"),
                selector = NodeSelector.fromJson(json.getJSONObject("selector")),
                bounds = bounds,
                className = json.getString("className"),
                packageName = json.getString("packageName"),
                viewIdResourceName = if (json.has("viewIdResourceName")) json.getString("viewIdResourceName") else null,
                clickable = json.getBoolean("clickable"),
                enabled = json.getBoolean("enabled"),
                scrollable = json.getBoolean("scrollable"),
                isTextField = json.getBoolean("isTextField"),
                text = if (json.has("text")) json.getString("text") else null
            )
        }
    }
}

