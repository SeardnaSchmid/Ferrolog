package com.seardnaschmid.ferrolog

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

/// Channels, the tap target and the scheduled reminders, shared by MainActivity, TrainingService
/// and ReminderReceiver. Texts come from Dart, in the app's language.
object Notify {
    const val TRAINING = "training" // silent, ongoing: the running training
    const val REST = "rest" // one shot with sound and vibration: the rest is over
    const val REST_SILENT = "rest_silent" // the same without sound, when the app's sound is off
    const val REMINDERS = "reminders"

    const val TRAINING_ID = 1
    const val REST_ID = 2

    private const val PREFS = "ferrolog_notify"

    fun manager(c: Context) = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    /// Creates or renames the channel. Importance and sound only count at creation, Android keeps
    /// the user's choice after that.
    fun channel(c: Context, id: String, name: String?) {
        if (Build.VERSION.SDK_INT < 26) return
        val importance = when (id) {
            REST, REST_SILENT -> NotificationManager.IMPORTANCE_HIGH
            TRAINING -> NotificationManager.IMPORTANCE_LOW
            else -> NotificationManager.IMPORTANCE_DEFAULT
        }
        val ch = NotificationChannel(id, name ?: manager(c).getNotificationChannel(id)?.name ?: id, importance)
        if (id == REST) ch.enableVibration(true)
        if (id == REST_SILENT) {
            ch.setSound(null, null)
            ch.enableVibration(false)
        }
        if (id == TRAINING) ch.setShowBadge(false)
        manager(c).createNotificationChannel(ch)
    }

    fun builder(c: Context, channel: String): Notification.Builder =
        (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channel) else @Suppress("DEPRECATION") Notification.Builder(c))
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(open(c))

    /// Opens the app where it was.
    fun open(c: Context): PendingIntent {
        val i = c.packageManager.getLaunchIntentForPackage(c.packageName)!!
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntent.getActivity(c, 0, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    fun allowed(c: Context) = manager(c).areNotificationsEnabled()

    // -------------------------------------------------------------------------------------------
    // Reminders: kept in prefs, so a restart (BOOT_COMPLETED) can schedule them again.

    fun saveReminders(c: Context, json: String) {
        val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        cancelReminders(c, p.getString("reminders", "[]")!!)
        p.edit().putString("reminders", json).apply()
        scheduleReminders(c)
    }

    fun scheduleReminders(c: Context) {
        val list = JSONArray(c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("reminders", "[]"))
        val alarms = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        for (i in 0 until list.length()) {
            val r = list.getJSONObject(i)
            val at = r.getLong("at")
            if (at <= now) continue
            // Inexact is fine for a reminder and needs no exact-alarm permission.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, reminder(c, r.getInt("id"), r.getString("title"), r.getString("text")))
        }
    }

    private fun cancelReminders(c: Context, json: String) {
        val list = JSONArray(json)
        val alarms = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0 until list.length()) {
            alarms.cancel(reminder(c, list.getJSONObject(i).getInt("id"), "", ""))
        }
    }

    private fun reminder(c: Context, id: Int, title: String, text: String): PendingIntent {
        val i = Intent(c, ReminderReceiver::class.java)
            .setAction("com.seardnaschmid.ferrolog.REMINDER.$id")
            .putExtra("id", id)
            .putExtra("title", title)
            .putExtra("text", text)
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }
}
