package dev.beamlak.flixquest_v2.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import dev.beamlak.flixquest_v2.MainActivity
import dev.beamlak.flixquest_v2.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import kotlin.math.roundToInt
import org.json.JSONObject

private const val TAG = "FlixQuestWidget"

/** Under this width the poster column is dropped and everything stacks vertically. */
private const val COMPACT_WIDTH_DP = 190

/** What a launcher that reports no size gets: a 4x2 phone widget. */
private const val FALLBACK_WIDTH_DP = 320
private const val FALLBACK_HEIGHT_DP = 170

/**
 * Widget bitmaps are parcelled across to the launcher and the whole RemoteViews payload has to fit
 * in roughly a megabyte of Binder buffer, so each image is decoded down to the size its view
 * actually needs. The hero sits under a scrim where RGB_565 banding is invisible; the poster is the
 * focal artwork and stays ARGB_8888. The text is drawn as ALPHA_8 masks (see [WidgetText]).
 */
private const val HERO_TARGET_PX = 420
private const val POSTER_TARGET_PX = 240

private const val HOME_DEEP_LINK = "flixquest://home"

/**
 * The only copy that lives on this side of the bridge: it shows when the app has never filled the
 * widget in. Every other string is written by [HomeWidgetService] so it exists in exactly one place.
 */
private const val SYNC_TITLE = "Open FlixQuest"
private const val SYNC_SUBTITLE = "Tap to sync this widget"

/** The app hero card's text over artwork: white, its facts line at 85%. */
private const val ON_ART_TITLE = 0xFFFFFFFF.toInt()
private const val ON_ART_SUBTITLE = 0xD9FFFFFF.toInt()
private const val ON_ART_META = 0xB3FFFFFF.toInt()

/** The app's Dark palette, until the app has synced the theme it is actually running. */
private const val DEFAULT_PRIMARY = 0xFFF57C00.toInt()
private const val DEFAULT_SURFACE = 0xFF202120.toInt()
private const val DEFAULT_FOREGROUND = 0xFFF7F7F7.toInt()
private const val DEFAULT_MUTED = 0xFFA7A8A8.toInt()

/** Supporting copy on the plain surface: the foreground, stepped back like [ON_ART_SUBTITLE]. */
private const val SUBTITLE_ALPHA = 0xD9

/**
 * The app's type scale (AppType) brought down to widget size: the kicker in tracked caps, the
 * title in ExtraBold with the hero title's tight tracking, and the facts in Medium.
 */
private class SlotStyles(
    val eyebrow: WidgetTextStyle,
    val title: WidgetTextStyle,
    val subtitle: WidgetTextStyle,
    val meta: WidgetTextStyle,
)

private val WIDE_STYLES = SlotStyles(
    eyebrow = WidgetTextStyle(R.font.figtree_extrabold, 10f, tracking = 0.2f),
    title = WidgetTextStyle(
        R.font.figtree_extrabold, 19f, maxLines = 2, tracking = -0.02f, lineSpacing = 0.95f,
    ),
    subtitle = WidgetTextStyle(R.font.figtree_medium, 12f),
    meta = WidgetTextStyle(R.font.figtree_medium, 11f, maxLines = 2),
)

private val COMPACT_STYLES = SlotStyles(
    eyebrow = WidgetTextStyle(R.font.figtree_extrabold, 9f, tracking = 0.18f),
    title = WidgetTextStyle(
        R.font.figtree_extrabold, 16f, maxLines = 3, tracking = -0.015f, lineSpacing = 0.95f,
    ),
    subtitle = WidgetTextStyle(R.font.figtree_medium, 11f),
    meta = WidgetTextStyle(R.font.figtree_medium, 10f, maxLines = 2),
)

/**
 * One slot of the widget carries one fact. No field may restate a value another field already
 * shows, and none may repeat what [eyebrow] says: [subtitle] and [meta] are separate facts, and
 * [progress] is the only place a completion ratio is expressed.
 */
data class WidgetContent(
    val eyebrow: String,
    val title: String,
    val subtitle: String = "",
    val meta: String = "",
    /** Sharp thumbnail of the poster art. */
    val posterPath: String? = null,
    /** Full-bleed backdrop behind the text. A different image from [posterPath], never a copy. */
    val heroPath: String? = null,
    val deepLink: String,
    val progress: Int? = null,
)

abstract class FlixQuestWidgetProvider : HomeWidgetProvider() {
    abstract fun content(widgetData: SharedPreferences): WidgetContent

    private data class WidgetTheme(
        val primary: Int,
        val surface: Int,
        val foreground: Int,
        val muted: Int,
    )

    /** In dp: the portrait width and height, which is how a phone widget is nearly always seen. */
    private data class WidgetSize(val width: Int, val height: Int)

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            HomeWidgetPlugin.getData(context),
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val content = content(widgetData)
        val theme = WidgetTheme(
            primary = widgetData.safeInt("theme_primary", DEFAULT_PRIMARY),
            surface = widgetData.safeInt("theme_surface", DEFAULT_SURFACE),
            foreground = widgetData.safeInt("theme_foreground", DEFAULT_FOREGROUND),
            muted = widgetData.safeInt("theme_muted", DEFAULT_MUTED),
        )
        val text = WidgetText(context)
        // The text is wrapped to the widget's size, so the views are built once per size rather
        // than once per placed widget; same-sized copies share their bitmaps.
        val bySize = HashMap<WidgetSize, RemoteViews>(2)
        appWidgetIds.forEach { widgetId ->
            try {
                val options = appWidgetManager.getAppWidgetOptions(widgetId)
                val size = WidgetSize(
                    width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                        .takeIf { it > 0 } ?: FALLBACK_WIDTH_DP,
                    height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
                        .takeIf { it > 0 } ?: FALLBACK_HEIGHT_DP,
                )
                val views = bySize.getOrPut(size) {
                    buildViews(context, text, content, theme, size)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (error: Exception) {
                Log.e(TAG, "Could not update widget $widgetId", error)
            }
        }
    }

    private fun buildViews(
        context: Context,
        text: WidgetText,
        content: WidgetContent,
        theme: WidgetTheme,
        size: WidgetSize,
    ): RemoteViews {
        val res = context.resources
        val density = res.displayMetrics.density
        val compact = size.width < COMPACT_WIDTH_DP
        val layout = if (compact) R.layout.flixquest_widget_compact else R.layout.flixquest_widget
        val styles = if (compact) COMPACT_STYLES else WIDE_STYLES

        val margin = res.getDimensionPixelSize(R.dimen.widget_margin)
        val padding = res.getDimensionPixelSize(
            if (compact) R.dimen.widget_padding_compact else R.dimen.widget_padding,
        )
        val innerWidth = (size.width * density).roundToInt() - 2 * (margin + padding)
        val innerHeight = (size.height * density).roundToInt() - 2 * (margin + padding)

        return RemoteViews(context.packageName, layout).apply {
            // The rounded card behind everything, tinted to whatever theme the app is running.
            setInt(R.id.widget_surface, "setColorFilter", theme.surface)

            // The compact card has no poster column, so its poster can stand in for a missing
            // backdrop without the widget ever showing one image twice.
            val heroPath = content.heroPath ?: content.posterPath.takeIf { compact }
            val hero = heroPath?.let { decodeScaled(it, HERO_TARGET_PX, Bitmap.Config.RGB_565) }
            val onArt = hero != null
            val shades = if (compact) {
                intArrayOf(R.id.widget_scrim)
            } else {
                intArrayOf(R.id.widget_scrim, R.id.widget_scrim_side)
            }
            if (hero == null) {
                setViewVisibility(R.id.widget_hero, View.GONE)
                shades.forEach { setViewVisibility(it, View.GONE) }
            } else {
                setImageViewBitmap(R.id.widget_hero, hero)
                setViewVisibility(R.id.widget_hero, View.VISIBLE)
                shades.forEach { setViewVisibility(it, View.VISIBLE) }
            }

            var textWidth = innerWidth
            if (!compact) {
                val posterWidth = res.getDimensionPixelSize(R.dimen.widget_poster_width)
                val posterHeight = res.getDimensionPixelSize(R.dimen.widget_poster_height)
                // A poster taller than the card would be cropped to a sliver, so it steps aside
                // and the text takes the whole width.
                val poster = content.posterPath
                    ?.takeIf { posterHeight <= innerHeight }
                    ?.let { decodeScaled(it, POSTER_TARGET_PX, Bitmap.Config.ARGB_8888) }
                if (poster == null) {
                    setViewVisibility(R.id.widget_poster, View.GONE)
                } else {
                    setImageViewBitmap(R.id.widget_poster, poster)
                    setViewVisibility(R.id.widget_poster, View.VISIBLE)
                    setContentDescription(
                        R.id.widget_poster,
                        context.getString(R.string.widget_poster_description, content.title),
                    )
                    textWidth -= posterWidth + padding
                }
            }

            // Theme colours stop being legible over artwork, so there the text keeps the hero
            // card's own white ramp. The accent mark reads on both and never changes.
            setInt(R.id.widget_mark, "setColorFilter", theme.primary)
            val colors = if (onArt) {
                intArrayOf(ON_ART_TITLE, ON_ART_TITLE, ON_ART_SUBTITLE, ON_ART_META)
            } else {
                intArrayOf(
                    theme.muted,
                    theme.foreground,
                    withAlpha(theme.foreground, SUBTITLE_ALPHA),
                    theme.muted,
                )
            }
            val markWidth = res.getDimensionPixelSize(R.dimen.widget_mark_width) +
                res.getDimensionPixelSize(R.dimen.widget_mark_gap)
            val eyebrow = text.render(
                content.eyebrow, styles.eyebrow, textWidth - markWidth, Color.alpha(colors[0]),
            )
            var title = text.render(
                content.title, styles.title, textWidth, Color.alpha(colors[1]),
            )
            var subtitle = text.render(
                content.subtitle, styles.subtitle, textWidth, Color.alpha(colors[2]),
            )
            var meta = text.render(
                content.meta, styles.meta, textWidth, Color.alpha(colors[3]),
            )

            // A short card gives up its least important lines rather than clipping the kicker
            // off the top: the meta first, then the subtitle, then the title's second line.
            fun stackHeight(): Int {
                val kicker = maxOf(
                    eyebrow?.height ?: 0,
                    (res.getDimension(R.dimen.widget_mark_width) * 431f / 277f).roundToInt(),
                )
                val gap = (5 * density).roundToInt()
                return kicker +
                    listOfNotNull(title, subtitle, meta).sumOf { it.height + gap }
            }
            if (meta != null && stackHeight() > innerHeight) meta = null
            if (subtitle != null && stackHeight() > innerHeight) subtitle = null
            if (styles.title.maxLines > 1 && stackHeight() > innerHeight) {
                title = text.render(
                    content.title,
                    styles.title.copy(maxLines = 1),
                    textWidth,
                    Color.alpha(colors[1]),
                )
            }

            setTextBitmap(R.id.widget_eyebrow, content.eyebrow, eyebrow, colors[0])
            setTextBitmap(R.id.widget_title, content.title, title, colors[1])
            setTextBitmap(R.id.widget_subtitle, content.subtitle, subtitle, colors[2])
            setTextBitmap(R.id.widget_meta, content.meta, meta, colors[3])

            // A bar at zero is noise rather than information, so it only appears once there is
            // something to show. It is also the only place a percentage is expressed.
            val progress = content.progress?.takeIf { it > 0 }
            if (progress == null) {
                setViewVisibility(R.id.widget_progress, View.GONE)
            } else {
                setProgressBar(R.id.widget_progress, 100, progress.coerceAtMost(100), false)
                setViewVisibility(R.id.widget_progress, View.VISIBLE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    setColorStateList(
                        R.id.widget_progress,
                        "setProgressTintList",
                        ColorStateList.valueOf(theme.primary),
                    )
                }
            }

            setOnClickPendingIntent(
                R.id.widget_container,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(content.deepLink),
                ),
            )
        }
    }

    /**
     * Shows a line drawn by [WidgetText], or hides the slot when there is nothing to say there,
     * which is quieter than an empty line. The mask already carries [color]'s alpha, so the filter
     * only supplies the colour; the words go on as the description for screen readers.
     */
    private fun RemoteViews.setTextBitmap(viewId: Int, value: String, bitmap: Bitmap?, color: Int) {
        if (bitmap == null) {
            setViewVisibility(viewId, View.GONE)
        } else {
            setImageViewBitmap(viewId, bitmap)
            setInt(viewId, "setColorFilter", withAlpha(color, 0xFF))
            setContentDescription(viewId, value)
            setViewVisibility(viewId, View.VISIBLE)
        }
    }

    private fun withAlpha(color: Int, alpha: Int): Int = (color and 0x00FFFFFF) or (alpha shl 24)

    private fun decodeScaled(path: String, targetWidth: Int, config: Bitmap.Config): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = (bounds.outWidth / targetWidth).coerceAtLeast(1)
            inPreferredConfig = config
        }
        val decoded = BitmapFactory.decodeFile(path, options) ?: return null
        if (decoded.width <= targetWidth) return decoded
        val targetHeight = (decoded.height * (targetWidth.toFloat() / decoded.width))
            .roundToInt()
            .coerceAtLeast(1)
        return Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true).also {
            if (it !== decoded) decoded.recycle()
        }
    }
}

/** home_widget can land an int in preferences as a Long, so never call getInt bare. */
private fun SharedPreferences.safeInt(key: String, fallback: Int): Int =
    try {
        getInt(key, fallback)
    } catch (_: ClassCastException) {
        (all[key] as? Number)?.toInt() ?: fallback
    }

private fun SharedPreferences.nonBlank(key: String): String? =
    getString(key, null)?.takeIf { it.isNotBlank() && it != "null" }

private fun JSONObject.optNonBlank(key: String): String? =
    optString(key).takeIf { it.isNotBlank() && it != "null" }

/**
 * Movie / TV pick of the day. The app writes a week of picks ahead of time so the widget keeps
 * rotating on its own while the app is closed; the day's entry is chosen by epoch-day offset.
 */
abstract class DailyPickWidgetProvider : FlixQuestWidgetProvider() {
    abstract val scheduleKey: String
    abstract val eyebrow: String

    override fun content(widgetData: SharedPreferences): WidgetContent {
        val payload = widgetData.nonBlank(scheduleKey) ?: return syncPrompt(eyebrow)
        return try {
            val root = JSONObject(payload)
            val items = root.getJSONArray("items")
            val startDay = root.getLong("startDay")
            val today = LocalDate.now().toEpochDay()
            val index = Math.floorMod((today - startDay).toInt(), items.length())
            val item = items.getJSONObject(index)
            WidgetContent(
                eyebrow = eyebrow,
                title = item.optNonBlank("title") ?: return syncPrompt(eyebrow),
                subtitle = item.optString("subtitle"),
                meta = item.optString("meta"),
                posterPath = item.optNonBlank("poster"),
                heroPath = item.optNonBlank("hero"),
                deepLink = item.optNonBlank("deepLink") ?: HOME_DEEP_LINK,
            )
        } catch (error: Exception) {
            Log.e(TAG, "Malformed schedule in $scheduleKey", error)
            syncPrompt(eyebrow)
        }
    }
}

/**
 * Widgets whose every string is composed on the Dart side. This class deliberately holds no copy of
 * its own beyond the sync prompt, which is what stops the two sides from drifting apart.
 */
abstract class StoredWidgetProvider : FlixQuestWidgetProvider() {
    abstract val prefix: String
    abstract val fallbackEyebrow: String
    abstract val fallbackDeepLink: String

    /** Widgets that never express a ratio leave the bar out entirely. */
    open val showsProgress: Boolean = false

    override fun content(widgetData: SharedPreferences): WidgetContent {
        val title = widgetData.nonBlank("${prefix}_title")
            ?: return syncPrompt(fallbackEyebrow, fallbackDeepLink)
        return WidgetContent(
            eyebrow = widgetData.nonBlank("${prefix}_eyebrow") ?: fallbackEyebrow,
            title = title,
            subtitle = widgetData.getString("${prefix}_subtitle", null).orEmpty(),
            meta = widgetData.getString("${prefix}_meta", null).orEmpty(),
            posterPath = widgetData.nonBlank("${prefix}_poster"),
            heroPath = widgetData.nonBlank("${prefix}_hero"),
            deepLink = widgetData.nonBlank("${prefix}_deep_link") ?: fallbackDeepLink,
            progress = if (showsProgress) widgetData.safeInt("${prefix}_progress", 0) else null,
        )
    }
}

private fun syncPrompt(eyebrow: String, deepLink: String = HOME_DEEP_LINK) = WidgetContent(
    eyebrow = eyebrow,
    title = SYNC_TITLE,
    subtitle = SYNC_SUBTITLE,
    deepLink = deepLink,
)

class MovieOfDayWidgetProvider : DailyPickWidgetProvider() {
    override val scheduleKey = "movie_daily_schedule"
    override val eyebrow = "MOVIE OF THE DAY"
}

class TvShowOfDayWidgetProvider : DailyPickWidgetProvider() {
    override val scheduleKey = "tv_daily_schedule"
    override val eyebrow = "TV SHOW OF THE DAY"
}

class WellnessWidgetProvider : StoredWidgetProvider() {
    override val prefix = "wellness"
    override val fallbackEyebrow = "VIEWING INSIGHTS"
    override val fallbackDeepLink = "flixquest://wellness"
    override val showsProgress = true
}

class ContinueWatchingWidgetProvider : StoredWidgetProvider() {
    override val prefix = "continue"
    override val fallbackEyebrow = "CONTINUE WATCHING"
    override val fallbackDeepLink = HOME_DEEP_LINK
    override val showsProgress = true
}

class MyListWidgetProvider : StoredWidgetProvider() {
    override val prefix = "my_list"
    override val fallbackEyebrow = "MY LIST"
    override val fallbackDeepLink = "flixquest://my-list"
}
