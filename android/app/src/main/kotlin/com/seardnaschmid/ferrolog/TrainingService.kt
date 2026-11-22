package com.seardnaschmid.ferrolog

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock

/// Runs from the first logged set until the training ends. Shows the next set and the rest as a
/// system countdown (no updates per second), and at the end of the rest posts a separate alert with
/// sound and vibration while the app is away; in the foreground the Dart timer signals as before.
/// Keeping the process alive this way is what makes the alert on time with the screen off.
class TrainingService : Service() {
    companion object {
        @Volatile var running = false

        /// When the current rest ends (ms since epoch), 0 without one.
        @Volatile var restEnd = 0L

        fun update(c: Context, args: Bundle) {
            val i = Intent(c, TrainingService::class.java).putExtras(args)
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
        }

        fun stop(c: Context) {
            c.stopService(Intent(c, TrainingService::class.java))
            Notify.manager(c).cancel(Notify.REST_ID)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var args = Bundle()
    private val restOver = Runnable { restOver() }
    private val restWarning = Runnable { signal(true) }
    private var warnedEnd = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.extras?.let { args = it }
        running = true
        Notify.channel(this, Notify.TRAINING, args.getString("channelName"))
        Notify.channel(this, Notify.REST, args.getString("alertChannelName"))
        Notify.channel(this, Notify.REST_SILENT, args.getString("alertSilentChannelName"))
        Notify.manager(this).cancel(Notify.REST_ID) // a new set or rest: the old alert is stale
        val n = notification(rest = true)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(Notify.TRAINING_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(Notify.TRAINING_ID, n)
        }
        handler.removeCallbacks(restOver)
        handler.removeCallbacks(restWarning)
        val end = args.getLong("restEnd", 0)
        restEnd = end
        if (end > 0) {
            val left = end - System.currentTimeMillis()
            if (left > 10000 && args.getBoolean("warning", true) && warnedEnd != end) {
                handler.postAtTime(restWarning, SystemClock.uptimeMillis() + left - 10000)
            }
            if (left > 0) handler.postAtTime(restOver, SystemClock.uptimeMillis() + left) else restOver()
        }
        // Killed by the system: no restart, the app shows it again when it's opened.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(restOver)
        handler.removeCallbacks(restWarning)
        running = false
        restEnd = 0
        super.onDestroy()
    }

    /// The ongoing notification; [rest] false once the rest is over.
    private fun notification(rest: Boolean): Notification {
        val end = args.getLong("restEnd", 0)
        val counting = rest && end > System.currentTimeMillis()
        val paused = args.getString("pausedText")
        val text = args.getString("text") ?: ""
        val b = Notify.builder(this, Notify.TRAINING)
            .setContentTitle(args.getString("title"))
            .setContentText(
                when {
                    paused != null -> "$text · $paused"
                    !counting && end > 0 -> "$text · ${args.getString("overText")}"
                    else -> text
                }
            )
            .setSubText(args.getString("sub"))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (counting) {
            b.setWhen(end).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= 24) b.setChronometerCountDown(true)
        } else {
            b.setShowWhen(false)
        }
        // Android 16: a Live Update, on the lock screen and as a chip in the status bar.
        // (The extra behind NotificationCompat.setRequestPromotedOngoing; older versions ignore it.)
        b.addExtras(Bundle().apply { putBoolean("android.requestPromotedOngoing", true) })
        return b.build()
    }

    private fun signal(warning: Boolean) {
        if (!running) return
        if (warning) warnedEnd = restEnd
        RestSound.play(this, warning, args.getBoolean("sound", true), args.getBoolean("vibrate", true))
    }

    private fun restOver() {
        if (!running) return
        Notify.manager(this).notify(Notify.TRAINING_ID, notification(rest = false))
        signal(false)
        if (MainActivity.visible) return
        val sound = args.getBoolean("sound", true)
        val vibrate = args.getBoolean("vibrate", true)
        if (!sound && !vibrate) return
        // Without sound: a channel of its own that stays silent, the vibration comes from here, as in the app.
        val b = Notify.builder(this, Notify.REST_SILENT)
            .setContentTitle(args.getString("alertTitle"))
            .setContentText(args.getString("alertText"))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(5 * 60 * 1000L)
        Notify.manager(this).notify(Notify.REST_ID, b.build())
    }
}
