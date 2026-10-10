package dev.beamlak.flixquest_v2.downloads

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.exoplayer.scheduler.Scheduler
import androidx.media3.exoplayer.scheduler.PlatformScheduler
import dev.beamlak.flixquest_v2.MainActivity
import dev.beamlak.flixquest_v2.R
import java.util.Locale

@UnstableApi
class StreamDownloadService : DownloadService(
    NOTIFICATION_ID,
    1_000L,
) {
    private val rateSamples = mutableMapOf<String, RateSample>()

    override fun onCreate() {
        createNotificationChannel()
        super.onCreate()
    }

    override fun getDownloadManager(): DownloadManager =
        StreamDownloadStore.get(applicationContext).downloadManager

    override fun getScheduler(): Scheduler = PlatformScheduler(this, SCHEDULER_JOB_ID)

    override fun getForegroundNotification(
        downloads: MutableList<Download>,
        notMetRequirements: Int,
    ): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val primary = downloads.firstOrNull { it.state == Download.STATE_DOWNLOADING }
            ?: downloads.firstOrNull()
        val metadata = primary?.let { StreamDownloadStore.requestMetadata(it.request) }
        val title = metadata?.optString("title")?.takeIf { it.isNotBlank() }
            ?: "video"
        val activeCount = downloads.count { it.state == Download.STATE_DOWNLOADING }
        val waitingForNetwork = notMetRequirements != 0
        val heading = when {
            waitingForNetwork -> "Waiting for network"
            downloads.size > 1 -> "Downloading ${downloads.size} videos"
            activeCount == 0 -> "Preparing $title"
            else -> "Downloading $title"
        }
        val progress = aggregateProgress(downloads)
        val transferRate = updateTransferRate(downloads)
        val details = if (downloads.size == 1 && primary != null) {
            singleDownloadDetails(primary, metadata, progress, transferRate)
        } else {
            aggregateDetails(downloads, progress, transferRate)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(heading)
            .setContentText(details)
            .setStyle(NotificationCompat.BigTextStyle().bigText(details))
            .setSubText("FlixQuest downloads")
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(false)
            .setProgress(100, progress ?: 0, progress == null)
            .build()
    }

    private fun singleDownloadDetails(
        download: Download,
        metadata: org.json.JSONObject?,
        progress: Int?,
        transferRate: Long,
    ): String {
        val quality = metadata?.optString("quality")?.takeIf { it.isNotBlank() }
        val subtitle = metadata?.optString("subtitle")?.takeIf { it.isNotBlank() }
        val total = totalBytes(download)
        return buildList {
            subtitle?.let(::add)
            quality?.let(::add)
            if (progress != null) add("$progress%")
            add(
                if (total != null) {
                    "${formatBytes(download.bytesDownloaded)} of ${total.second}${formatBytes(total.first)}"
                } else {
                    "${formatBytes(download.bytesDownloaded)} downloaded"
                },
            )
            if (transferRate > 0) add("${formatBytes(transferRate)}/s")
        }.joinToString("  •  ")
    }

    private fun aggregateDetails(
        downloads: List<Download>,
        progress: Int?,
        transferRate: Long,
    ): String = buildList {
        if (progress != null) add("$progress% complete")
        add("${formatBytes(downloads.sumOf { it.bytesDownloaded })} downloaded")
        if (transferRate > 0) add("${formatBytes(transferRate)}/s")
    }.joinToString("  •  ")

    private fun aggregateProgress(downloads: List<Download>): Int? {
        if (downloads.isEmpty()) return null
        val knownLengths = downloads.map { it.contentLength }.filter { it > 0 }
        if (knownLengths.size == downloads.size) {
            val total = knownLengths.sum()
            if (total > 0) {
                return ((downloads.sumOf { it.bytesDownloaded } * 100) / total)
                    .toInt()
                    .coerceIn(0, 100)
            }
        }
        val percentages = downloads.mapNotNull {
            it.percentDownloaded.takeIf { percent -> !percent.isNaN() && percent >= 0 }
        }
        return percentages.takeIf { it.isNotEmpty() }
            ?.average()
            ?.toInt()
            ?.coerceIn(0, 100)
    }

    private fun totalBytes(download: Download): Pair<Long, String>? {
        if (download.contentLength > 0) return download.contentLength to ""
        val percent = download.percentDownloaded
        if (download.bytesDownloaded <= 0 || percent.isNaN() || percent <= 0) return null
        return ((download.bytesDownloaded * 100) / percent).toLong() to "~"
    }

    private fun updateTransferRate(downloads: List<Download>): Long {
        val now = SystemClock.elapsedRealtime()
        val active = downloads.filter { it.state == Download.STATE_DOWNLOADING }
        val activeIds = active.map { it.request.id }.toSet()
        rateSamples.keys.retainAll(activeIds)
        return active.sumOf { download ->
            val previous = rateSamples[download.request.id]
            if (previous == null || download.bytesDownloaded < previous.bytes) {
                rateSamples[download.request.id] = RateSample(download.bytesDownloaded, now, 0.0)
                return@sumOf 0L
            }
            val elapsed = now - previous.sampledAt
            if (elapsed < 500) return@sumOf previous.rate.toLong()
            val measured = (download.bytesDownloaded - previous.bytes) * 1_000.0 / elapsed
            val smoothed = if (previous.rate <= 0) {
                measured
            } else {
                (measured * .65) + (previous.rate * .35)
            }
            val visibleRate = smoothed.takeIf { it >= 1_024 } ?: 0.0
            rateSamples[download.request.id] =
                RateSample(download.bytesDownloaded, now, visibleRate)
            visibleRate.toLong()
        }
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1_024) return "$bytes B"
        val kilobytes = bytes / 1_024.0
        if (kilobytes < 1_024) return String.format(Locale.US, "%.1f KB", kilobytes)
        val megabytes = kilobytes / 1_024.0
        if (megabytes < 1_024) return String.format(Locale.US, "%.1f MB", megabytes)
        return String.format(Locale.US, "%.2f GB", megabytes / 1_024.0)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Video downloads",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Progress for videos being saved for offline playback"
            },
        )
    }

    companion object {
        const val CHANNEL_ID = "stream_downloads"
        const val NOTIFICATION_ID = 4_301
        const val SCHEDULER_JOB_ID = 4_302
    }

    private data class RateSample(
        val bytes: Long,
        val sampledAt: Long,
        val rate: Double,
    )
}
