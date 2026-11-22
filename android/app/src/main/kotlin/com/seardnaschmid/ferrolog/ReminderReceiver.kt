package com.seardnaschmid.ferrolog

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// A reminder is due (streak in danger, long break), or the phone restarted and the reminders need
/// scheduling again. Texts were written by Dart when the list was handed over.
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Notify.scheduleReminders(c)
            return
        }
        if (!Notify.allowed(c)) return
        val n = Notify.builder(c, Notify.REMINDERS)
            .setContentTitle(intent.getStringExtra("title"))
            .setContentText(intent.getStringExtra("text"))
            .setAutoCancel(true)
            .build()
        Notify.manager(c).notify(100 + intent.getIntExtra("id", 0), n)
    }
}
