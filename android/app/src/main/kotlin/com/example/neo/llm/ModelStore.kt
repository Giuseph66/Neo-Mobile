package com.example.neo.llm

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

class ModelStore(private val context: Context) {
    private val modelsDir: File = File(context.filesDir, "models")
    private val indexFile: File = File(modelsDir, "index.json")

    init {
        if (!modelsDir.exists()) {
            modelsDir.mkdirs()
        }
        if (!indexFile.exists()) {
            writeIndex(JSONArray(), null)
        }
    }

    fun listModels(): List<ModelEntry> {
        val index = readIndex()
        val list = mutableListOf<ModelEntry>()
        val models = index.getJSONArray("models")
        for (i in 0 until models.length()) {
            val obj = models.getJSONObject(i)
            list.add(ModelEntry.fromJson(obj))
        }
        return list
    }

    fun addModel(sourceFile: File): ModelEntry {
        val id = UUID.randomUUID().toString()
        val name = sourceFile.name
        val dest = File(modelsDir, name)
        sourceFile.copyTo(dest, overwrite = true)
        val entry = ModelEntry(
            id = id,
            name = name,
            path = dest.absolutePath,
            sizeBytes = dest.length(),
            quantHint = quantHintFor(name)
        )
        val index = readIndex()
        val models = index.getJSONArray("models")
        models.put(entry.toJson())
        writeIndex(models, index.optString("activeId", null))
        return entry
    }

    fun addModelFromPath(path: String, nameOverride: String? = null, id: String? = null): ModelEntry {
        val src = File(path)
        val destName = nameOverride ?: src.name
        val dest = File(modelsDir, destName)
        if (src.absolutePath != dest.absolutePath) {
            src.copyTo(dest, overwrite = true)
        }
        val entry = ModelEntry(
            id = id ?: UUID.randomUUID().toString(),
            name = destName,
            path = dest.absolutePath,
            sizeBytes = dest.length(),
            quantHint = quantHintFor(destName)
        )
        val index = readIndex()
        val models = index.getJSONArray("models")
        models.put(entry.toJson())
        writeIndex(models, index.optString("activeId", null))
        return entry
    }

    fun setActiveModel(id: String) {
        val index = readIndex()
        val models = index.getJSONArray("models")
        writeIndex(models, id)
    }

    fun getActiveModelId(): String? {
        val index = readIndex()
        return index.optString("activeId", null)
    }

    fun getModelById(id: String): ModelEntry? {
        return listModels().firstOrNull { it.id == id }
    }

    fun removeModel(id: String): Boolean {
        val index = readIndex()
        val models = index.getJSONArray("models")
        val newModels = JSONArray()
        var removed: ModelEntry? = null
        for (i in 0 until models.length()) {
            val obj = models.getJSONObject(i)
            val entry = ModelEntry.fromJson(obj)
            if (entry.id == id) {
                removed = entry
            } else {
                newModels.put(obj)
            }
        }
        if (removed == null) {
            return false
        }
        File(removed.path).delete()
        val activeId = index.optString("activeId", null)
        val nextActive = if (activeId == id) null else activeId
        writeIndex(newModels, nextActive)
        return true
    }

    private fun readIndex(): JSONObject {
        if (!indexFile.exists()) {
            return JSONObject().apply {
                put("models", JSONArray())
                put("activeId", JSONObject.NULL)
            }
        }
        val content = indexFile.readText()
        return JSONObject(content)
    }

    private fun writeIndex(models: JSONArray, activeId: String?) {
        val obj = JSONObject()
        obj.put("models", models)
        if (activeId == null) {
            obj.put("activeId", JSONObject.NULL)
        } else {
            obj.put("activeId", activeId)
        }
        indexFile.writeText(obj.toString())
    }

    private fun quantHintFor(name: String): String {
        val regex = Regex("Q\\d+[_A-Z]*")
        val match = regex.find(name)
        return match?.value ?: "GGUF"
    }
}

data class ModelEntry(
    val id: String,
    val name: String,
    val path: String,
    val sizeBytes: Long,
    val quantHint: String?
) {
    fun toMap(loaded: Boolean): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to name,
            "path" to path,
            "sizeBytes" to sizeBytes,
            "quantHint" to quantHint,
            "loaded" to loaded
        )
    }

    fun toJson(): JSONObject {
        val obj = JSONObject()
        obj.put("id", id)
        obj.put("name", name)
        obj.put("path", path)
        obj.put("sizeBytes", sizeBytes)
        obj.put("quantHint", quantHint)
        return obj
    }

    companion object {
        fun fromJson(obj: JSONObject): ModelEntry {
            return ModelEntry(
                id = obj.optString("id"),
                name = obj.optString("name"),
                path = obj.optString("path"),
                sizeBytes = obj.optLong("sizeBytes"),
                quantHint = obj.optString("quantHint", null)
            )
        }
    }
}
