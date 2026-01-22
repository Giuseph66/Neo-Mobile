package com.example.neo.llm

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.File

class DownloadReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
            return
        }
        val downloadId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        if (downloadId <= 0) {
            return
        }
        val tracker = DownloadTracker(context)
        val pending = tracker.getByDownloadId(downloadId) ?: return
        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        val cursor = dm.query(query) ?: return
        cursor.use {
            if (!cursor.moveToFirst()) {
                return
            }
            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            if (status == DownloadManager.STATUS_SUCCESSFUL) {
                val localUri =
                    cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                if (localUri.isNullOrEmpty()) {
                    tracker.remove(pending.modelId)
                    LocalLlmPlugin.emitEvent(
                        mapOf(
                            "type" to "download_error",
                            "modelId" to pending.modelId,
                            "message" to "Arquivo nao encontrado",
                            "fileName" to pending.fileName
                        )
                    )
                    return
                }
                val store = ModelStore(context)
                if (store.getModelById(pending.modelId) != null) {
                    tracker.remove(pending.modelId)
                    return
                }
                val dest = File(context.filesDir, "models/${pending.fileName}")
                dest.parentFile?.mkdirs()
                val moved = try {
                    val uri = Uri.parse(localUri)
                    when (uri.scheme) {
                        "file", null -> {
                            val path = uri.path
                            if (path.isNullOrEmpty()) {
                                false
                            } else {
                                val file = File(path)
                                if (file.absolutePath != dest.absolutePath) {
                                    file.copyTo(dest, overwrite = true)
                                    file.delete()
                                }
                                true
                            }
                        }
                        else -> {
                            context.contentResolver.openInputStream(uri)?.use { input ->
                                dest.outputStream().use { output ->
                                    input.copyTo(output)
                                }
                            }
                            true
                        }
                    }
                } catch (e: Exception) {
                    false
                }
                if (!moved) {
                    tracker.remove(pending.modelId)
                    LocalLlmPlugin.emitEvent(
                        mapOf(
                            "type" to "download_error",
                            "modelId" to pending.modelId,
                            "message" to "Falha ao copiar arquivo",
                            "fileName" to pending.fileName
                        )
                    )
                    return
                }
                store.addModelFromPath(dest.absolutePath, pending.fileName, pending.modelId)
                tracker.remove(pending.modelId)
                LocalLlmPlugin.emitEvent(
                    mapOf(
                        "type" to "download_progress",
                        "modelId" to pending.modelId,
                        "progress01" to 1.0,
                        "fileName" to pending.fileName,
                        "downloadedBytes" to dest.length(),
                        "totalBytes" to dest.length()
                    )
                )
            } else if (status == DownloadManager.STATUS_FAILED) {
                tracker.remove(pending.modelId)
                LocalLlmPlugin.emitEvent(
                    mapOf(
                        "type" to "download_error",
                        "modelId" to pending.modelId,
                        "message" to "Falha no download",
                        "fileName" to pending.fileName
                    )
                )
            }
        }
    }
}
