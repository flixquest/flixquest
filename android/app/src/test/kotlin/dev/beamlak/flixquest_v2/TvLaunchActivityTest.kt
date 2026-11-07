package dev.beamlak.flixquest_v2

import android.app.Application
import android.content.Intent
import android.os.Looper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
@LooperMode(LooperMode.Mode.PAUSED)
class TvLaunchActivityTest {
    @Test fun startsTheAppOnlyOnceItsWindowIsOnScreen() {
        val activity = Robolectric.buildActivity(TvLaunchActivity::class.java).setup().get()
        shadowOf(Looper.getMainLooper()).idle()
        assertNull(shadowOf(activity).nextStartedActivity)

        activity.onWindowFocusChanged(true)
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(1))

        assertEquals(
            MainActivity::class.java.name,
            shadowOf(activity).nextStartedActivity?.component?.className,
        )
        assertFalse(activity.isFinishing)
    }

    @Test fun regainingFocusDoesNotStartTheAppAgain() {
        val activity = Robolectric.buildActivity(TvLaunchActivity::class.java).setup().get()
        activity.onWindowFocusChanged(true)
        activity.onWindowFocusChanged(false)
        activity.onWindowFocusChanged(true)
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(1))

        assertNotNull(shadowOf(activity).nextStartedActivity)
        assertNull(shadowOf(activity).nextStartedActivity)
    }

    @Test fun leavingBeforeTheHandoverDoesNotPullTheAppBackUp() {
        val controller = Robolectric.buildActivity(TvLaunchActivity::class.java).setup()
        val activity = controller.get()
        activity.onWindowFocusChanged(true)
        controller.pause().stop()
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(1))

        assertNull(shadowOf(activity).nextStartedActivity)
    }

    @Test fun reopeningOverTheRunningAppJustRevealsIt() {
        val controller = Robolectric.buildActivity(TvLaunchActivity::class.java)
        shadowOf(controller.get()).setIsTaskRoot(false)
        controller.create()
        val activity = controller.get()

        activity.onWindowFocusChanged(true)
        shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofSeconds(1))

        assertTrue(activity.isFinishing)
        assertNull(shadowOf(activity).nextStartedActivity)
    }

    @Test fun onlyTheTvLauncherOpensTheLaunchScreen() {
        val packageManager = RuntimeEnvironment.getApplication().packageManager
        fun launcherActivity(category: String) = packageManager
            .queryIntentActivities(
                Intent(Intent.ACTION_MAIN)
                    .addCategory(category)
                    .setPackage(RuntimeEnvironment.getApplication().packageName),
                0,
            )
            .map { it.activityInfo.name }

        assertEquals(
            listOf(TvLaunchActivity::class.java.name),
            launcherActivity(Intent.CATEGORY_LEANBACK_LAUNCHER),
        )
        assertEquals(
            listOf(MainActivity::class.java.name),
            launcherActivity(Intent.CATEGORY_LAUNCHER),
        )
    }
}
