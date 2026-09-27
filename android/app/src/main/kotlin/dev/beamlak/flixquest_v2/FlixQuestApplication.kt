package dev.beamlak.flixquest_v2

import android.app.Application
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import com.startapp.sdk.adsbase.StartAppSDK
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import io.flutter.embedding.engine.loader.FlutterLoader
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class FlixQuestApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Start.io shows its own consent/disclosure popup on first launch by
        // default. Record the personalized-ads consent signal and turn that
        // popup off, so the first open goes straight to the app.
        StartAppSDK.setUserConsent(this, "pas", System.currentTimeMillis(), true)
        StartAppSDK.enableConsent(this, false)
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val uiModeManager = base.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        val isTelevision =
            uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
                base.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        if (!needsShieldRendererWorkaround(Build.MANUFACTURER, Build.MODEL, isTelevision)) return

        // Install before content providers, background services or the activity can access
        // Flutter. Do not initialize the engine here: applicationContext is not ready yet.
        val executor = Executors.newCachedThreadPool()
        FlutterInjector.setInstance(
            FlutterInjector.Builder()
                .setExecutorService(executor)
                .setFlutterLoader(ShieldFlutterLoader(FlutterJNI(), executor))
                .build(),
        )
    }
}

internal fun needsShieldRendererWorkaround(
    manufacturer: String,
    model: String,
    isTelevision: Boolean,
): Boolean = isTelevision &&
    manufacturer.trim().equals("NVIDIA", ignoreCase = true) &&
    model.contains("SHIELD", ignoreCase = true)

/** Work around https://github.com/flutter/flutter/issues/159503 on Shield TVs only. */
internal class ShieldFlutterLoader(
    flutterJNI: FlutterJNI,
    executor: ExecutorService,
) : FlutterLoader(flutterJNI, executor) {
    override fun ensureInitializationComplete(applicationContext: Context, args: Array<String>?) {
        // Flutter's async initialization also calls this method. This covers background
        // messaging/widgets starting Flutter before MainActivity, as well as normal launch.
        // Remove competing flags so debug launch arguments cannot undo the workaround.
        val shieldArgs = args.orEmpty().filterNot {
            it == "--enable-impeller" || it.startsWith("--enable-impeller=")
        } + "--enable-impeller=false"
        super.ensureInitializationComplete(applicationContext, shieldArgs.toTypedArray())
    }
}
