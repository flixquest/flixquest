package dev.beamlak.flixquest_v2.downloads

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.transformer.ExportException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

@UnstableApi
class StreamDownloadsBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    DownloadManager.Listener {
    private val appContext = activity.applicationContext
    val store: StreamDownloadStore = StreamDownloadStore.get(appContext)
    private val exporter = StreamDownloadExporter(appContext, store)
    private val fileExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var polling = false
    private var pendingSave: PendingSave? = null

    init {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        store.downloadManager.addListener(this)
        DownloadService.start(appContext, StreamDownloadService::class.java)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDownloads" -> runResult(result) { downloadMaps() }
            "enqueue" -> enqueue(call, result)
            "pause" -> withId(call, result) { id ->
                DownloadService.sendSetStopReason(
                    appContext,
                    StreamDownloadService::class.java,
                    id,
                    USER_PAUSED,
                    false,
                )
            }
            "resume" -> withId(call, result) { id ->
                DownloadService.sendSetStopReason(
                    appContext,
                    StreamDownloadService::class.java,
                    id,
                    Download.STOP_REASON_NONE,
                    false,
                )
            }
            "retry" -> withId(call, result) { id ->
                val download = store.getDownload(id)
                    ?: throw IllegalArgumentException("Download not found: $id")
                DownloadService.sendAddDownload(
                    appContext,
                    StreamDownloadService::class.java,
                    download.request,
                    true,
                )
            }
            "getExportProgress" -> exportProgress(call, result)
            "openExternal" -> exportForExternalPlayer(call, result)
            "saveCopy" -> exportForDocument(call, result)
            "remove" -> withId(call, result) { id ->
                exporter.deleteExport(id)
                store.deleteSubtitle(id)
                DownloadService.sendRemoveDownload(
                    appContext,
                    StreamDownloadService::class.java,
                    id,
                    false,
                )
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SAVE_COPY_REQUEST) return false
        val pending = pendingSave ?: return true
        pendingSave = null
        val destination = data?.data
        if (resultCode != Activity.RESULT_OK || destination == null) {
            pending.result.success(false)
            return true
        }
        fileExecutor.execute {
            try {
                appContext.contentResolver.openOutputStream(destination, "w").use { output ->
                    checkNotNull(output) { "Could not open the selected destination." }
                    pending.file.inputStream().use { input -> input.copyTo(output) }
                }
                mainHandler.post { pending.result.success(true) }
            } catch (error: Exception) {
                mainHandler.post {
                    pending.result.error("SAVE_COPY_FAILED", error.message, null)
                }
            }
        }
        return true
    }

    private fun exportForExternalPlayer(call: MethodCall, result: MethodChannel.Result) {
        withExportedFile(call, result) { file ->
            val uri = FileProvider.getUriForFile(
                appContext,
                "${appContext.packageName}.offline_files",
                file,
            )
            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "video/mp4")
                clipData = ClipData.newRawUri("Offline video", uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            check(viewIntent.resolveActivity(activity.packageManager) != null) {
                "No installed application can open this video."
            }
            activity.startActivity(Intent.createChooser(viewIntent, "Open video with"))
            result.success(null)
        }
    }

    private fun exportProgress(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        runResult(result) { exporter.progress(id) }
    }

    private fun exportForDocument(call: MethodCall, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("SAVE_IN_PROGRESS", "A save location is already being selected.", null)
            return
        }
        withExportedFile(call, result) { file ->
            pendingSave = PendingSave(file, result)
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "video/mp4"
                putExtra(Intent.EXTRA_TITLE, file.name)
            }
            try {
                activity.startActivityForResult(intent, SAVE_COPY_REQUEST)
            } catch (error: Exception) {
                pendingSave = null
                result.error("FILE_PICKER_UNAVAILABLE", error.message, null)
            }
        }
    }

    private fun withExportedFile(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (File) -> Unit,
    ) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        exporter.export(id) { exported ->
            mainHandler.post {
                exported.fold(
                    onSuccess = { file ->
                        try {
                            operation(file)
                        } catch (error: Exception) {
                            result.error("EXPORT_ACTION_FAILED", error.message, null)
                        }
                    },
                    onFailure = { error ->
                        result.error(
                            (error as? StreamDownloadExportException)?.code ?: "EXPORT_FAILED",
                            error.message,
                            causeSummary(error),
                        )
                    },
                )
            }
        }
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *> ?: run {
            result.error("INVALID_ARGUMENTS", "Download arguments are required.", null)
            return
        }
        val id = arguments["id"] as? String
        if (!id.isNullOrBlank() && store.getDownload(id)?.state == Download.STATE_COMPLETED) {
            result.error("ALREADY_DOWNLOADED", "This title is already downloaded.", null)
            return
        }
        store.prepareRequest(arguments) { prepared ->
            mainHandler.post {
                prepared.fold(
                    onSuccess = { request ->
                        try {
                            DownloadService.sendAddDownload(
                                appContext,
                                StreamDownloadService::class.java,
                                request,
                                true,
                            )
                            result.success(null)
                            emitDownloads()
                        } catch (error: Exception) {
                            result.error("ENQUEUE_FAILED", error.message, null)
                        }
                    },
                    onFailure = { error ->
                        result.error("PREPARE_FAILED", error.message, null)
                    },
                )
            }
        }
    }

    private fun withId(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (String) -> Unit,
    ) {
        val id = call.argument<String>("id")
        if (id.isNullOrBlank()) {
            result.error("INVALID_ID", "A download id is required.", null)
            return
        }
        runResult(result) {
            operation(id)
            null
        }
    }

    private fun runResult(result: MethodChannel.Result, operation: () -> Any?) {
        try {
            result.success(operation())
        } catch (error: Exception) {
            result.error("DOWNLOAD_ERROR", error.message, null)
        }
    }

    /** The cause chain, so error reports say why an export failed. */
    private fun causeSummary(error: Throwable): String? =
        error.causes().drop(1).joinToString(" <- ") { cause ->
            val code = (cause as? ExportException)?.let { "[${it.errorCodeName}]" }.orEmpty()
            "${cause.javaClass.simpleName}$code: ${cause.message}"
        }.ifEmpty { null }

    private fun downloadMaps(): List<Map<String, Any?>> =
        store.getDownloads().map(store::downloadToMap)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        emitDownloads()
        if (!polling) {
            polling = true
            mainHandler.post(progressPoller)
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        polling = false
        mainHandler.removeCallbacks(progressPoller)
    }

    private val progressPoller = object : Runnable {
        override fun run() {
            if (!polling) return
            emitDownloads()
            mainHandler.postDelayed(this, 750L)
        }
    }

    private fun emitDownloads() {
        val sink = eventSink ?: return
        try {
            sink.success(downloadMaps())
        } catch (error: Exception) {
            sink.error("DOWNLOAD_QUERY_FAILED", error.message, null)
        }
    }

    override fun onInitialized(downloadManager: DownloadManager) = emitDownloads()

    override fun onDownloadChanged(
        downloadManager: DownloadManager,
        download: Download,
        finalException: Exception?,
    ) = emitDownloads()

    override fun onDownloadRemoved(downloadManager: DownloadManager, download: Download) =
        emitDownloads()

    companion object {
        private const val METHOD_CHANNEL = "dev.beamlak.flixquest/stream_downloads"
        private const val EVENT_CHANNEL = "dev.beamlak.flixquest/stream_download_events"
        private const val USER_PAUSED = 1
        private const val SAVE_COPY_REQUEST = 4_303
    }

    private data class PendingSave(
        val file: File,
        val result: MethodChannel.Result,
    )
}
