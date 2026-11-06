package dev.beamlak.flixquest_v2

import android.app.Activity
import android.content.Intent
import android.graphics.drawable.Animatable
import android.os.Bundle
import android.widget.ImageView

/**
 * Android TV doesn't show an app's splash icon, so TV launches open here first. The F builds while
 * MainActivity starts behind it, and this screen stays up until the app's first frame covers it.
 * The manifest marks it noHistory, so Android then removes it.
 */
class TvLaunchActivity : Activity() {
    private var mark: ImageView? = null
    private var started = false
    private val startApp = Runnable { startActivity(Intent(this, MainActivity::class.java)) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Reopening from the launcher lands here on top of the running app, so just reveal it.
        if (!isTaskRoot) {
            finish()
            return
        }
        mark = ImageView(this).apply {
            setImageResource(R.drawable.splash_fq_animated)
            scaleType = ImageView.ScaleType.CENTER
        }
        setContentView(mark)
    }

    // Focus means the window is on screen. Starting any earlier would spend the build unseen.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        val mark = mark
        if (!hasFocus || started || mark == null) return
        started = true
        (mark.drawable as? Animatable)?.start()
        mark.postDelayed(startApp, START_APP_DELAY_MS)
    }

    override fun onStop() {
        mark?.removeCallbacks(startApp)
        super.onStop()
    }

    private companion object {
        // Gives the animation a frame to get going before Flutter's startup occupies the main thread.
        const val START_APP_DELAY_MS = 300L
    }
}
