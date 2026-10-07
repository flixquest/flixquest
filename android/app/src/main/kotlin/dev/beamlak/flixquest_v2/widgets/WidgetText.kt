package dev.beamlak.flixquest_v2.widgets

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import androidx.annotation.FontRes
import androidx.core.content.res.ResourcesCompat
import dev.beamlak.flixquest_v2.R
import kotlin.math.ceil
import kotlin.math.floor

/**
 * One line style of the widget, mirroring the app's AppType scale.
 *
 * [font] is one of the two Figtree weights the app uses: Medium is its `Figtree`, ExtraBold its
 * `FigtreeBold`.
 */
data class WidgetTextStyle(
    @FontRes val font: Int,
    val sizeSp: Float,
    val maxLines: Int = 1,
    /** In ems, as Paint takes it. */
    val tracking: Float = 0f,
    val lineSpacing: Float = 1f,
)

/**
 * Draws widget text in Figtree.
 *
 * A launcher inflates a widget's layout with a restricted context, and TextView refuses to load
 * font resources in one, so `android:fontFamily="@font/…"` quietly renders in the system font. The
 * text is laid out here instead, in the app's own process where the font loads, and handed over
 * as a bitmap.
 *
 * The bitmap is an ALPHA_8 coverage mask, a quarter of the size of a colour one, which matters
 * because every bitmap in a RemoteViews shares one Binder transaction with the artwork. The colour
 * goes on in the launcher with ImageView's colour filter (SRC_ATOP), and a translucent colour's
 * alpha is drawn into the mask itself, since SRC_ATOP keeps the mask's alpha and ignores the
 * filter's.
 */
class WidgetText(private val context: Context) {
    private val metrics = context.resources.displayMetrics
    private val typefaces = HashMap<Int, Typeface>(2)

    /**
     * [text] wrapped to [maxWidthPx] and cut to the style's line count, as a bitmap no larger than
     * the ink it holds. Null when there is nothing to draw.
     */
    fun render(text: String, style: WidgetTextStyle, maxWidthPx: Int, alpha: Int = 0xFF): Bitmap? {
        if (text.isBlank() || maxWidthPx <= 0) return null
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
            typeface = typeface(style.font)
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, style.sizeSp, metrics)
            letterSpacing = style.tracking
            color = Color.argb(alpha, 0, 0, 0)
        }
        val layout = StaticLayout.Builder
            .obtain(text, 0, text.length, paint, maxWidthPx)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setMaxLines(style.maxLines)
            .setLineSpacing(0f, style.lineSpacing)
            .setIncludePad(false)
            .build()

        // Trim to the widest line so the view only takes the room the words do, which also keeps
        // the start edge right for right-to-left text.
        var left = Float.MAX_VALUE
        var right = 0f
        for (line in 0 until layout.lineCount) {
            left = minOf(left, layout.getLineLeft(line))
            right = maxOf(right, layout.getLineRight(line))
        }
        val start = floor(left).coerceAtLeast(0f)
        val width = (ceil(right) - start).toInt().coerceIn(1, maxWidthPx)
        val height = layout.getLineBottom(layout.lineCount - 1).coerceAtLeast(1)

        return Bitmap.createBitmap(metrics, width, height, Bitmap.Config.ALPHA_8).also {
            val canvas = Canvas(it)
            canvas.translate(-start, 0f)
            layout.draw(canvas)
        }
    }

    private fun typeface(@FontRes font: Int): Typeface =
        typefaces.getOrPut(font) {
            try {
                ResourcesCompat.getFont(context, font)
            } catch (error: Exception) {
                Log.e("FlixQuestWidget", "Could not load widget font", error)
                null
            } ?: if (font == R.font.figtree_extrabold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }
}
