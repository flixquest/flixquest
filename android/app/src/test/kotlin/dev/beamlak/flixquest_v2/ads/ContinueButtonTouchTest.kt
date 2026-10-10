package dev.beamlak.flixquest_v2.ads

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Looper
import android.view.InputDevice
import android.view.MotionEvent
import android.webkit.ValueCallback
import android.webkit.WebView
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.time.Duration

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
@LooperMode(LooperMode.Mode.PAUSED)
class ContinueButtonTouchTest {
    private val document = "https://flix.quest/a/3ad05c8e4d"

    @Test fun sendsOneTouchToTheContinueButton() {
        val web = attachedWebView()
        val touch = ContinueButtonTouch()
        var result: Boolean? = null
        touch.tap(web, document) { result = it }
        assertEquals(1, web.lookupCount)
        assertEquals(listOf(MotionEvent.ACTION_DOWN), web.actions)
        assertNull(result)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(80))
        assertEquals(listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP), web.actions)
        assertEquals(listOf(InputDevice.SOURCE_TOUCHSCREEN, InputDevice.SOURCE_TOUCHSCREEN), web.sources)
        assertTrue(result == true)
        touch.tap(web, document) { result = it }
        assertFalse(result == true)
        assertEquals(2, web.actions.size)
    }

    @Test fun closingTheAdCancelsThePendingRelease() {
        val web = attachedWebView()
        val touch = ContinueButtonTouch()
        var result: Boolean? = null
        touch.tap(web, document) { result = it }
        web.settings.javaScriptEnabled = false
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(80))
        assertEquals(listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_CANCEL), web.actions)
        assertFalse(result == true)
    }

    @Test fun navigationCannotReceiveAContinueTouch() {
        val web = attachedWebView()
        web.currentUrl = "https://advertiser.example/offer"
        var result = true
        ContinueButtonTouch().tap(web, document) { result = it }
        assertFalse(result)
        assertTrue(web.actions.isEmpty())
    }

    @Test fun inlineTagWithBlankNativeUrlReceivesOneTouch() {
        val web = attachedWebView()
        val inline = "https://appassets.androidplatform.net/adsterra/"
        web.currentUrl = "about:blank"
        web.currentOriginalUrl = "data:text/html;charset=utf-8;base64,"
        web.buttonLocation = JSONObject.quote("""{"url":"$inline","x":0.5,"y":0.5}""")
        val touch = ContinueButtonTouch()
        var result: Boolean? = null
        touch.tap(web, inline) { result = it }
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(80))
        assertTrue(result == true)
        assertEquals(listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP), web.actions)
        touch.tap(web, inline) { result = it }
        assertFalse(result == true)
        assertEquals(2, web.actions.size)
    }

    @Test fun blankNativeUrlDoesNotAcceptAnAdvertiserOrUnverifiedDocument() {
        val web = attachedWebView()
        val inline = "https://appassets.androidplatform.net/adsterra/"
        web.currentUrl = "about:blank"
        web.currentOriginalUrl = "data:text/html;charset=utf-8;base64,"
        var result = true
        ContinueButtonTouch().tap(web, document) { result = it }
        assertFalse(result)
        assertEquals(0, web.lookupCount)
        web.buttonLocation = JSONObject.quote("""{"url":"https://advertiser.example/offer","x":0.5,"y":0.5}""")
        ContinueButtonTouch().tap(web, inline) { result = it }
        assertFalse(result)
        assertTrue(web.actions.isEmpty())
        web.currentOriginalUrl = "about:blank"
        web.buttonLocation = JSONObject.quote("""{"url":"$inline","x":0.5,"y":0.5}""")
        ContinueButtonTouch().tap(web, inline) { result = it }
        assertFalse(result)
        assertTrue(web.actions.isEmpty())
    }

    @Test fun replacingInlineDocumentWithBlankPageCancelsTheRelease() {
        val web = attachedWebView()
        val inline = "https://appassets.androidplatform.net/adsterra/"
        web.currentUrl = "about:blank"
        web.currentOriginalUrl = "data:text/html;charset=utf-8;base64,"
        web.buttonLocation = JSONObject.quote("""{"url":"$inline","x":0.5,"y":0.5}""")
        var result = true
        ContinueButtonTouch().tap(web, inline) { result = it }
        // getUrl stays about:blank, but this is now a different document.
        web.currentOriginalUrl = "about:blank"
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(80))
        assertFalse(result)
        assertEquals(listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_CANCEL), web.actions)
    }

    @Test fun replacingInlineDocumentDuringLookupReceivesNoTouch() {
        val web = attachedWebView()
        val inline = "https://appassets.androidplatform.net/adsterra/"
        web.currentUrl = "about:blank"
        web.currentOriginalUrl = "data:text/html;charset=utf-8;base64,"
        web.buttonLocation = JSONObject.quote("""{"url":"$inline","x":0.5,"y":0.5}""")
        web.beforeLookup = { web.currentOriginalUrl = "about:blank" }
        var result = true
        ContinueButtonTouch().tap(web, inline) { result = it }
        assertFalse(result)
        assertTrue(web.actions.isEmpty())
    }

    @Test fun changedDocumentDuringButtonLookupReceivesNoTouch() {
        val web = attachedWebView()
        web.beforeLookup = { web.currentUrl = "https://flix.quest/other" }
        var result = true
        ContinueButtonTouch().tap(web, document) { result = it }
        assertFalse(result)
        assertTrue(web.actions.isEmpty())
    }

    @Test fun missingButtonAndDetachedWebViewReceiveNoTouch() {
        val web = attachedWebView()
        web.buttonLocation = "null"
        var result = true
        ContinueButtonTouch().tap(web, document) { result = it }
        assertFalse(result)
        assertTrue(web.actions.isEmpty())
        val detached = RecordingWebView(web.context)
        detached.currentUrl = document
        detached.settings.javaScriptEnabled = true
        detached.layout(0, 0, 400, 600)
        ContinueButtonTouch().tap(detached, document) { result = it }
        assertFalse(result)
        assertTrue(detached.actions.isEmpty())
    }

    private fun attachedWebView(): RecordingWebView {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().visible().get()
        val web = RecordingWebView(activity)
        activity.setContentView(web)
        shadowOf(Looper.getMainLooper()).idle()
        web.currentUrl = document
        web.settings.javaScriptEnabled = true
        web.buttonLocation = JSONObject.quote("""{"url":"$document","x":0.5,"y":0.5}""")
        // Robolectric's WebView provider leaves its layout frame empty.
        // Give this recording view a viewport for the native input test.
        web.right = 400
        web.bottom = 600
        assertTrue("Test WebView must be attached", web.isAttachedToWindow)
        assertTrue("Test WebView must have JavaScript enabled", web.settings.javaScriptEnabled)
        assertEquals(400, web.width)
        assertEquals(600, web.height)
        return web
    }

    private class RecordingWebView(context: Context) : WebView(context) {
        var currentUrl: String? = null
        var currentOriginalUrl: String? = null
        var buttonLocation = "null"
        var beforeLookup: (() -> Unit)? = null
        var lookupCount = 0
        val actions = mutableListOf<Int>()
        val sources = mutableListOf<Int>()
        override fun getUrl(): String? = currentUrl
        override fun getOriginalUrl(): String? = currentOriginalUrl
        override fun evaluateJavascript(script: String, callback: ValueCallback<String>?) {
            lookupCount++
            beforeLookup?.invoke()
            callback?.onReceiveValue(buttonLocation)
        }
        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            actions.add(event.action)
            sources.add(event.source)
            return true
        }
    }
}
