package com.jiny.hmlove

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java) ?: return

            // 기본 채널 (소리 있음)
            val defaultChannel = NotificationChannel(
                "default",
                "기본 알림",
                NotificationManager.IMPORTANCE_HIGH
            )
            manager.createNotificationChannel(defaultChannel)

            // 무음 채널
            val silentChannel = NotificationChannel(
                "silent",
                "무음 알림",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(silentChannel)
        }
    }
}
