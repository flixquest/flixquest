package dev.beamlak.flixquest_v2

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import android.webkit.WebView
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.beamlak.flixquest_v2.downloads.StreamDownloadsBridge
import dev.beamlak.flixquest_v2.downloads.StreamOfflinePlayerFactory
import dev.beamlak.flixquest_v2.links.MediaLinkBridge
import dev.beamlak.flixquest_v2.ads.PlaybackAdInputBridge
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin

class MainActivity: FlutterActivity() {
    private var downloadsBridge: StreamDownloadsBridge? = null
    private var linkBridge: MediaLinkBridge? = null
    private var playbackAdInputBridge: PlaybackAdInputBridge? = null

    // Starting an activity of our own (a file picker, an external player, a full-screen ad) also
    // reports the user as leaving, which would send a playing video into picture in picture.
    private var launchingOwnActivity = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        playbackAdInputBridge = PlaybackAdInputBridge(
            flutterEngine.dartExecutor.binaryMessenger,
        ) { identifier ->
            val plugin = flutterEngine.plugins.get(WebViewFlutterPlugin::class.java)
                as? WebViewFlutterPlugin
            plugin?.instanceManager?.getInstance<WebView>(identifier)
        }

        val bridge = StreamDownloadsBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        downloadsBridge = bridge
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "dev.beamlak.flixquest/offline_player",
                StreamOfflinePlayerFactory(bridge.store),
            )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_PRESENTATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTelevision" -> result.success(isTelevision())
                // Full-screen ads run in their own activity, above anything
                // Flutter can draw; a toast still shows on top of them.
                "showHint" -> {
                    val text = call.arguments as? String
                    if (text.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        Toast.makeText(applicationContext, text, Toast.LENGTH_LONG).show()
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // The intent the activity started on is where a tapped or shared address arrives, and it is
        // already in hand by the time the engine is configured — well before Dart can ask for it.
        linkBridge = MediaLinkBridge(flutterEngine.dartExecutor.binaryMessenger).also {
            it.onIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkBridge?.onIntent(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        playbackAdInputBridge?.dispose()
        playbackAdInputBridge = null
        linkBridge?.dispose()
        linkBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        launchingOwnActivity = true
        try {
            super.startActivityForResult(intent, requestCode, options)
        } catch (e: RuntimeException) {
            launchingOwnActivity = false
            throw e
        }
    }

    // Only a real departure, such as the home button, reaches the plugins listening for it.
    override fun onUserLeaveHint() {
        if (launchingOwnActivity) {
            launchingOwnActivity = false
            return
        }
        super.onUserLeaveHint()
    }

    override fun onResume() {
        super.onResume()
        launchingOwnActivity = false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (downloadsBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun isTelevision(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            (uiModeManager == null &&
                packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
    }

    private companion object {
        const val DEVICE_PRESENTATION_CHANNEL =
            "dev.beamlak.flixquest/device_presentation"
    }
}
