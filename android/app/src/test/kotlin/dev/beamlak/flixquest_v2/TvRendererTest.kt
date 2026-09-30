package dev.beamlak.flixquest_v2

import android.app.Application
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterJNI
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import org.robolectric.shadows.ShadowBuild
import org.robolectric.shadows.ShadowLog
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter
import java.util.concurrent.Executors

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], manifest = Config.NONE, application = Application::class)
@LooperMode(LooperMode.Mode.PAUSED)
class TvRendererTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private val executor = Executors.newCachedThreadPool()

    @After fun tearDown() {
        executor.shutdownNow()
        FlutterInjector.reset()
    }

    @Test fun xiaomiAndroid11InstallsLoaderDuringAttachmentWithoutStartingFlutter() {
        ShadowBuild.setManufacturer("Xiaomi")
        ShadowBuild.setModel("Mi TV")
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_TELEVISION)

        attachApplication()
        val injector = FlutterInjector.instance()
        try {
            assertTrue(injector.flutterLoader() is TvCompatibilityFlutterLoader)
            assertFalse(injector.flutterLoader().initialized())
        } finally {
            injector.executorService().shutdownNow()
        }
    }

    @Test @Config(sdk = [34])
    fun philipsInstallsCompatibilityLoaderBeforeForegroundOrBackgroundStartup() {
        ShadowBuild.setManufacturer("TP Vision")
        ShadowBuild.setBrand("Philips")
        ShadowBuild.setModel("Philips TV")
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_TELEVISION)

        attachApplication()
        val injector = FlutterInjector.instance()
        try {
            assertTrue(injector.flutterLoader() is TvCompatibilityFlutterLoader)
            assertFalse(injector.flutterLoader().initialized())
            assertTrue(ShadowLog.getLogsForTag("FlixQuestRenderer").any {
                it.msg.contains("policy=skia") && it.msg.contains("brand=Philips")
            })
        } finally {
            injector.executorService().shutdownNow()
        }
    }

    @Test fun phonesKeepExistingInjectorAndRendererDefaults() {
        ShadowBuild.setManufacturer("Google")
        ShadowBuild.setModel("Pixel")
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_NORMAL)
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_LEANBACK, false)
        val original = FlutterInjector.Builder().setExecutorService(executor).build()
        FlutterInjector.setInstance(original)

        attachApplication()

        assertSame(original, FlutterInjector.instance())
        assertFalse(original.flutterLoader() is TvCompatibilityFlutterLoader)
    }

    @Test fun leanbackFeatureSelectsSkiaEvenWhenUiModeIsNotTelevision() {
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_NORMAL)
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_LEANBACK, true)

        attachApplication()
        val injector = FlutterInjector.instance()
        try {
            assertTrue(injector.flutterLoader() is TvCompatibilityFlutterLoader)
            assertFalse(injector.flutterLoader().initialized())
        } finally {
            injector.executorService().shutdownNow()
        }
    }

    @Test fun unknownTvBrandsSelectSkiaWithoutAnAllowlist() {
        ShadowBuild.setManufacturer("unknown")
        ShadowBuild.setBrand("unknown")
        ShadowBuild.setModel("unknown")
        shadowOf(context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
            .setCurrentModeType(Configuration.UI_MODE_TYPE_TELEVISION)
        shadowOf(context.packageManager).setSystemFeature(PackageManager.FEATURE_LEANBACK, false)

        attachApplication()
        val injector = FlutterInjector.instance()
        try {
            assertTrue(injector.flutterLoader() is TvCompatibilityFlutterLoader)
            assertFalse(injector.flutterLoader().initialized())
        } finally {
            injector.executorService().shutdownNow()
        }
    }

    @Test fun foregroundInitializationSelectsSkiaAndPreservesOtherArguments() {
        val jni = RecordingFlutterJNI()
        val loader = TvCompatibilityFlutterLoader(jni, executor)
        loader.startInitialization(context)
        loader.ensureInitializationComplete(
            context, arrayOf("--trace-startup", "--enable-impeller=true", "--enable-impeller"),
        )

        assertEquals(listOf("--enable-impeller=false"), jni.args.filter { it.startsWith("--enable-impeller") })
        assertTrue(jni.args.contains("--trace-startup"))
        loader.ensureInitializationComplete(context, null)
        assertEquals(1, jni.initCount)
    }

    @Test fun backgroundAsyncInitializationAlsoSelectsSkiaWithNoActivityArguments() {
        val jni = RecordingFlutterJNI()
        val loader = TvCompatibilityFlutterLoader(jni, executor)
        loader.startInitialization(context)
        var callbackCalled = false
        loader.ensureInitializationCompleteAsync(context, null, Handler(Looper.getMainLooper())) {
            callbackCalled = true
        }

        val deadline = System.nanoTime() + 5_000_000_000L
        while (!callbackCalled && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(10)
        }
        assertTrue("Background initialization callback", callbackCalled)
        assertEquals(listOf("--enable-impeller=false"), jni.args.filter { it.startsWith("--enable-impeller") })
        assertEquals(1, jni.initCount)
    }

    private fun attachApplication() {
        // Android calls Application.attach before providers or Application.onCreate.
        ReflectionHelpers.callInstanceMethod<Void>(
            FlixQuestApplication(), "attach", ClassParameter.from(Context::class.java, context),
        )
    }

    // Exercise the real FlutterLoader up to its JNI boundary, without loading libflutter.so.
    private class RecordingFlutterJNI : FlutterJNI() {
        var args = emptyList<String>()
        var initCount = 0
        override fun loadLibrary(context: Context) {}
        override fun updateRefreshRate() {}
        override fun prefetchDefaultFontManager() {}
        override fun init(
            context: Context, args: Array<String>, bundlePath: String?,
            appStoragePath: String, engineCachesPath: String, initTimeMillis: Long, apiLevel: Int,
        ) {
            this.args = args.toList()
            initCount++
        }
    }
}
