package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import android.graphics.Color
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

internal fun widgetHasSession(prefs: SharedPreferences): Boolean {
    if (prefs.getBoolean("isConnected", false)) return true
    val authToken = prefs.getString("authToken", "") ?: ""
    val myName = prefs.getString("myName", "") ?: ""
    val partnerName = prefs.getString("partnerName", "") ?: ""
    val startDate = prefs.getString("startDate", "") ?: ""
    return authToken.isNotEmpty() ||
        myName.isNotEmpty() ||
        partnerName.isNotEmpty() ||
        startDate.isNotEmpty()
}

internal fun widgetSettingsPendingIntent(context: Context): PendingIntent {
    val intent = Intent(context, CalendarWidgetSettingsActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return PendingIntent.getActivity(
        context, 10, intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
}

private fun withAlpha(color: Int, alpha: Int): Int =
    (alpha.coerceIn(0, 255) shl 24) or (color and 0x00FFFFFF)

internal fun selectedWidgetTheme(prefs: SharedPreferences): CalendarWidgetThemeOption {
    val bgArgb = prefs.getInt(
        CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB,
        0xFFFFFFFF.toInt()
    )
    val savedThemeId = prefs.getString(CalendarWidgetSettingsActivity.PREF_KEY_THEME_ID, null)
    if (!savedThemeId.isNullOrEmpty()) {
        return CalendarWidgetSettingsActivity.themeFor(savedThemeId)
    }
    val bgRgb = (bgArgb and 0x00FFFFFF) or 0xFF000000.toInt()
    return CalendarWidgetSettingsActivity.THEMES.minByOrNull {
        val dr = Color.red(bgRgb) - Color.red(it.bgRgb)
        val dg = Color.green(bgRgb) - Color.green(it.bgRgb)
        val db = Color.blue(bgRgb) - Color.blue(it.bgRgb)
        dr * dr + dg * dg + db * db
    } ?: CalendarWidgetSettingsActivity.THEMES.first()
}

/**
 * 사용자가 배경을 실제로 바꿨는지 여부.
 *
 * 위젯 설정 화면은 '적용'만 눌러도 기본 테마·불투명 값(widgetBgArgb)을 저장한다.
 * 그 값으로 배경을 덮으면 기본 디자인(윤곽선·그라데이션·그림자 카드)이 납작한 단색으로
 * 바뀌어 새 디자인이 보이지 않으므로, "기본 테마 + 불투명"은 사용자 지정으로 보지 않는다.
 */
internal fun hasCustomWidgetBackground(prefs: SharedPreferences): Boolean {
    if (!prefs.contains(CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB)) return false
    val argb = prefs.getInt(
        CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB,
        0xFFFFFFFF.toInt()
    )
    val opaque = Color.alpha(argb) == 255
    return !(opaque && isDefaultWidgetTheme(selectedWidgetTheme(prefs)))
}

/** 사용자 지정 배경이 있을 때 종이 더미 장식(뒤 카드·테이프)을 숨긴다. 레이아웃에 없는 id 는 건드리지 않도록 호출부에서 구분. */
internal fun hidePaperDecor(views: RemoteViews, backCards: Boolean = true) {
    if (backCards) {
        views.setViewVisibility(R.id.paper_back_pink, View.GONE)
        views.setViewVisibility(R.id.paper_back_lavender, View.GONE)
    }
    views.setViewVisibility(R.id.paper_tape, View.GONE)
}

internal fun applyWidgetBackground(
    views: RemoteViews,
    prefs: SharedPreferences,
    hasBackCards: Boolean = true
) {
    if (!hasCustomWidgetBackground(prefs)) return
    val argb = prefs.getInt(
        CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB,
        0xFFFFFFFF.toInt()
    )
    hidePaperDecor(views, hasBackCards)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        views.setInt(
            R.id.widget_card,
            "setBackgroundResource",
            R.drawable.widget_background_tintable
        )
        views.setColorStateList(
            R.id.widget_card,
            "setBackgroundTintList",
            ColorStateList.valueOf(argb)
        )
    } else {
        views.setInt(R.id.widget_card, "setBackgroundColor", argb)
    }
}

private const val INK_COLOR = 0xFF4A3B52.toInt()
private const val ROSE_COLOR = 0xFFEC5F8E.toInt()

/** 다음 기념일까지의 진행률(0..1). 값이 없거나 비정상이면 null (막대 숨김). */
internal fun anniversaryProgressFraction(daysTogether: Long, daysLeft: Long?): Float? {
    if (daysLeft == null || daysLeft < 0 || daysTogether <= 0) return null
    val total = daysTogether + daysLeft
    if (total <= 0) return null
    return (daysTogether.toFloat() / total).coerceIn(0f, 1f)
}

/**
 * 진행 막대 비트맵: 잉크 외곽선 트랙 + 장미색 채움 + 채움 끝의 하트 스티커.
 * 레이아웃만으로는 하트를 채움 끝에 둘 수 없어 Canvas 로 직접 그린다.
 */
internal fun createAnniversaryProgressBitmap(
    context: Context,
    fraction: Float,
    fillColor: Int,
    widthDp: Float,
    heightDp: Float = 22f
): Bitmap {
    val density = context.resources.displayMetrics.density
    val w = (widthDp * density).toInt().coerceAtLeast(1)
    val h = (heightDp * density).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val sw = 1.6f * density
    val trackH = 10f * density
    val heartSize = h - sw
    val heartR = heartSize / 2f
    val cy = h / 2f

    val track = RectF(sw / 2f, cy - trackH / 2f, w - sw / 2f, cy + trackH / 2f)
    val trackRadius = trackH / 2f
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)

    // 트랙(흰색)
    paint.style = Paint.Style.FILL
    paint.color = 0xFFFFFFFF.toInt()
    canvas.drawRoundRect(track, trackRadius, trackRadius, paint)

    // 채움
    val endX = (track.left + track.width() * fraction).coerceIn(heartR + sw / 2f, w - heartR - sw / 2f)
    val fill = RectF(track.left + sw / 2f, track.top + sw / 2f, endX, track.bottom - sw / 2f)
    paint.color = fillColor
    canvas.drawRoundRect(fill, trackRadius - sw / 2f, trackRadius - sw / 2f, paint)
    // 채움 윗부분 하이라이트
    paint.color = 0x55FFFFFF
    val hl = RectF(fill.left + trackRadius / 2f, fill.top + sw * 0.6f, fill.right - trackRadius / 2f, fill.top + sw * 0.6f + 2f * density)
    if (hl.right > hl.left) canvas.drawRoundRect(hl, density, density, paint)

    // 트랙 외곽선
    paint.style = Paint.Style.STROKE
    paint.strokeWidth = sw
    paint.color = INK_COLOR
    canvas.drawRoundRect(track, trackRadius, trackRadius, paint)

    // 하트 스티커(24x24 격자를 heartSize 로 스케일)
    val heart = Path().apply {
        moveTo(12f, 21f)
        cubicTo(12f, 21f, 3f, 15f, 3f, 8.8f)
        cubicTo(3f, 5.8f, 5.2f, 3.8f, 7.8f, 3.8f)
        cubicTo(9.6f, 3.8f, 11.2f, 4.8f, 12f, 6.4f)
        cubicTo(12.8f, 4.8f, 14.4f, 3.8f, 16.2f, 3.8f)
        cubicTo(18.8f, 3.8f, 21f, 5.8f, 21f, 8.8f)
        cubicTo(21f, 15f, 12f, 21f, 12f, 21f)
        close()
    }
    val highlight = Path().apply {
        moveTo(6.2f, 9f)
        cubicTo(6.1f, 7.6f, 6.9f, 6.6f, 8f, 6.4f)
    }
    val scale = heartSize * 1.1f / 24f
    val m = Matrix().apply {
        postScale(scale, scale)
        postTranslate(endX - 12f * scale, cy - 12f * scale)
    }
    heart.transform(m)
    highlight.transform(m)
    paint.style = Paint.Style.FILL
    paint.color = ROSE_COLOR
    canvas.drawPath(heart, paint)
    paint.style = Paint.Style.STROKE
    paint.strokeWidth = sw
    paint.strokeJoin = Paint.Join.ROUND
    paint.color = INK_COLOR
    canvas.drawPath(heart, paint)
    paint.strokeWidth = 1.3f * density
    paint.strokeCap = Paint.Cap.ROUND
    paint.color = 0xFFFFFFFF.toInt()
    canvas.drawPath(highlight, paint)
    return bitmap
}

/** 진행 막대를 그려 넣거나(값이 있을 때) 숨긴다. */
internal fun applyAnniversaryProgress(
    context: Context,
    views: RemoteViews,
    imageId: Int,
    hideIds: List<Int>,
    fraction: Float?,
    theme: CalendarWidgetThemeOption?,
    widthDp: Float
) {
    if (fraction == null) {
        for (id in hideIds) views.setViewVisibility(id, View.GONE)
        return
    }
    val fillColor = if (theme == null || isDefaultWidgetTheme(theme)) ROSE_COLOR else theme.primary
    views.setImageViewBitmap(
        imageId,
        createAnniversaryProgressBitmap(context, fraction, fillColor, widthDp)
    )
}

internal fun isDefaultWidgetTheme(theme: CalendarWidgetThemeOption): Boolean =
    theme.id == CalendarWidgetSettingsActivity.THEMES.first().id

private val LEGACY_MOOD_EMOJI_TO_KEY = mapOf(
    "\uD83D\uDE0A" to "happy",
    "\uD83E\uDD70" to "love",
    "\uD83E\uDD29" to "excited",
    "\uD83D\uDE4F" to "grateful",
    "\uD83D\uDE0C" to "peaceful",
    "\uD83D\uDE0E" to "proud",
    "\uD83E\uDD7A" to "missing",
    "\uD83D\uDE10" to "bored",
    "\uD83D\uDE22" to "sad",
    "\uD83D\uDE24" to "angry",
    "\uD83D\uDE34" to "tired",
    "\uD83D\uDE29" to "stressed"
)

/** 기분 키(우선) 또는 레거시 이모지 → 얼굴 벡터 드로어블. 없으면 neutral. */
internal fun moodFaceResFor(moodKey: String?, legacyEmoji: String?): Int {
    var key = moodKey?.trim().orEmpty()
    if (key.isEmpty()) {
        val emoji = legacyEmoji?.replace("\uFE0F", "")?.trim().orEmpty()
        key = LEGACY_MOOD_EMOJI_TO_KEY[emoji] ?: ""
    }
    return when (key) {
        "happy" -> R.drawable.mood_face_happy
        "love" -> R.drawable.mood_face_love
        "excited" -> R.drawable.mood_face_excited
        "grateful" -> R.drawable.mood_face_grateful
        "peaceful" -> R.drawable.mood_face_peaceful
        "proud" -> R.drawable.mood_face_proud
        "missing" -> R.drawable.mood_face_missing
        "bored" -> R.drawable.mood_face_bored
        "sad" -> R.drawable.mood_face_sad
        "angry" -> R.drawable.mood_face_angry
        "tired" -> R.drawable.mood_face_tired
        "stressed" -> R.drawable.mood_face_stressed
        else -> R.drawable.mood_face_neutral
    }
}

internal fun applyCoupleWidgetTheme(views: RemoteViews, theme: CalendarWidgetThemeOption) {
    val isDefault = isDefaultWidgetTheme(theme)
    // 기본(러브) 테마는 종이 카드 위 잉크색 글씨, 그 외 테마는 테마색을 그대로 사용.
    views.setTextColor(R.id.couple_names, if (isDefault) INK_COLOR else theme.primary)
    views.setTextColor(R.id.days_together, theme.primary)
    views.setTextColor(
        R.id.start_date,
        if (isDefault) 0xFF7A7480.toInt() else withAlpha(theme.primary, 128)
    )
    views.setTextColor(R.id.next_anniversary, theme.textSecondary)
    views.setTextColor(R.id.widget_settings_btn, theme.primary)
    if (!isDefaultWidgetTheme(theme) && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        views.setInt(
            R.id.widget_settings_btn,
            "setBackgroundResource",
            R.drawable.widget_calendar_nav_btn_bg
        )
        views.setColorStateList(
            R.id.widget_settings_btn,
            "setBackgroundTintList",
            ColorStateList.valueOf(withAlpha(theme.primary, 26))
        )
    }
}

internal fun applyMediumWidgetExtrasTheme(
    views: RemoteViews,
    theme: CalendarWidgetThemeOption
) {
    // 일정 칩은 흰 배경 위에 얹히므로 잉크색 고정. D-N 은 테마에 맞춘다.
    views.setTextColor(
        R.id.anniv_dday,
        if (isDefaultWidgetTheme(theme)) INK_COLOR else theme.textPrimary
    )
}

internal fun buildNotConnectedWidgetViews(
    context: Context,
    prefs: SharedPreferences,
    launchIntent: PendingIntent
): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.widget_not_connected)
    views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

    runCatching {
        applyWidgetBackground(views, prefs)
        val theme = selectedWidgetTheme(prefs)
        views.setTextColor(R.id.widget_not_connected_title, theme.primary)
        views.setTextColor(R.id.widget_not_connected_message, theme.textSecondary)
    }

    return views
}

class HMLoveWidgetProvider : AppWidgetProvider() {
    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildMediumWidgetViews(
        context: Context,
        prefs: SharedPreferences,
        applyStyling: Boolean = true
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_couple)

        views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
        views.setOnClickPendingIntent(R.id.widget_poke_btn, PokeReceiver.pendingIntent(context))
        views.setOnClickPendingIntent(
            R.id.widget_settings_btn,
            widgetSettingsPendingIntent(context)
        )

        val myName = prefs.getString("myName", "나") ?: "나"
        val partnerName = prefs.getString("partnerName", "상대방") ?: "상대방"
        val startDate = prefs.getString("startDate", "") ?: ""

        if (applyStyling) {
            runCatching {
                applyWidgetBackground(views, prefs)
                val theme = selectedWidgetTheme(prefs)
                applyCoupleWidgetTheme(views, theme)
                applyMediumWidgetExtrasTheme(views, theme)
            }
        }

        val parsed = parseStartDate(startDate)
        val daysTogether = if (parsed != null) {
            ChronoUnit.DAYS.between(parsed, LocalDate.now()) + 1
        } else {
            prefs.getSafeLong("daysTogether", 0)
        }

        val anniversary = if (parsed != null) calcNextAnniversary(parsed) else null
        val nextAnniversaryName = anniversary?.first ?: prefs.getString("nextAnniversaryName", null)
        val nextAnniversaryDaysLeft = anniversary?.second ?: if (prefs.contains("nextAnniversaryDaysLeft")) {
            prefs.getSafeLong("nextAnniversaryDaysLeft", 0)
        } else null

        val myMoodFace = moodFaceResFor(
            prefs.getString("myMoodKey", null),
            prefs.getString("myMoodEmoji", null)
        )
        val partnerMoodFace = moodFaceResFor(
            prefs.getString("partnerMoodKey", null),
            prefs.getString("partnerMoodEmoji", null)
        )
        val todaySchedule = prefs.getString("todaySchedule", "") ?: ""

        views.setTextViewText(R.id.couple_names, "$myName ♥ $partnerName")
        views.setTextViewText(R.id.days_together, "${daysTogether}일째")
        views.setTextViewText(R.id.start_date, "$startDate ~")
        views.setImageViewResource(R.id.mood_my_face, myMoodFace)
        views.setImageViewResource(R.id.mood_partner_face, partnerMoodFace)
        views.setTextViewText(R.id.mood_my_name, myName)
        views.setTextViewText(R.id.mood_partner_name, partnerName)

        if (todaySchedule.isNotEmpty()) {
            views.setTextViewText(R.id.today_schedule, todaySchedule)
        } else {
            views.setTextViewText(R.id.today_schedule, "오늘 일정 없음")
        }

        if (nextAnniversaryName != null && nextAnniversaryDaysLeft != null) {
            views.setTextViewText(R.id.next_anniversary, "${nextAnniversaryName}까지")
            views.setTextViewText(R.id.anniv_dday, "D-$nextAnniversaryDaysLeft")
        } else {
            views.setTextViewText(R.id.next_anniversary, "")
            views.setViewVisibility(R.id.next_anniversary, View.GONE)
            views.setTextViewText(R.id.anniv_dday, "")
        }

        runCatching {
            applyAnniversaryProgress(
                context,
                views,
                R.id.anniv_progress,
                listOf(R.id.anniv_progress_row),
                anniversaryProgressFraction(daysTogether, nextAnniversaryDaysLeft),
                if (applyStyling) selectedWidgetTheme(prefs) else null,
                96f
            )
        }.onFailure { views.setViewVisibility(R.id.anniv_progress_row, View.GONE) }

        return views
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val prefs = HomeWidgetPlugin.getData(context)
            val isConnected = widgetHasSession(prefs)

            if (!isConnected) {
                val views = buildNotConnectedWidgetViews(context, prefs, launchAppIntent(context))
                appWidgetManager.updateAppWidget(appWidgetId, views)
                continue
            }

            try {
                val views = buildMediumWidgetViews(context, prefs)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                val views = buildMediumWidgetViews(context, prefs, applyStyling = false)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}

fun SharedPreferences.getSafeLong(key: String, defaultValue: Long): Long {
    return try {
        getLong(key, defaultValue)
    } catch (e: ClassCastException) {
        try {
            getInt(key, defaultValue.toInt()).toLong()
        } catch (e2: ClassCastException) {
            getString(key, null)?.toLongOrNull() ?: defaultValue
        }
    }
}

fun parseStartDate(dateStr: String): LocalDate? {
    return try {
        LocalDate.parse(dateStr, DateTimeFormatter.ofPattern("yyyy.MM.dd"))
    } catch (e: Exception) {
        null
    }
}

fun calcNextAnniversary(startDate: LocalDate): Pair<String, Long>? {
    val today = LocalDate.now()
    val milestones = listOf(100, 200, 300, 365, 500, 700, 730, 1000, 1095, 1461)
    for (days in milestones) {
        val date = startDate.plusDays((days - 1).toLong())
        if (date.isAfter(today)) {
            val daysLeft = ChronoUnit.DAYS.between(today, date)
            return Pair("${days}일", daysLeft)
        }
    }
    // Fall back to annual anniversary
    var year = today.year - startDate.year
    val thisYearAnniv = startDate.withYear(today.year)
    if (!thisYearAnniv.isAfter(today)) year++
    val nextAnniv = startDate.withYear(startDate.year + year)
    val daysLeft = ChronoUnit.DAYS.between(today, nextAnniv)
    return Pair("${year}주년", daysLeft)
}
