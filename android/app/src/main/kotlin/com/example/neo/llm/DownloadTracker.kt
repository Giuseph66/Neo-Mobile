package com.example.neo.llm

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

class DownloadTracker(context: Context) {
    private val prefs = context.getSharedPreferences("llm_downloads", Context.MODE_PRIVATE)

    fun add(download: PendingDownload) {
        val list = load().toMutableList()
        list.removeAll { it.modelId == download.modelId }
        list.add(download)
        save(list)
    }

    fun remove(modelId: String) {
        val list = load().filterNot { it.modelId == modelId }
        save(list)
    }

    fun getByDownloadId(downloadId: Long): PendingDownload? {
        return load().firstOrNull { it.downloadId == downloadId }
    }

    fun all(): List<PendingDownload> = load()

    private fun load(): List<PendingDownload> {
        val raw = prefs.getString("downloads", null) ?: return emptyList()
        val json = JSONArray(raw)
        val list = mutableListOf<PendingDownload>()
        for (i in 0 until json.length()) {
            val obj = json.getJSONObject(i)
            list.add(
                PendingDownload(
                    modelId = obj.optString("modelId"),
                    downloadId = obj.optLong("downloadId"),
                    fileName = obj.optString("fileName")
                )
            )
        }
        return list
    }

    private fun save(list: List<PendingDownload>) {
        val json = JSONArray()
        list.forEach {
            val obj = JSONObject()
            obj.put("modelId", it.modelId)
            obj.put("downloadId", it.downloadId)
            obj.put("fileName", it.fileName)
            json.put(obj)
        }
        prefs.edit().putString("downloads", json.toString()).apply()
    }
}

data class PendingDownload(
    val modelId: String,
    val downloadId: Long,
    val fileName: String
)
