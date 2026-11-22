package com.seardnaschmid.ferrolog

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper

/// Brief, transient focus lets music continue at reduced volume until the signal finishes.
object RestSound {
    private val handler = Handler(Looper.getMainLooper())
    fun play(c: Context, warning: Boolean, sound: Boolean, vibrate: Boolean) {
        if (vibrate) MainActivity.vibrate(c)
        if (!sound) return
        val audio = c.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val listener = AudioManager.OnAudioFocusChangeListener { }
        val request = if (Build.VERSION.SDK_INT >= 26) AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            .setOnAudioFocusChangeListener(listener).build() else null
        val granted = if (Build.VERSION.SDK_INT >= 26) audio.requestAudioFocus(request!!) else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return
        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
        if (warning) {
            for (delay in listOf(0L, 220L, 440L)) handler.postDelayed({ tone.startTone(ToneGenerator.TONE_PROP_BEEP, 110) }, delay)
        } else tone.startTone(ToneGenerator.TONE_PROP_ACK, 600)
        handler.postDelayed({
            tone.release()
            if (Build.VERSION.SDK_INT >= 26) audio.abandonAudioFocusRequest(request!!) else {
                @Suppress("DEPRECATION")
                audio.abandonAudioFocus(listener)
            }
        }, if (warning) 700 else 750)
    }
}
