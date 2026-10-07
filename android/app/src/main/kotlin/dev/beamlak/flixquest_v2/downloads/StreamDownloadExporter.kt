package dev.beamlak.flixquest_v2.downloads

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.text.format.Formatter
import android.util.Log
import androidx.media3.common.Format
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSourceBitmapLoader
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.transformer.AssetLoader
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultAssetLoaderFactory
import androidx.media3.transformer.DefaultDecoderFactory
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMp4Muxer
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import java.io.File
import java.util.concurrent.CancellationException

@UnstableApi
class StreamDownloadExporter(
    context: Context,
    private val store: StreamDownloadStore,
) {
    private val appContext = context.applicationContext
    // Exported files are user-visible artifacts and must survive app restarts
    // and Android cache cleanup. The download cache itself remains private,
    // while this directory keeps completed conversion work reusable.
    private val exportDirectory = File(appContext.filesDir, "offline_exports")
    private var activeExportId: String? = null
    private var activeTransformer: Transformer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbacks = mutableListOf<(Result<File>) -> Unit>()

    fun export(downloadId: String, callback: (Result<File>) -> Unit) {
        val download = store.getDownload(downloadId)
        if (download == null || download.state != Download.STATE_COMPLETED) {
            callback(Result.failure(IllegalStateException("The download must finish before it can be exported.")))
            return
        }

        val output = outputFile(download)
        if (output.isFile && output.length() > 0) {
            callback(Result.success(output))
            return
        }
        if (activeExportId == downloadId) {
            callbacks.add(callback)
            return
        }
        if (activeExportId != null) {
            callback(Result.failure(IllegalStateException("Another video is already being prepared.")))
            return
        }
        if (!exportDirectory.exists() && !exportDirectory.mkdirs()) {
            callback(Result.failure(IllegalStateException("Could not create the video export directory.")))
            return
        }

        if (!hasSpaceFor(download)) {
            callback(Result.failure(notEnoughStorage(download, cause = null)))
            return
        }

        activeExportId = downloadId
        callbacks.add(callback)
        startTransformer(download, output, inAppMuxer = false)
    }

    /**
     * Remuxes [download] into [output]. Android's MediaMuxer rejects some
     * HLS/DASH sample streams (it fails while writing or finalising the file),
     * so a muxing failure is retried once with Media3's own MP4 muxer.
     */
    private fun startTransformer(download: Download, output: File, inAppMuxer: Boolean) {
        val downloadId = download.request.id
        val mediaSourceFactory = DefaultMediaSourceFactory(store.readOnlyCacheFactory())
        val assetLoaderFactory = DefaultAssetLoaderFactory(
            appContext,
            DefaultDecoderFactory.Builder(appContext).build(),
            Clock.DEFAULT,
            mediaSourceFactory,
            DataSourceBitmapLoader(appContext),
        )
        val listener = object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                finish(Result.success(output))
            }

            override fun onError(
                composition: Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                output.delete()
                Log.e(
                    TAG,
                    "Export of $downloadId failed with the " +
                        "${if (inAppMuxer) "in-app" else "framework"} muxer " +
                        "(${exportException.errorCodeName})",
                    exportException,
                )
                if (!inAppMuxer && exportException.isMuxingError() && hasSpaceFor(download)) {
                    // Start the retry outside the failed Transformer's callback.
                    mainHandler.post {
                        if (activeExportId == downloadId) {
                            startTransformer(download, output, inAppMuxer = true)
                        }
                    }
                    return
                }
                finish(Result.failure(describeFailure(download, exportException)))
            }
        }
        try {
            activeTransformer = Transformer.Builder(appContext)
                .setAssetLoaderFactory(
                    SquarePixelAspectAssetLoaderFactory(assetLoaderFactory),
                )
                .apply { if (inAppMuxer) setMuxerFactory(InAppMp4Muxer.Factory()) }
                .addListener(listener)
                .build()
                .also { it.start(download.request.toMediaItem(), output.absolutePath) }
        } catch (error: Exception) {
            output.delete()
            finish(Result.failure(describeFailure(download, error)))
        }
    }

    fun deleteExport(downloadId: String) {
        if (activeExportId == downloadId) {
            activeTransformer?.cancel()
            finish(Result.failure(CancellationException("Video export was cancelled.")))
        }
        exportDirectory.listFiles()
            ?.filter { it.name.endsWith("-${Integer.toHexString(downloadId.hashCode())}.mp4") }
            ?.forEach(File::delete)
    }

    /** Returns the remuxer's real progress when the current export exposes it. */
    fun progress(downloadId: String): Map<String, Any?> {
        if (activeExportId != downloadId) {
            return mapOf("state" to "idle", "progress" to null)
        }
        val transformer = activeTransformer
            ?: return mapOf("state" to "starting", "progress" to null)
        val holder = ProgressHolder()
        return when (transformer.getProgress(holder)) {
            Transformer.PROGRESS_STATE_AVAILABLE -> mapOf(
                "state" to "available",
                "progress" to holder.progress,
            )
            Transformer.PROGRESS_STATE_WAITING_FOR_AVAILABILITY ->
                mapOf("state" to "starting", "progress" to null)
            Transformer.PROGRESS_STATE_UNAVAILABLE ->
                mapOf("state" to "unavailable", "progress" to null)
            else -> mapOf("state" to "starting", "progress" to null)
        }
    }

    private fun finish(result: Result<File>) {
        val completedCallbacks = callbacks.toList()
        callbacks.clear()
        activeTransformer = null
        activeExportId = null
        completedCallbacks.forEach { it(result) }
    }

    /** The remuxed MP4 is about the size of the cached segments, plus headroom. */
    private fun requiredBytes(download: Download): Long =
        download.bytesDownloaded + EXPORT_HEADROOM_BYTES

    private fun hasSpaceFor(download: Download): Boolean =
        exportDirectory.usableSpace >= requiredBytes(download)

    private fun notEnoughStorage(download: Download, cause: Throwable?): Exception {
        val shortfall = (requiredBytes(download) - exportDirectory.usableSpace)
            .coerceAtLeast(EXPORT_HEADROOM_BYTES)
        return StreamDownloadExportException(
            code = "EXPORT_NO_SPACE",
            message = "There isn't enough free storage to prepare this video. " +
                "Free up about ${Formatter.formatShortFileSize(appContext, shortfall)} " +
                "and try again.",
            cause = cause,
        )
    }

    private fun describeFailure(download: Download, error: Throwable): Exception {
        val outOfSpace = error.causes().any {
            val message = it.message.orEmpty()
            message.contains("ENOSPC") || message.contains("No space left", ignoreCase = true)
        }
        if (outOfSpace) return notEnoughStorage(download, error)
        if (error is ExportException && error.isMuxingError()) {
            return StreamDownloadExportException(
                code = "EXPORT_UNSUPPORTED",
                message = "This video can't be converted for other players. " +
                    "You can still watch it in FlixQuest.",
                cause = error,
            )
        }
        return StreamDownloadExportException(
            code = "EXPORT_FAILED",
            message = "Could not prepare this video. You can still watch it in FlixQuest.",
            cause = error,
        )
    }

    private fun ExportException.isMuxingError(): Boolean =
        errorCode == ExportException.ERROR_CODE_MUXING_FAILED ||
            errorCode == ExportException.ERROR_CODE_MUXING_TIMEOUT

    private fun outputFile(download: Download): File {
        val metadata = StreamDownloadStore.requestMetadata(download.request)
        val title = metadata.optString("title", "FlixQuest video")
            .replace(Regex("[^a-zA-Z0-9._ -]"), "_")
            .trim(' ', '.')
            .take(80)
            .ifBlank { "FlixQuest video" }
        val suffix = Integer.toHexString(download.request.id.hashCode())
        return File(exportDirectory, "$title-$suffix.mp4")
    }

    private companion object {
        const val TAG = "StreamDownloadExporter"
        const val EXPORT_HEADROOM_BYTES = 64L * 1024 * 1024
    }
}

/** An export failure carrying the method-channel error code Dart receives. */
class StreamDownloadExportException(
    val code: String,
    message: String,
    cause: Throwable?,
) : Exception(message, cause)

/** This throwable and its causes, outermost first. */
internal fun Throwable.causes(): Sequence<Throwable> =
    generateSequence(this) { it.cause?.takeIf { cause -> cause !== it } }.take(8)

/**
 * Some HLS/DASH manifests report a negligible non-square pixel ratio (for
 * example 1.001565). Transformer then needlessly decodes and re-encodes an
 * otherwise MP4-compatible stream. Normalizing that metadata keeps exports on
 * the encoded remux path and avoids a codec surface altogether.
 */
@UnstableApi
private class SquarePixelAspectAssetLoaderFactory(
    private val delegate: AssetLoader.Factory,
) : AssetLoader.Factory {
    override fun createAssetLoader(
        editedMediaItem: androidx.media3.transformer.EditedMediaItem,
        looper: Looper,
        listener: AssetLoader.Listener,
        compositionSettings: AssetLoader.CompositionSettings,
    ): AssetLoader {
        return delegate.createAssetLoader(
            editedMediaItem,
            looper,
            object : AssetLoader.Listener {
                override fun onDurationUs(durationUs: Long) = listener.onDurationUs(durationUs)

                override fun onTrackCount(trackCount: Int) = listener.onTrackCount(trackCount)

                override fun onTrackAdded(
                    inputFormat: Format,
                    supportedOutputTypes: Int,
                ): Boolean = listener.onTrackAdded(
                    normalizePixelAspect(inputFormat),
                    supportedOutputTypes,
                )

                override fun onOutputFormat(
                    format: Format,
                ): androidx.media3.transformer.SampleConsumer? =
                    listener.onOutputFormat(normalizePixelAspect(format))

                override fun onError(exportException: ExportException) =
                    listener.onError(exportException)
            },
            compositionSettings,
        )
    }

    private fun normalizePixelAspect(format: Format): Format {
        val ratio = format.pixelWidthHeightRatio
        return if (ratio.isFinite() && kotlin.math.abs(ratio - 1f) < 0.01f) {
            format.buildUpon().setPixelWidthHeightRatio(1f).build()
        } else {
            format
        }
    }
}
