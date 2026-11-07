package dev.beamlak.flixquest_v2
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import dev.beamlak.flixquest_v2.links.MediaLinkBridge
class MainActivity : FlutterActivity() {
    private var linkBridge: MediaLinkBridge? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "dev.beamlak.flixquest/device_presentation")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTelevision") {
                    val mode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                    result.success(mode?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK))
                } else result.notImplemented()
            }
        linkBridge = MediaLinkBridge(engine.dartExecutor.binaryMessenger).also { it.onIntent(intent) }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkBridge?.onIntent(intent)
    }
    override fun cleanUpFlutterEngine(engine: FlutterEngine) {
        linkBridge?.dispose()
        linkBridge = null
        super.cleanUpFlutterEngine(engine)
    }
}
