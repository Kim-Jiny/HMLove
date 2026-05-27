package com.jiny.hmlove

import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * 위젯 Provider 들이 401 받았을 때 refresh token 으로 새 access token 받아 prefs 갱신.
 *
 * - prefs 에 refreshToken / apiBaseUrl 이 있어야 함 (WidgetService.saveAuthInfo 에서 저장)
 * - 성공 시 prefs 의 authToken 갱신 + 새 token 반환
 * - 실패 시 null 반환 → 호출 측은 fetch 포기 (다음 cooldown 까지 대기)
 *
 * Dart 측 Dio interceptor 와 동일한 /auth/refresh 엔드포인트 사용.
 */
object WidgetTokenRefresher {
    private const val TAG = "WidgetTokenRefresher"

    @Synchronized
    fun refresh(prefs: SharedPreferences): String? {
        val refreshToken = prefs.getString("refreshToken", "") ?: ""
        val baseUrl = (prefs.getString("apiBaseUrl", "") ?: "").trimEnd('/')
        if (refreshToken.isEmpty() || baseUrl.isEmpty()) {
            if (BuildConfig.DEBUG) {
                Log.w(TAG, "refresh: missing refreshToken or baseUrl — skip")
            }
            return null
        }

        var conn: HttpURLConnection? = null
        return try {
            val url = URL("$baseUrl/auth/refresh")
            conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                connectTimeout = 8_000
                readTimeout = 10_000
            }
            val body = JSONObject().put("refreshToken", refreshToken).toString()
            conn.outputStream.use { it.write(body.toByteArray()) }
            val code = conn.responseCode
            if (code !in 200..299) {
                if (BuildConfig.DEBUG) Log.w(TAG, "refresh: HTTP $code")
                return null
            }
            val responseBody = conn.inputStream.bufferedReader().use { it.readText() }
            val json = JSONObject(responseBody)
            val newToken = json.optString("accessToken").ifEmpty { null }
            if (newToken == null) {
                if (BuildConfig.DEBUG) Log.w(TAG, "refresh: no accessToken in response")
                return null
            }
            prefs.edit().putString("authToken", newToken).apply()
            if (BuildConfig.DEBUG) Log.i(TAG, "refresh: success — new token saved")
            newToken
        } catch (e: Throwable) {
            if (BuildConfig.DEBUG) Log.w(TAG, "refresh: error ${e.message}")
            null
        } finally {
            try { conn?.disconnect() } catch (_: Throwable) {}
        }
    }
}
