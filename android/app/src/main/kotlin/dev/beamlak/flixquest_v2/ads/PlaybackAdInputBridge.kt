package dev.beamlak.flixquest_v2.ads

import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.webkit.WebView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONTokener
import java.util.WeakHashMap

class PlaybackAdInputBridge(
    messenger: BinaryMessenger,
    findWebView: (Long) -> WebView?,
) {
    private val touch = ContinueButtonTouch { Log.d("PlaybackAdInput", it) }
    private val channel = MethodChannel(messenger, "dev.beamlak.flixquest/playback_ad_input")

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "tapContinue") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val id = call.argument<Number>("webViewId")?.toLong()
            val document = call.argument<String>("document")
            val webView = id?.let(findWebView)
            if (webView == null || document == null) {
                Log.d("PlaybackAdInput", "Continue touch unavailable: native WebView or document missing")
                result.success(false)
            } else {
                touch.tap(webView, document) { result.success(it) }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        touch.dispose()
    }
}

/** Native input is restricted to fq-continue in the original tag document. */
internal class ContinueButtonTouch(private val log: (String) -> Unit = {}) {
    private val handler = Handler(Looper.getMainLooper())
    private val touched = WeakHashMap<WebView, String>()
    private var disposed = false

    fun tap(webView: WebView, document: String, complete: (Boolean) -> Unit) {
        fun reject(reason: String) {
            log("Continue touch rejected: $reason")
            complete(false)
        }
        val initialUrl = webView.url ?: run { reject("no_native_url"); return }
        val initialOriginalUrl = webView.originalUrl
        // loadDataWithBaseURL uses a null history URL in webview_flutter.
        // On a real Android WebView getUrl() is then about:blank, although
        // location.href is the HTTPS base. Only our inline tag document may
        // use this case; its DOM URL is verified below before sending input.
        val inlineDocument = initialUrl == "about:blank" &&
            initialOriginalUrl?.startsWith("data:text/html") == true &&
            matchesDocument(document, INLINE_DOCUMENT)
        if (!available(webView)) {
            reject("webview_not_available")
            return
        }
        if (!matchesDocument(initialUrl, document) && !inlineDocument) {
            reject("native_document_mismatch")
            return
        }
        if (touched[webView] == initialUrl) {
            reject("already_attempted")
            return
        }
        webView.evaluateJavascript(BUTTON_LOCATION) { value ->
            val point = try {
                val json = JSONTokener(value).nextValue() as? String
                json?.let(::JSONObject)
            } catch (_: Exception) { null }
            if (point == null || !available(webView) || webView.url != initialUrl ||
                webView.originalUrl != initialOriginalUrl ||
                !matchesDocument(point.optString("url"), document) ||
                touched[webView] == initialUrl
            ) {
                reject("button_missing_or_document_changed")
                return@evaluateJavascript
            }
            val xRatio = point.optDouble("x", Double.NaN)
            val yRatio = point.optDouble("y", Double.NaN)
            if (!xRatio.isFinite() || !yRatio.isFinite() ||
                xRatio <= 0 || xRatio >= 1 || yRatio <= 0 || yRatio >= 1
            ) {
                reject("button_outside_viewport")
                return@evaluateJavascript
            }
            touched[webView] = initialUrl
            val x = (xRatio * webView.width).toFloat()
            val y = (yRatio * webView.height).toFloat()
            val downTime = SystemClock.uptimeMillis()
            val accepted = dispatch(webView, downTime, MotionEvent.ACTION_DOWN, x, y)
            handler.postDelayed({
                // Closing the ad disables JS; a navigation may also replace
                // the document during DOWN. Neither may receive an UP tap.
                if (!available(webView) || webView.url != initialUrl ||
                    webView.originalUrl != initialOriginalUrl
                ) {
                    if (webView.isAttachedToWindow) {
                        dispatch(webView, downTime, MotionEvent.ACTION_CANCEL, x, y)
                    }
                    reject("document_changed_before_release")
                } else {
                    val released = dispatch(webView, downTime, MotionEvent.ACTION_UP, x, y)
                    log("Continue touch sent: accepted=${accepted && released} inline=$inlineDocument")
                    complete(accepted && released)
                }
            }, 80)
        }
    }

    fun dispose() { disposed = true }

    private fun available(webView: WebView) = !disposed && webView.isAttachedToWindow &&
        webView.visibility == View.VISIBLE && webView.width > 0 && webView.height > 0 &&
        webView.settings.javaScriptEnabled

    private fun dispatch(webView: WebView, downTime: Long, action: Int, x: Float, y: Float): Boolean {
        val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x, y, 0)
        event.source = InputDevice.SOURCE_TOUCHSCREEN
        return try { webView.dispatchTouchEvent(event) } finally { event.recycle() }
    }

    private fun matchesDocument(actual: String?, expected: String): Boolean {
        if (actual == null) return false
        val a = Uri.parse(actual)
        val e = Uri.parse(expected)
        return a.scheme == "https" && a.scheme == e.scheme && a.host == e.host &&
            a.port == e.port && a.path?.trimEnd('/') == e.path?.trimEnd('/')
    }

    private companion object {
        const val INLINE_DOCUMENT = "https://appassets.androidplatform.net/adsterra/"
        const val BUTTON_LOCATION = """
            (function(){
              var b=document.getElementById('fq-continue');
              if(!b||b.disabled||!document.getElementById('fq-controls'))return null;
              var r=b.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2;
              if(r.width<=0||r.height<=0||!b.contains(document.elementFromPoint(x,y)))return null;
              return JSON.stringify({url:location.href,x:x/innerWidth,y:y/innerHeight});
            })();
        """
    }
}
