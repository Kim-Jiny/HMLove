package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/// 디버그 빌드에서만 출력. release 에서는 logcat 노이즈 / 정보 노출 둘 다 방지.
private inline fun devLogW(tag: String, msg: String) {
    if (BuildConfig.DEBUG) Log.w(tag, msg)
}

private inline fun devLogI(tag: String, msg: String) {
    if (BuildConfig.DEBUG) Log.i(tag, msg)
}

/**
 * 2x2 그림 위젯 — 상대방이 보낸 마지막 그림을 표시.
 *
 * 데이터 흐름:
 *  1) 캐시된 SharedPreferences 의 doodleImageUrl 로 즉시 1차 렌더 (오프라인/즉답)
 *  2) 백그라운드 스레드에서 /api/doodle/latest 호출 → 새 URL/이미지 받아오기
 *  3) prefs 갱신 + 이미지 다운로드 + 위젯 재렌더
 *
 * Dart background isolate 에서는 home_widget plugin method channel 이 동작하지 않아
 * authToken/apiBaseUrl 을 못 읽는다. Kotlin 은 동일 프로세스의 SharedPreferences 에
 * 직접 접근 가능하므로 여기서 fetch 하는 게 가장 robust.
 */
class HMLoveDoodleWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val TAG = "HMLoveDoodle"
    }

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

        // 1) 일단 캐시된 URL 로 즉시 렌더 (없으면 empty)
        for (appWidgetId in appWidgetIds) {
            if (!isConnected) {
                val views =
                    buildNotConnectedWidgetViews(context, prefs, launchAppIntent(context))
                appWidgetManager.updateAppWidget(appWidgetId, views)
                continue
            }
            renderFromCache(context, appWidgetManager, appWidgetId, prefs)
        }

        if (!isConnected) return

        // 2) 백그라운드에서 latest fetch → prefs 갱신 → 다시 렌더
        ioExecutor.execute {
            fetchLatestAndRefresh(context, appWidgetManager, appWidgetIds, prefs)
        }
    }

    /// prefs 의 doodleImageUrl + 디스크 캐시로 위젯 한 번 그림.
    private fun renderFromCache(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: android.content.SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_doodle)
        views.setOnClickPendingIntent(R.id.widget_doodle_root, launchAppIntent(context))

        val imageUrl = prefs.getString("doodleImageUrl", null)
        if (imageUrl.isNullOrEmpty()) {
            showEmpty(views)
        } else {
            val cached = cacheFileFor(context, imageUrl)
            if (cached.exists() && cached.length() > 0) {
                showImage(views, cached)
            } else {
                showEmpty(views)
            }
        }
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /// 서버에서 latest doodle 받아 prefs/캐시 업데이트하고 위젯 재렌더.
    /// Dart BG isolate 가 token/baseUrl 을 못 받아도 여기서 직접 읽고 호출함.
    private fun fetchLatestAndRefresh(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        prefs: android.content.SharedPreferences,
    ) {
        val token = prefs.getString("authToken", "") ?: ""
        val baseUrl = prefs.getString("apiBaseUrl", "") ?: ""
        if (token.isEmpty() || baseUrl.isEmpty()) {
            devLogW(TAG,"fetchLatest: missing token/baseUrl in prefs — skipping")
            return
        }

        val latest = fetchDoodleLatest("$baseUrl/doodle/latest", token)
        if (latest == null) {
            devLogW(TAG,"fetchLatest: failed or no doodle")
            return
        }

        val (imageUrl, createdAt, senderName) = latest
        devLogI(TAG,"fetchLatest: imageUrl=$imageUrl @ $createdAt")

        // prefs 갱신
        prefs.edit()
            .putString("doodleImageUrl", imageUrl)
            .putString("doodleReceivedAt", createdAt)
            .putString("doodleSenderName", senderName)
            .apply()

        if (imageUrl.isNullOrEmpty()) {
            // 받은 그림 없음 — empty 상태로 재렌더
            for (id in appWidgetIds) renderFromCache(context, appWidgetManager, id, prefs)
            return
        }

        // 이미지 캐시 확인/다운로드
        val cached = cacheFileFor(context, imageUrl)
        if (!cached.exists() || cached.length() == 0L) {
            val ok = downloadToCache(imageUrl, cached, token)
            if (!ok) {
                devLogW(TAG,"fetchLatest: image download failed for $imageUrl")
            }
        }

        // 위젯 재렌더
        for (id in appWidgetIds) {
            renderFromCache(context, appWidgetManager, id, prefs)
        }
    }

    /// /doodle/latest 호출 → (imageUrl, createdAt, senderName) Triple 반환 또는 null.
    private fun fetchDoodleLatest(
        urlString: String,
        token: String,
    ): Triple<String?, String?, String?>? {
        return try {
            val url = URL(urlString)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                connectTimeout = 10_000
                readTimeout = 15_000
            }
            try {
                if (conn.responseCode !in 200..299) {
                    devLogW(TAG,"fetchDoodleLatest: HTTP ${conn.responseCode}")
                    return null
                }
                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val root = JSONObject(body)
                if (root.isNull("doodle")) {
                    // 받은 그림 자체가 없음
                    return Triple(null, null, null)
                }
                val doodle = root.getJSONObject("doodle")
                val imageUrl = doodle.optString("imageUrl").ifEmpty { null }
                val createdAt = doodle.optString("createdAt").ifEmpty { null }
                val sender = doodle.optJSONObject("sender")
                val senderName = sender?.optString("nickname")?.ifEmpty { null }
                Triple(imageUrl, createdAt, senderName)
            } finally {
                conn.disconnect()
            }
        } catch (e: Throwable) {
            devLogW(TAG,"fetchDoodleLatest error: ${e.message}")
            null
        }
    }

    private fun showEmpty(views: RemoteViews) {
        views.setViewVisibility(R.id.widget_doodle_image, View.GONE)
        views.setViewVisibility(R.id.widget_doodle_empty, View.VISIBLE)
    }

    private fun showImage(views: RemoteViews, file: File) {
        // RemoteViews IPC 한도(~1MB)를 피하려고 적절히 다운샘플링.
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
