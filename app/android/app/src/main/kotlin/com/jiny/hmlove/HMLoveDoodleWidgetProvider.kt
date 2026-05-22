package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.time.Duration
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.concurrent.Executors

/**
 * 2x2 그림 위젯 — 상대방이 보낸 마지막 그림을 표시.
 *
 * 데이터 흐름:
 *  - Flutter `WidgetService.updateDoodleData(...)` → SharedPreferences
 *    (doodleImageUrl / doodleReceivedAt / doodleSenderName)
 *  - 위젯이 update 될 때 imageUrl을 보고, 캐시(파일)에 없으면 백그라운드로 다운받고
 *    다음 update에서 그림 표시. 캐시는 cacheDir/doodle/{hash}.png.
 */
class HMLoveDoodleWidgetProvider : AppWidgetProvider() {
    private val ioExecutor by lazy { Executors.newSingleThreadExecutor() }

    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context,
            42,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val isConnected = widgetHasSession(prefs)

        for (appWidgetId in appWidgetIds) {
            if (!isConnected) {
                val views = buildNotConnectedWidgetViews(context, prefs, launchAppIntent(context))
                appWidgetManager.updateAppWidget(appWidgetId, views)
                continue
            }

            val imageUrl = prefs.getString("doodleImageUrl", null)
            val receivedAt = prefs.getString("doodleReceivedAt", null)
            val senderName = prefs.getString("doodleSenderName", null)

            val views = RemoteViews(context.packageName, R.layout.widget_doodle)
            views.setOnClickPendingIntent(R.id.widget_doodle_root, launchAppIntent(context))

            if (imageUrl.isNullOrEmpty()) {
                showEmpty(views)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                continue
            }

            val cached = cacheFileFor(context, imageUrl)
            if (cached.exists() && cached.length() > 0) {
                showImage(views, cached, senderName, receivedAt)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } else {
                // 캐시 미스 → 다운로드 시작, 일단 empty 상태로 표시
                showEmpty(views)
                appWidgetManager.updateAppWidget(appWidgetId, views)

                ioExecutor.execute {
                    val ok = downloadToCache(imageUrl, cached, prefs.getString("authToken", null))
                    if (ok) {
                        // 다운로드 완료 → 위젯 다시 그리기
                        val refreshed = RemoteViews(context.packageName, R.layout.widget_doodle)
                        refreshed.setOnClickPendingIntent(
                            R.id.widget_doodle_root,
                            launchAppIntent(context),
                        )
                        showImage(refreshed, cached, senderName, receivedAt)
                        appWidgetManager.updateAppWidget(appWidgetId, refreshed)
                    }
                }
            }
        }
    }

    private fun showEmpty(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_doodle_image, View.GONE)
        views.setViewVisibility(R.id.widget_doodle_empty, View.VISIBLE)
        views.setViewVisibility(R.id.widget_doodle_caption, View.GONE)
    }

    private fun showImage(
        views: RemoteViews,
        file: File,
        senderName: String?,
        receivedAtIso: String?,
    ) {
        // RemoteViews IPC 한도(~1MB)를 피하려고 적절히 다운샘플링.
        // 1) 이미지 사이즈 측정 → 512px 기준으로 inSampleSize 계산
        val sizeOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        try {
            BitmapFactory.decodeFile(file.absolutePath, sizeOpts)
        } catch (_: Throwable) {
            showEmpty(views)
            return
        }
        val target = 512
        var sample = 1
        while (sizeOpts.outWidth / (sample * 2) >= target &&
            sizeOpts.outHeight / (sample * 2) >= target
        ) {
            sample *= 2
        }
        val decodeOpts = BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = android.graphics.Bitmap.Config.RGB_565
        }
        val bitmap = try {
            BitmapFactory.decodeFile(file.absolutePath, decodeOpts)
        } catch (_: Throwable) {
            null
        }

        if (bitmap == null) {
            showEmpty(views)
            return
        }

        views.setImageViewBitmap(R.id.widget_doodle_image, bitmap)
        views.setViewVisibility(R.id.widget_doodle_image, View.VISIBLE)
        views.setViewVisibility(R.id.widget_doodle_empty, View.GONE)

        val caption = buildCaption(senderName, receivedAtIso)
        if (caption.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_doodle_caption, View.GONE)
        } else {
            views.setTextViewText(R.id.widget_doodle_caption, caption)
            views.setViewVisibility(R.id.widget_doodle_caption, View.VISIBLE)
        }
    }

    private fun buildCaption(senderName: String?, receivedAtIso: String?): String? {
        val name = senderName?.takeIf { it.isNotEmpty() } ?: "상대방"
        val relative = receivedAtIso?.let { formatRelative(it) }
        return if (relative != null) "$name · $relative" else name
    }

    /** ISO8601 → "방금", "5분 전", "3시간 전", "2일 전" 등의 짧은 표현. */
    private fun formatRelative(iso: String): String? {
        val instant = try {
            OffsetDateTime.parse(iso, DateTimeFormatter.ISO_OFFSET_DATE_TIME)
                .atZoneSameInstant(ZoneId.systemDefault())
                .toLocalDateTime()
        } catch (_: DateTimeParseException) {
            null
        } ?: return null

        val now = java.time.LocalDateTime.now()
        val seconds = Duration.between(instant, now).seconds
        return when {
            seconds < 60 -> "방금"
            seconds < 3600 -> "${seconds / 60}분 전"
            seconds < 86400 -> "${seconds / 3600}시간 전"
            seconds < 604800 -> "${seconds / 86400}일 전"
            else -> "${seconds / 604800}주 전"
        }
    }

    private fun cacheFileFor(context: Context, urlString: String): File {
        val dir = File(context.cacheDir, "doodle").also { it.mkdirs() }
        val name = urlString.hashCode().toString() + ".png"
        return File(dir, name)
    }

    private fun downloadToCache(urlString: String, target: File, token: String?): Boolean {
        return try {
            val url = URL(urlString)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 10_000
                readTimeout = 15_000
                if (!token.isNullOrEmpty()) {
                    setRequestProperty("Authorization", "Bearer $token")
                }
            }
            try {
                if (conn.responseCode in 200..299) {
                    conn.inputStream.use { input ->
                        target.outputStream().use { output -> input.copyTo(output) }
                    }
                    true
                } else {
                    false
                }
            } finally {
                conn.disconnect()
            }
        } catch (_: Throwable) {
            false
        }
    }
}
