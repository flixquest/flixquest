package dev.beamlak.flixquest_v2.downloads

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.TrackSelectionParameters
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.DataSourceInputStream
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.dash.offline.DashDownloader
import androidx.media3.exoplayer.hls.offline.HlsDownloader
import androidx.media3.exoplayer.offline.DefaultDownloadIndex
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadHelper
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadProgress
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.Downloader
import androidx.media3.exoplayer.offline.DownloaderFactory
import androidx.media3.exoplayer.offline.ProgressiveDownloader
import androidx.media3.exoplayer.scheduler.Requirements
import org.json.JSONArray
import org.json.JSONObject
import uz.shs.better_player_plus.DisguisedSegmentDataSource
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

@UnstableApi
class StreamDownloadStore private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val databaseProvider = StandaloneDatabaseProvider(appContext)
    private val downloadIndex = DefaultDownloadIndex(databaseProvider)
    private val downloadExecutor: ExecutorService = Executors.newFixedThreadPool(4)
    private val subtitleDirectory = File(appContext.filesDir, "offline_subtitles")

    private val recovery = DownloadRecoveryState(File(appContext.filesDir, "offline_requests"))
    private val sourceResolver = DownloadSourceResolver()

    val cache = SimpleCache(
        File(appContext.filesDir, "offline_streams"),
        NoOpCacheEvictor(),
        databaseProvider,
    )

    val downloadManager = DownloadManager(
        appContext,
        downloadIndex,
        DownloaderFactory { request ->
            RecoveringDownloader(request, recovery,
                create = { current, previous -> createDownloader(current, previous) },
                refresh = ::refreshRequest,
                clearCache = { current ->
                    val namespace = DownloadRecoveryState.namespace(current)
                    if (namespace.isNotEmpty()) {
                        cache.keys.filter { it.startsWith(namespace) }.forEach(cache::removeResource)
                    }
                },
            )
        },
    ).apply {
        maxParallelDownloads = 2
        requirements = Requirements(Requirements.NETWORK)
    }

    fun prepareRequest(
        arguments: Map<*, *>,
        callback: (Result<DownloadRequest>) -> Unit,
    ) {
        val id = arguments["id"] as? String
        val url = arguments["url"] as? String
        val format = arguments["format"] as? String
        if (id.isNullOrBlank() || url.isNullOrBlank() || format.isNullOrBlank()) {
            callback(Result.failure(IllegalArgumentException("A download id, URL, and format are required.")))
            return
        }

        val metadata = metadataJson(arguments)
        val helper = try {
            createHelper(arguments, id, url, format)
        } catch (error: Exception) {
            callback(Result.failure(error))
            return
        }

        val handler = Handler(Looper.getMainLooper())
        val finished = AtomicBoolean(false)
        fun complete(result: Result<DownloadRequest>) {
            if (!finished.compareAndSet(false, true)) return
            handler.removeCallbacksAndMessages(helper)
            helper.release()
            callback(result)
        }
        handler.postAtTime(
            { complete(Result.failure(IOException("Download preparation timed out."))) },
            helper,
            android.os.SystemClock.uptimeMillis() + 60_000L,
        )
        helper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper, tracksInfoAvailable: Boolean) {
                if (finished.get()) return
                try {
                    val selection = arguments["audioTrack"] as? Map<*, *>
                    if (selection != null) {
                        check(tracksInfoAvailable) { "Audio track information is unavailable." }
                        for (period in 0 until helper.periodCount) {
                            val override = DownloadAudioTracks.findOverride(helper.getTracks(period), selection)
                            // Never silently substitute the default language if a manifest changed.
                            checkNotNull(override) { "The selected audio track is no longer available." }
                            helper.replaceTrackSelections(
                                period,
                                trackParameters(arguments).buildUpon()
                                    .setOverrideForType(override)
                                    .build(),
                            )
                            check(helper.getTracks(period).groups.any { group ->
                                group.mediaTrackGroup == override.mediaTrackGroup &&
                                    override.trackIndices.all { group.isTrackSelected(it) }
                            }) { "The selected audio track could not be selected for download." }
                        }
                    }
                    if (metadata.optJSONObject("source") != null) {
                        check(tracksInfoAvailable) { "The original download tracks are unavailable." }
                        val expected = metadata.optJSONArray("selectedTracks")
                        if (expected != null) DownloadTrackIdentity.restore(helper, expected, trackParameters(arguments))
                        metadata.put("selectedTracks", DownloadTrackIdentity.capture(helper))
                    }
                } catch (error: Exception) {
                    complete(Result.failure(error))
                    return
                }
                // DownloadHelper (and its DefaultTrackSelector) is bound to the
                // looper on which preparation completes. Subtitle I/O belongs
                // on the worker pool, but getDownloadRequest() and release()
                // must return to this looper or Media3 throws and terminates
                // the process.
                val helperHandler = Handler(
                    checkNotNull(Looper.myLooper()) {
                        "DownloadHelper prepared without an application looper."
                    },
                )
                downloadExecutor.execute {
                    try {
                        downloadSubtitle(arguments, id, metadata)
                    } catch (error: Exception) {
                        helperHandler.post {
                            complete(Result.failure(error))
                        }
                        return@execute
                    }
                    helperHandler.post {
                        if (finished.get()) return@post
                        val preparedRequest = runCatching {
                            helper.getDownloadRequest(
                                id,
                                metadata.toString().toByteArray(StandardCharsets.UTF_8),
                            )
                        }
                        complete(preparedRequest)
                    }
                }
            }

            override fun onPrepareError(helper: DownloadHelper, error: java.io.IOException) {
                complete(Result.failure(error))
            }
        })
    }

    /** Media3 reads HLS EXT-X-MEDIA, DASH adaptation sets and in-band audio. */
    fun getAudioTracks(arguments: Map<*, *>, callback: (Result<List<Map<String, Any?>>>) -> Unit) {
        val helper = try {
            createHelper(
                arguments,
                "audio_inspection",
                requireNotNull(arguments["url"] as? String),
                requireNotNull(arguments["format"] as? String),
            )
        } catch (error: Exception) {
            callback(Result.failure(error))
            return
        }
        val handler = Handler(Looper.getMainLooper())
        var finished = false
        val timeout = Runnable {
            finished = true
            helper.release()
            callback(Result.failure(java.io.IOException("Audio inspection timed out.")))
        }
        handler.postDelayed(timeout, 30_000L)
        helper.prepare(object : DownloadHelper.Callback {
            override fun onPrepared(helper: DownloadHelper, tracksInfoAvailable: Boolean) {
                if (finished) return
                finished = true
                handler.removeCallbacks(timeout)
                val result = runCatching {
                    if (tracksInfoAvailable && helper.periodCount > 0) {
                        DownloadAudioTracks.choices(helper.getTracks(0))
                    } else {
                        emptyList()
                    }
                }
                helper.release()
                callback(result)
            }

            override fun onPrepareError(helper: DownloadHelper, error: java.io.IOException) {
                if (finished) return
                finished = true
                handler.removeCallbacks(timeout)
                helper.release()
                callback(Result.failure(error))
            }
        })
    }

    private fun trackParameters(arguments: Map<*, *>): TrackSelectionParameters {
        val maxVideoHeight = (arguments["maxVideoHeight"] as? Number)?.toInt()
            ?.takeIf { it > 0 }

        return TrackSelectionParameters.Builder(appContext)
            .setForceHighestSupportedBitrate(true)
            .apply {
                if (maxVideoHeight != null) {
                    setMaxVideoSize(Int.MAX_VALUE, maxVideoHeight)
                }
            }
            .build()
    }

    private fun createHelper(arguments: Map<*, *>, id: String, url: String, format: String): DownloadHelper {
        val mimeType = when (format.lowercase()) {
            "hls" -> MimeTypes.APPLICATION_M3U8
            "dash" -> MimeTypes.APPLICATION_MPD
            else -> {
                throw IllegalArgumentException("Unsupported stream format: $format")
            }
        }
        val headers = metadataHeaders(metadataJson(arguments))
        val httpFactory = httpFactory(headers)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMimeType(mimeType)
            .setMediaId(id)
            .build()
        return DownloadHelper.Factory()
            .setRenderersFactory(DefaultRenderersFactory(appContext))
            .setDataSourceFactory(httpFactory)
            .setTrackSelectionParameters(trackParameters(arguments))
            .create(mediaItem)
    }

    fun originalRequest(id: String): DownloadRequest? = downloadIndex.getDownload(id)?.request

    fun getDownload(id: String): Download? = downloadIndex.getDownload(id)?.let(::effectiveDownload)

    private fun effectiveDownload(download: Download): Download {
        val resolved = runCatching { recovery.current(download.request) }
        val current = resolved.getOrDefault(download.request)
        if (current == download.request && resolved.isSuccess) return download
        return Download(current, if (resolved.isSuccess) download.state else Download.STATE_FAILED, download.startTimeMs, download.updateTimeMs,
            download.contentLength, download.stopReason,
            if (resolved.isSuccess) download.failureReason else Download.FAILURE_REASON_UNKNOWN,
            DownloadProgress().apply {
                bytesDownloaded = download.bytesDownloaded
                percentDownloaded = download.percentDownloaded
            })
    }

    fun getDownloads(): List<Download> {
        val result = mutableListOf<Download>()
        downloadIndex.getDownloads().use { cursor ->
            while (cursor.moveToNext()) result.add(effectiveDownload(cursor.download))
        }
        return result
    }

    fun readOnlyCacheFactory(request: DownloadRequest): CacheDataSource.Factory = CacheDataSource.Factory()
        .setCache(cache)
        .setCacheKeyFactory(DownloadCacheReuse.keyFactory(DownloadRecoveryState.namespace(request)))
        .setUpstreamDataSourceFactory(null)
        .setCacheWriteDataSinkFactory(null)

    /** Better Player calls this by reflection with no arguments (see proguard-rules.pro), so it
     * can't name the request. Each key resolves to whichever download's namespace holds it.
     */
    fun readOnlyCacheFactory(): CacheDataSource.Factory {
        val namespaces = getDownloads()
            .map { DownloadRecoveryState.namespace(it.request) }
            .filter { it.isNotEmpty() }
            .distinct()
        return CacheDataSource.Factory()
            .setCache(cache)
            .setCacheKeyFactory { spec ->
                val key = spec.key ?: spec.uri.toString()
                if (namespaces.any { key.startsWith(it) }) key
                else namespaces.firstOrNull { cache.getCachedSpans(it + key).isNotEmpty() }
                    ?.let { it + key } ?: key
            }
            .setUpstreamDataSourceFactory(null)
            .setCacheWriteDataSinkFactory(null)
    }

    fun downloadToMap(download: Download): Map<String, Any?> {
        val metadata = requestMetadata(download.request)
        val state = when (download.state) {
            Download.STATE_QUEUED -> "queued"
            Download.STATE_STOPPED -> "stopped"
            Download.STATE_DOWNLOADING -> "downloading"
            Download.STATE_COMPLETED -> "completed"
            Download.STATE_FAILED -> "failed"
            Download.STATE_REMOVING -> "removing"
            Download.STATE_RESTARTING -> "restarting"
            else -> "unknown"
        }
        val percent = download.percentDownloaded
            .takeIf { !it.isNaN() && it >= 0f }
            ?.toDouble() ?: if (download.state == Download.STATE_COMPLETED) 100.0 else 0.0
        return mapOf(
            "id" to download.request.id,
            "title" to metadata.optString("title", "Untitled"),
            "subtitle" to metadata.optString("subtitle").ifBlank { null },
            "mediaType" to metadata.optString("mediaType", "video"),
            "quality" to metadata.optString("quality", "Auto"),
            "audioTrackName" to metadata.optString("audioTrackName").ifBlank { null },
            "posterUrl" to metadata.optString("posterUrl").ifBlank { null },
            "state" to state,
            "progress" to percent,
            "bytesDownloaded" to download.bytesDownloaded,
            "contentLength" to download.contentLength,
            "createdAt" to download.startTimeMs,
            "error" to if (download.state == Download.STATE_FAILED) "The download failed. Retry to try again." else null,
            "contentId" to metadata.optInt("contentId").takeIf { it > 0 },
            "seasonNumber" to metadata.optInt("seasonNumber").takeIf { it >= 0 },
            "episodeNumber" to metadata.optInt("episodeNumber").takeIf { it >= 0 },
            "offlineSubtitlePath" to metadata.optString("offlineSubtitlePath").ifBlank { null },
            "offlineSubtitleName" to metadata.optString("offlineSubtitleName").ifBlank { null },
        )
    }

    fun deleteSubtitle(id: String) {
        subtitleFile(id, "vtt").delete()
        subtitleFile(id, "srt").delete()
    }

    private fun metadataJson(arguments: Map<*, *>): JSONObject = JSONObject().apply {
        put("title", arguments["title"] as? String ?: "Untitled")
        put("subtitle", arguments["subtitle"] as? String ?: "")
        put("mediaType", arguments["mediaType"] as? String ?: "video")
        put("quality", arguments["quality"] as? String ?: "Auto")
        put("posterUrl", arguments["posterUrl"] as? String ?: "")
        put("format", arguments["format"] as? String ?: "")
        put("maxVideoHeight", arguments["maxVideoHeight"] ?: JSONObject.NULL)
        (arguments["source"] as? Map<*, *>)?.let {
            put("source", JSONObject(it))
            put("cacheNamespace", arguments["cacheNamespace"] as? String ?: DownloadRecoveryState.newNamespace())
        }
        (arguments["selectedTracks"] as? List<*>)?.let { put("selectedTracks", JSONArray(it)) }
        for (key in listOf("offlineSubtitlePath", "offlineSubtitleName")) {
            (arguments[key] as? String)?.let { put(key, it) }
        }
        put("audioTrackName", arguments["audioTrackName"] as? String ?: "")
        (arguments["audioTrack"] as? Map<*, *>)?.let { put("audioTrack", JSONObject(it)) }
        put("contentId", (arguments["contentId"] as? Number)?.toInt() ?: 0)
        put("seasonNumber", (arguments["seasonNumber"] as? Number)?.toInt() ?: -1)
        put("episodeNumber", (arguments["episodeNumber"] as? Number)?.toInt() ?: -1)
        val headers = JSONObject()
        (arguments["headers"] as? Map<*, *>)?.forEach { (key, value) ->
            if (key is String && value is String) headers.put(key, value)
        }
        put("headers", headers)
    }

    private fun downloadSubtitle(arguments: Map<*, *>, id: String, metadata: JSONObject) {
        val url = arguments["subtitleTrackUrl"] as? String
        if (url.isNullOrBlank()) return
        val name = (arguments["subtitleTrackName"] as? String).orEmpty()
            .ifBlank { "Original subtitle" }
        val extension = if (Uri.parse(url).path?.lowercase()?.endsWith(".srt") == true) {
            "srt"
        } else {
            "vtt"
        }
        if (!subtitleDirectory.exists() && !subtitleDirectory.mkdirs()) return
        deleteSubtitle(id)
        val output = subtitleFile(id, extension)
        val headers = buildMap {
            (arguments["subtitleTrackHeaders"] as? Map<*, *>)?.forEach { (key, value) ->
                if (key is String && value is String) put(key, value)
            }
        }
        try {
            val dataSource = httpFactory(headers).createDataSource()
            DataSourceInputStream(dataSource, DataSpec(Uri.parse(url))).use { input ->
                output.outputStream().use(input::copyTo)
            }
            if (output.length() > 0) {
                metadata.put("offlineSubtitlePath", output.absolutePath)
                metadata.put("offlineSubtitleName", name)
            } else {
                output.delete()
            }
        } catch (_: Exception) {
            output.delete()
            // A subtitle failure must not prevent the video itself downloading.
        }
    }

    private fun subtitleFile(id: String, extension: String): File {
        val safeId = id.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        return File(subtitleDirectory, "$safeId.$extension")
    }

    private fun createDownloader(request: DownloadRequest, previous: List<DownloadRequest>): Downloader {
        val namespace = DownloadRecoveryState.namespace(request)
        val upstream = DownloadCacheReuse.upstream(cache, namespace,
            previous.map(DownloadRecoveryState::namespace).filter { it.isNotEmpty() },
            mediaFactory(request.mimeType, httpFactory(metadataHeaders(requestMetadata(request)))))
        val factory = CacheDataSource.Factory().setCache(cache)
            .setCacheKeyFactory(DownloadCacheReuse.keyFactory(namespace))
            .setUpstreamDataSourceFactory(upstream)
        val item = request.toMediaItem()
        return when (request.mimeType) {
            MimeTypes.APPLICATION_M3U8 -> HlsDownloader(item, factory, downloadExecutor)
            MimeTypes.APPLICATION_MPD -> DashDownloader(item, factory, downloadExecutor)
            else -> ProgressiveDownloader(item, factory, downloadExecutor)
        }
    }

    /** Runs on Media3's download thread while the service remains active. */
    private fun refreshRequest(request: DownloadRequest, cancelled: () -> Boolean): DownloadRequest {
        val arguments = sourceResolver.resolve(request).toMutableMap().apply {
            put("cacheNamespace", DownloadRecoveryState.newNamespace())
        }
        if (cancelled()) throw InterruptedException("Download cancelled")
        val completed = CountDownLatch(1)
        var prepared: Result<DownloadRequest>? = null
        Handler(Looper.getMainLooper()).post {
            if (cancelled()) completed.countDown() else {
                prepareRequest(arguments) { result -> prepared = result; completed.countDown() }
            }
        }
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(65)
        while (!completed.await(100, TimeUnit.MILLISECONDS)) {
            if (cancelled()) throw InterruptedException("Download cancelled")
            if (System.nanoTime() > deadline) throw IOException("Download renewal timed out. Retry later.")
        }
        if (cancelled()) throw InterruptedException("Download cancelled")
        return prepared?.getOrThrow() ?: throw IOException("Download renewal was interrupted.")
    }

    companion object {
        @Volatile
        private var instance: StreamDownloadStore? = null

        fun get(context: Context): StreamDownloadStore = instance ?: synchronized(this) {
            instance ?: StreamDownloadStore(context).also { instance = it }
        }

        fun requestMetadata(request: DownloadRequest): JSONObject = try {
            JSONObject(String(request.data, StandardCharsets.UTF_8))
        } catch (_: Exception) {
            JSONObject()
        }

        fun metadataHeaders(metadata: JSONObject): Map<String, String> {
            val headers = metadata.optJSONObject("headers") ?: return emptyMap()
            return buildMap {
                headers.keys().forEach { key -> put(key, headers.optString(key)) }
            }
        }

        fun httpFactory(headers: Map<String, String>): DefaultHttpDataSource.Factory =
            DefaultHttpDataSource.Factory()
                .setAllowCrossProtocolRedirects(true)
                .setUserAgent("FlixQuest/4.0")
                .setDefaultRequestProperties(headers)

        /** HLS segments can arrive hidden in images; unwrap them before caching, as the player does. */
        fun mediaFactory(mimeType: String?, http: DataSource.Factory): DataSource.Factory =
            if (mimeType == MimeTypes.APPLICATION_M3U8) DisguisedSegmentDataSource.Factory(http) else http
    }
}
