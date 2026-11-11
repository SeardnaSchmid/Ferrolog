package com.seardnaschmid.ferrolog

import android.content.Context
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ferrolog/alert").setMethodCallHandler { call, result ->
            if (call.method == "keepScreenOn") {
                // While training: the display stays on, the rest timer stays in view.
                if (call.argument<Boolean>("on") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            if (call.method == "showWhenLocked") {
                // While training: power twice shows the session without unlocking. No setTurnScreenOn,
                // the screen stays off until the user wakes it.
                val on = call.argument<Boolean>("on") == true
                if (Build.VERSION.SDK_INT >= 27) {
                    setShowWhenLocked(on)
                } else if (on) {
                    @Suppress("DEPRECATION")
                    window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
                } else {
                    @Suppress("DEPRECATION")
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
                }
                result.success(null)
                return@setMethodCallHandler
            }
            // Rest timer hit 0: play the notification sound and/or vibrate twice.
            if (call.argument<Boolean>("sound") == true) {
                RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))?.play()
            }
            if (call.argument<Boolean>("vibrate") == true) {
                @Suppress("DEPRECATION")
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                val pattern = longArrayOf(0, 250, 150, 250)
                if (Build.VERSION.SDK_INT >= 26) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, -1)
                }
            }
            result.success(null)
        }
    }
}
