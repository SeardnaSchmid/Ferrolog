package com.seardnaschmid.ferrolog

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        /// In the foreground: the Dart timer signals the end of the rest, no notification needed.
        @Volatile var visible = false

        /// Vibrates in the rhythm of the beep [kind] (see RestSound).
        fun vibrate(c: Context, kind: String = "end") {
            @Suppress("DEPRECATION")
            val vibrator = c.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val pattern = when (kind) {
                "twice" -> longArrayOf(0, 60, 100, 60)
                "last" -> longArrayOf(0, 120)
                else -> longArrayOf(0, 250, 150, 250)
            }
            if (Build.VERSION.SDK_INT >= 26) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        }
    }

    private var permissionResult: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        visible = true
        Notify.manager(this).cancel(Notify.REST_ID) // back in the app, the alert has done its job
    }

    override fun onPause() {
        visible = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ferrolog/notify").setMethodCallHandler { call, result ->
            when (call.method) {
                "askPermission" -> {
                    if (Build.VERSION.SDK_INT < 33 ||
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(Notify.allowed(this))
                    } else {
                        permissionResult?.success(false)
                        permissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                    }
                }
                "training" -> {
                    val b = Bundle()
                    for ((k, v) in call.arguments as Map<*, *>) {
                        when (v) {
                            is String -> b.putString(k as String, v)
                            is Boolean -> b.putBoolean(k as String, v)
                            is Number -> b.putLong(k as String, v.toLong())
                        }
                    }
                    try {
                        TrainingService.update(this, b)
                    } catch (e: Exception) {
                        // Not allowed from the background (Android 12+); the next change in the app tries again.
                    }
                    result.success(null)
                }
                "trainingStop" -> {
                    TrainingService.stop(this)
                    result.success(null)
                }
                "reminders" -> {
                    Notify.channel(this, Notify.REMINDERS, call.argument<String>("channelName"))
                    val list = JSONArray()
                    for (r in call.argument<List<Map<String, Any>>>("list")!!) list.put(JSONObject(r))
                    Notify.saveReminders(this, list.toString())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
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
            val kind = call.argument<String>("beep") ?: "end"
            // The service plays the rest's countdown itself while it runs the same rest; timed-set
            // beeps (no "restLeft") always come from here.
            val left = call.argument<Int>("restLeft")
            if (left != null && TrainingService.running && TrainingService.restEnd > 0 &&
                Math.abs(TrainingService.restEnd - System.currentTimeMillis() - left * 1000L) < 3000
            ) {
                result.success(null)
                return@setMethodCallHandler
            }
            RestSound.play(this, kind, call.argument<Boolean>("sound") == true,
                call.argument<Boolean>("vibrate") == true)
            result.success(null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 1) return
        permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        permissionResult = null
    }
}
