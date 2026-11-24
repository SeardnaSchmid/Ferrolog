package com.seardnaschmid.ferrolog

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.sin

/// The countdown's beeps: "twice" a short double (rest 30 and 15 s, lead-in 10 s), "last" a higher
/// short one (3, 2, 1), "end" a long one (0, go, timed-set signals). The vibration follows the same
/// rhythm. Brief, transient focus lets music continue at reduced volume until the beep finishes.
object RestSound {
    private val handler = Handler(Looper.getMainLooper())
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    fun play(c: Context, kind: String, sound: Boolean, vibrate: Boolean) {
        if (vibrate) MainActivity.vibrate(c, kind)
        if (!sound) return
        val audio = c.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val listener = AudioManager.OnAudioFocusChangeListener { }
        val request = if (Build.VERSION.SDK_INT >= 26) AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attributes)
            .setOnAudioFocusChangeListener(listener).build() else null
        val granted = if (Build.VERSION.SDK_INT >= 26) audio.requestAudioFocus(request!!) else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
        }
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) return
        val ms = when (kind) {
            "twice" -> beep(880.0, 80, count = 2)
            "last" -> beep(1320.0, 140)
            else -> beep(1320.0, 700)
        }
        handler.postDelayed({
            if (Build.VERSION.SDK_INT >= 26) audio.abandonAudioFocusRequest(request!!) else {
                @Suppress("DEPRECATION")
                audio.abandonAudioFocus(listener)
            }
        }, ms + 150L)
    }

    /**
     * [count] sine tones of [hz] for [ms] each, 100 ms apart, with 5 ms fades so they don't click.
     * Returns how long it plays, in ms.
     */
    private fun beep(hz: Double, ms: Int, count: Int = 1): Long {
        val rate = 44100
        val tone = rate * ms / 1000
        val period = tone + rate / 10
        val n = period * (count - 1) + tone
        val fade = rate / 200.0
        val samples = ShortArray(n) { j ->
            val i = j % period
            if (i >= tone) return@ShortArray 0
            val envelope = min(1.0, min(i / fade, (tone - i) / fade))
            (sin(2 * PI * hz * i / rate) * envelope * 0.8 * Short.MAX_VALUE).toInt().toShort()
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(attributes)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(rate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(n * 2)
            .build()
        track.write(samples, 0, n)
        track.play()
        val length = n * 1000L / rate
        handler.postDelayed({ track.release() }, length + 200L)
        return length
    }
}
