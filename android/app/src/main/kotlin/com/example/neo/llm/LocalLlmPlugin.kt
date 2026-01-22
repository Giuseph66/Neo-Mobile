package com.example.neo.llm

import android.app.Activity
import android.app.ActivityManager
import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class LocalLlmPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var engine: LocalLlmEngine? = null
    private var store: ModelStore? = null
    private var activeLoaded: Boolean = false
    private var activeRequestId: String? = null
    private var downloadManager: DownloadManager? = null
    private var downloadTracker: DownloadTracker? = null
    private var progressHandler: Handler? = null
    private var progressRunnable: Runnable? = null
    private val progressIntervalMs = 1500L
    private var lastProcCpuMs: Long = 0
    private var lastWallTimeMs: Long = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        engine = LocalLlmEngine()
        store = ModelStore(binding.applicationContext)
        downloadManager =
            binding.applicationContext.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        downloadTracker = DownloadTracker(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "local_llm")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "local_llm_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        resumePendingDownloads()
        startProgressMonitor()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        context = null
        stopProgressMonitor()
        downloadManager = null
        downloadTracker = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val safeContext = context
        if (safeContext == null) {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }
        when (call.method) {
            "getDeviceInfo" -> {
                val info = mapOf(
                    "abi" to Build.SUPPORTED_ABIS.joinToString(","),
                    "cores" to Runtime.getRuntime().availableProcessors(),
                    "ramEstimate" to Runtime.getRuntime().maxMemory(),
                    "engineReady" to (engine?.isNativeReady() == true),
                    "model" to Build.MODEL,
                    "manufacturer" to Build.MANUFACTURER
                )
                result.success(info)
            }
            "getProcessStats" -> {
                result.success(getProcessStats(safeContext))
            }
            "listModels" -> {
                val models = store?.listModels()?.map { entry ->
                    val loaded = entry.id == store?.getActiveModelId() && activeLoaded
                    entry.toMap(loaded)
                } ?: emptyList()
                result.success(models)
            }
            "setActiveModel" -> {
                val id = call.argument<String>("modelId")
                if (id == null) {
                    result.success(false)
                    return
                }
                store?.setActiveModel(id)
                activeLoaded = false
                result.success(true)
            }
            "getActiveModel" -> {
                val activeId = store?.getActiveModelId()
                val model = activeId?.let { store?.getModelById(it) }
                if (model == null) {
                    result.success(mapOf<String, Any>())
                } else {
                    result.success(model.toMap(activeLoaded))
                }
            }
            "importModel" -> {
                val uriString = call.argument<String>("fileUri")
                if (uriString == null) {
                    result.success(null)
                    return
                }
                val model = importModel(safeContext, uriString)
                result.success(model?.id)
            }
            "downloadModel" -> {
                val url = call.argument<String>("url")
                val fileName = call.argument<String>("fileName")
                if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.success(null)
                    return
                }
                downloadModel(safeContext, url, fileName, result)
            }
            "loadModel" -> {
                val id = call.argument<String>("modelId")
                val params = call.argument<Map<String, Any>>("params")
                if (id == null || params == null) {
                    result.success(false)
                    return
                }
                if (engine?.isNativeReady() != true) {
                    emitEventInternal(
                        mapOf(
                            "type" to "model_error",
                            "modelId" to id,
                            "message" to "JNI stub ativo. Integre o llama.cpp."
                        )
                    )
                    result.success(false)
                    return
                }
                val model = store?.getModelById(id)
                if (model == null) {
                    result.success(false)
                    return
                }
                val ctxLen = (params["ctxLen"] as? Number)?.toInt() ?: 2048
                val threads = (params["threads"] as? Number)?.toInt() ?: 4
                val loaded = engine?.loadModel(model.path, ctxLen, threads) ?: false
                activeLoaded = loaded
                emitEventInternal(mapOf("type" to "model_loaded", "modelId" to id))
                result.success(loaded)
            }
            "unloadModel" -> {
                engine?.unload()
                activeLoaded = false
                result.success(true)
            }
            "deleteModel" -> {
                val id = call.argument<String>("modelId")
                if (id == null) {
                    result.success(false)
                    return
                }
                val activeId = store?.getActiveModelId()
                if (activeId == id) {
                    engine?.unload()
                    activeLoaded = false
                }
                val removed = store?.removeModel(id) ?: false
                result.success(removed)
            }
            "generate" -> {
                val prompt = call.argument<String>("prompt") ?: ""
                val params = call.argument<Map<String, Any>>("params") ?: emptyMap()
                val temp = (params["temp"] as? Number)?.toDouble() ?: 0.7
                val topP = (params["topP"] as? Number)?.toDouble() ?: 0.9
                val topK = (params["topK"] as? Number)?.toInt() ?: 40
                val maxTokens = (params["maxTokens"] as? Number)?.toInt() ?: 256
                val requestId = UUID.randomUUID().toString()
                activeRequestId = requestId
                if (!activeLoaded) {
                    emitEventInternal(
                        mapOf(
                            "type" to "error",
                            "requestId" to requestId,
                            "message" to "Modelo nao carregado. Clique em Carregar Modelo."
                        )
                    )
                    result.success(requestId)
                    return
                }
                engine?.generate(
                    prompt = prompt,
                    temp = temp,
                    topP = topP,
                    topK = topK,
                    maxTokens = maxTokens,
                    onToken = { token ->
                        val tps = engine?.getLastTps() ?: 0.0
                        emitEventInternal(
                            mapOf(
                                "type" to "token",
                                "requestId" to requestId,
                                "textChunk" to token,
                                "tps" to tps
                            )
                        )
                    },
                    onDone = {
                        emitEventInternal(
                            mapOf(
                                "type" to "done",
                                "requestId" to requestId
                            )
                        )
                    },
                    onError = { message ->
                        emitEventInternal(
                            mapOf(
                                "type" to "error",
                                "requestId" to requestId,
                                "message" to message
                            )
                        )
                    }
                )
                result.success(requestId)
            }
            "stopGeneration" -> {
                engine?.stop()
                activeRequestId = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun importModel(context: Context, uriString: String): ModelEntry? {
        return if (uriString.startsWith("content://")) {
            val uri = Uri.parse(uriString)
            val fileName = queryName(context, uri) ?: "model.gguf"
            val dest = File(context.filesDir, "models/$fileName")
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output ->
                    input.copyTo(output)
                }
            }
            store?.addModelFromPath(dest.absolutePath, fileName)
        } else {
            val file = File(uriString)
            if (!file.exists()) {
                null
            } else {
                store?.addModel(file)
            }
        }
    }

    private fun downloadModel(
        context: Context,
        url: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        val modelId = UUID.randomUUID().toString()
        val dm = downloadManager
        val tracker = downloadTracker
        if (dm == null || tracker == null) {
            result.success(null)
            emitEventInternal(
                mapOf(
                    "type" to "download_error",
                    "modelId" to modelId,
                    "message" to "DownloadManager indisponivel"
                )
            )
            return
        }
        val request = DownloadManager.Request(Uri.parse(url))
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setTitle(fileName)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setMimeType("application/octet-stream")
            .setDestinationInExternalFilesDir(
                context,
                Environment.DIRECTORY_DOWNLOADS,
                fileName
            )
        val downloadId = dm.enqueue(request)
        tracker.add(PendingDownload(modelId, downloadId, fileName))
        emitEventInternal(
            mapOf(
                "type" to "download_progress",
                "modelId" to modelId,
                "progress01" to -1.0,
                "fileName" to fileName,
                "downloadedBytes" to 0L,
                "totalBytes" to -1L
            )
        )
        result.success(modelId)
    }

    private fun resumePendingDownloads() {
        val tracker = downloadTracker ?: return
        val dm = downloadManager ?: return
        val pending = tracker.all()
        if (pending.isEmpty()) {
            return
        }
        val ids = pending.map { it.downloadId }.toLongArray()
        val query = DownloadManager.Query().setFilterById(*ids)
        val cursor = dm.query(query) ?: return
        cursor.use {
            while (cursor.moveToNext()) {
                val downloadId =
                    cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID))
                val entry = pending.firstOrNull { it.downloadId == downloadId } ?: continue
                val status =
                    cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                when (status) {
                    DownloadManager.STATUS_SUCCESSFUL -> handleCompletedDownload(entry, cursor)
                    DownloadManager.STATUS_FAILED -> {
                        tracker.remove(entry.modelId)
                        emitEventInternal(
                            mapOf(
                                "type" to "download_error",
                                "modelId" to entry.modelId,
                                "message" to "Falha no download",
                                "fileName" to entry.fileName
                            )
                        )
                    }
                    else -> {
                        val total =
                            cursor.getLong(
                                cursor.getColumnIndexOrThrow(
                                    DownloadManager.COLUMN_TOTAL_SIZE_BYTES
                                )
                            )
                        val downloaded =
                            cursor.getLong(
                                cursor.getColumnIndexOrThrow(
                                    DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR
                                )
                            )
                        emitProgress(entry, downloaded, total)
                    }
                }
            }
        }
    }

    private fun startProgressMonitor() {
        if (progressRunnable != null) {
            return
        }
        progressHandler = Handler(Looper.getMainLooper())
        progressRunnable = object : Runnable {
            override fun run() {
                val tracker = downloadTracker
                val dm = downloadManager
                if (tracker != null && dm != null) {
                    val pending = tracker.all()
                    if (pending.isNotEmpty()) {
                        val ids = pending.map { it.downloadId }.toLongArray()
                        val query = DownloadManager.Query().setFilterById(*ids)
                        val cursor = dm.query(query)
                        cursor?.use {
                            while (cursor.moveToNext()) {
                                val downloadId =
                                    cursor.getLong(
                                        cursor.getColumnIndexOrThrow(
                                            DownloadManager.COLUMN_ID
                                        )
                                    )
                                val entry = pending.firstOrNull {
                                    it.downloadId == downloadId
                                } ?: continue
                                val status =
                                    cursor.getInt(
                                        cursor.getColumnIndexOrThrow(
                                            DownloadManager.COLUMN_STATUS
                                        )
                                    )
                                when (status) {
                                    DownloadManager.STATUS_SUCCESSFUL -> handleCompletedDownload(
                                        entry,
                                        cursor
                                    )
                                    DownloadManager.STATUS_FAILED -> {
                                        tracker.remove(entry.modelId)
                                        emitEventInternal(
                                            mapOf(
                                                "type" to "download_error",
                                                "modelId" to entry.modelId,
                                                "message" to "Falha no download",
                                                "fileName" to entry.fileName
                                            )
                                        )
                                    }
                                    else -> {
                                        val total =
                                            cursor.getLong(
                                                cursor.getColumnIndexOrThrow(
                                                    DownloadManager.COLUMN_TOTAL_SIZE_BYTES
                                                )
                                            )
                                        val downloaded =
                                            cursor.getLong(
                                                cursor.getColumnIndexOrThrow(
                                                    DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR
                                                )
                                            )
                                        emitProgress(entry, downloaded, total)
                                    }
                                }
                            }
                        }
                    }
                }
                progressHandler?.postDelayed(this, progressIntervalMs)
            }
        }
        progressHandler?.post(progressRunnable!!)
    }

    private fun stopProgressMonitor() {
        progressRunnable?.let { progressHandler?.removeCallbacks(it) }
        progressRunnable = null
        progressHandler = null
    }

    private fun emitProgress(entry: PendingDownload, downloaded: Long, total: Long) {
        val progress = if (total > 0) downloaded.toDouble() / total.toDouble() else -1.0
        emitEventInternal(
            mapOf(
                "type" to "download_progress",
                "modelId" to entry.modelId,
                "progress01" to progress,
                "fileName" to entry.fileName,
                "downloadedBytes" to downloaded,
                "totalBytes" to total
            )
        )
    }

    private fun handleCompletedDownload(entry: PendingDownload, cursor: android.database.Cursor? = null) {
        val safeContext = context ?: return
        val tracker = downloadTracker ?: return
        if (store?.getModelById(entry.modelId) != null) {
            tracker.remove(entry.modelId)
            return
        }
        val localUri = cursor?.getString(
            cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)
        ) ?: run {
            val dm = downloadManager ?: return
            val query = DownloadManager.Query().setFilterById(entry.downloadId)
            val queryCursor = dm.query(query) ?: return
            queryCursor.use {
                if (!it.moveToFirst()) {
                    return
                }
                it.getString(it.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
            }
        }
        if (localUri.isNullOrBlank()) {
            tracker.remove(entry.modelId)
            emitEventInternal(
                mapOf(
                    "type" to "download_error",
                    "modelId" to entry.modelId,
                    "message" to "Arquivo nao encontrado",
                    "fileName" to entry.fileName
                )
            )
            return
        }
        val dest = File(safeContext.filesDir, "models/${entry.fileName}")
        dest.parentFile?.mkdirs()
        val moved = moveDownloadedFile(safeContext, Uri.parse(localUri), dest)
        if (!moved) {
            tracker.remove(entry.modelId)
            emitEventInternal(
                mapOf(
                    "type" to "download_error",
                    "modelId" to entry.modelId,
                    "message" to "Falha ao copiar arquivo",
                    "fileName" to entry.fileName
                )
            )
            return
        }
        store?.addModelFromPath(dest.absolutePath, entry.fileName, entry.modelId)
        tracker.remove(entry.modelId)
        emitEventInternal(
            mapOf(
                "type" to "download_progress",
                "modelId" to entry.modelId,
                "progress01" to 1.0,
                "fileName" to entry.fileName,
                "downloadedBytes" to dest.length(),
                "totalBytes" to dest.length()
            )
        )
    }

    private fun moveDownloadedFile(context: Context, uri: Uri, dest: File): Boolean {
        return try {
            when (uri.scheme) {
                "file", null -> {
                    val file = File(uri.path ?: return false)
                    if (file.absolutePath != dest.absolutePath) {
                        file.copyTo(dest, overwrite = true)
                        file.delete()
                    }
                }
                else -> {
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(dest).use { output ->
                            input.copyTo(output)
                        }
                    }
                }
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun queryName(context: Context, uri: Uri): String? {
        val cursor = context.contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && nameIndex != -1) {
                return cursor.getString(nameIndex)
            }
        }
        return null
    }

    private fun getProcessStats(context: Context): Map<String, Any?> {
        val pid = Process.myPid()
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memInfo = am.getProcessMemoryInfo(intArrayOf(pid))
        val pssKb = memInfo.firstOrNull()?.totalPss ?: 0
        val rssKb = readVmRssKb(pid)
        val cpuPercent = readCpuPercent(pid)
        return mapOf(
            "cpuPercent" to cpuPercent,
            "pssKb" to pssKb,
            "rssKb" to rssKb
        )
    }

    private fun readVmRssKb(pid: Int): Int {
        return try {
            val lines = File("/proc/$pid/status").readLines()
            val line = lines.firstOrNull { it.startsWith("VmRSS:") } ?: return 0
            val parts = line.split(Regex("\\s+"))
            parts.getOrNull(1)?.toIntOrNull() ?: 0
        } catch (e: Exception) {
            0
        }
    }

    private fun readCpuPercent(pid: Int): Double {
        val wallNow = SystemClock.elapsedRealtime()
        val procNow = Process.getElapsedCpuTime()
        val deltaWall = wallNow - lastWallTimeMs
        val deltaProc = procNow - lastProcCpuMs
        lastWallTimeMs = wallNow
        lastProcCpuMs = procNow
        if (deltaWall <= 0L || deltaProc < 0L) {
            return 0.0
        }
        return (deltaProc.toDouble() / deltaWall.toDouble()) * 100.0
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

    private fun emitEventInternal(event: Map<String, Any?>) {
        LocalLlmPlugin.emitEvent(event)
    }

    companion object {
        private var eventSink: EventChannel.EventSink? = null
        private val staticHandler = Handler(Looper.getMainLooper())

        @JvmStatic
        fun emitEvent(event: Map<String, Any?>) {
            staticHandler.post {
                eventSink?.success(event)
            }
        }
    }
}
