package com.jiny.hmlove

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/** 위젯의 하트를 누르면 앱을 열지 않고 바로 '보고싶어' 콕을 보낸다. */
class PokeReceiver : BroadcastReceiver() {

    companion object {
        private const val ACTION = "com.jiny.hmlove.ACTION_POKE"

        fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, PokeReceiver::class.java).apply { action = ACTION }
            return PendingIntent.getBroadcast(
                context, 7001, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val app = context.applicationContext
        val pending = goAsync()
        val prefs = HomeWidgetPlugin.getData(app)
        val token = prefs.getString("authToken", null)
        val base = prefs.getString("apiBaseUrl", null)
        val ui = Handler(Looper.getMainLooper())

        if (token.isNullOrEmpty() || base.isNullOrEmpty()) {
            Toast.makeText(app, "앱을 한 번 열어 로그인해 주세요", Toast.LENGTH_SHORT).show()
            pending.finish()
            return
        }

        thread {
            var message = "콕을 보내지 못했어요"
            try {
                val conn = (URL("$base/poke").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 8000
                    readTimeout = 8000
                    doOutput = true
                    setRequestProperty("Authorization", "Bearer $token")
                    setRequestProperty("Content-Type", "application/json")
                }
                conn.outputStream.use { it.write("""{"kind":"miss"}""".toByteArray()) }
                when (conn.responseCode) {
                    201, 200 -> {
                        message = "보고싶어 콕을 보냈어요"
                        buzz(app)
                    }
                    429 -> message = "조금만 천천히 보내주세요"
                    400 -> message = "상대방이 연결되면 보낼 수 있어요"
                    401 -> message = "앱을 한 번 열어 다시 로그인해 주세요"
                }
                conn.disconnect()
            } catch (_: Exception) {
            }
            ui.post {
                Toast.makeText(app, message, Toast.LENGTH_SHORT).show()
                pending.finish()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun buzz(context: Context) {
        runCatching {
            val v = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
            v.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 40, 60, 40), -1))
        }
    }
}
