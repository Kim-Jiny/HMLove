package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class HMLoveWidgetProvider : AppWidgetProvider() {
    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                val prefs = HomeWidgetPlugin.getData(context)
                val isConnected = prefs.getBoolean("isConnected", false)

                if (!isConnected) {
                    val views = RemoteViews(context.packageName, R.layout.widget_not_connected)
                    views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                    continue
                }

                val views = RemoteViews(context.packageName, R.layout.widget_couple)

                views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))

                val myName = prefs.getString("myName", "나") ?: "나"
                val partnerName = prefs.getString("partnerName", "상대방") ?: "상대방"
                val daysTogether = prefs.getSafeLong("daysTogether", 0)
                val startDate = prefs.getString("startDate", "") ?: ""
                val nextAnniversaryName = prefs.getString("nextAnniversaryName", null)
                val nextAnniversaryDaysLeft = if (prefs.contains("nextAnniversaryDaysLeft")) {
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

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                val views = RemoteViews(context.packageName, R.layout.widget_not_connected)
                views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
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
