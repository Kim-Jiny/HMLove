package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.os.Build
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

internal fun applyWidgetBackground(
    views: RemoteViews,
    prefs: SharedPreferences
) {
    if (!prefs.contains(CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB)) return
    val argb = prefs.getInt(
        CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB,
        0xFFFFFFFF.toInt()
    )
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        views.setInt(
            R.id.widget_root,
            "setBackgroundResource",
            R.drawable.widget_background_tintable
        )
        views.setColorStateList(
            R.id.widget_root,
            "setBackgroundTintList",
            ColorStateList.valueOf(argb)
        )
    } else {
        views.setInt(R.id.widget_root, "setBackgroundColor", argb)
    }
}

internal fun applyCoupleWidgetTheme(views: RemoteViews, theme: CalendarWidgetThemeOption) {
    views.setTextColor(R.id.couple_names, theme.primary)
    views.setTextColor(R.id.days_together, theme.primary)
    views.setTextColor(R.id.start_date, withAlpha(theme.primary, 128))
    views.setTextColor(R.id.next_anniversary, theme.textSecondary)
    views.setTextColor(R.id.widget_settings_btn, theme.primary)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
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
    views.setTextColor(R.id.mood_row, theme.primary)
    views.setTextColor(R.id.today_schedule, theme.textPrimary)
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
        views.setTextColor(R.id.widget_not_connected_emoji, theme.primary)
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

        val myMoodEmoji = prefs.getString("myMoodEmoji", "\uD83D\uDE36") ?: "\uD83D\uDE36"
        val partnerMoodEmoji = prefs.getString("partnerMoodEmoji", "\uD83D\uDE36") ?: "\uD83D\uDE36"
        val todaySchedule = prefs.getString("todaySchedule", "") ?: ""

        views.setTextViewText(R.id.couple_names, "$myName ♥ $partnerName")
        views.setTextViewText(R.id.days_together, "${daysTogether}일째")
        views.setTextViewText(R.id.start_date, "$startDate ~")
        views.setTextViewText(R.id.mood_row, "$myMoodEmoji ♥ $partnerMoodEmoji")

        if (todaySchedule.isNotEmpty()) {
            views.setTextViewText(R.id.today_schedule, todaySchedule)
        } else {
            views.setTextViewText(R.id.today_schedule, "오늘 일정 없음")
        }

        if (nextAnniversaryName != null && nextAnniversaryDaysLeft != null) {
            views.setTextViewText(
                R.id.next_anniversary,
                "\uD83C\uDF89 $nextAnniversaryName D-$nextAnniversaryDaysLeft"
            )
        } else {
            views.setTextViewText(R.id.next_anniversary, "")
        }

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
