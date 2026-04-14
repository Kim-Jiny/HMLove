package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class HMLoveSmallWidgetProvider : AppWidgetProvider() {
    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildSmallWidgetViews(
        context: Context,
        prefs: android.content.SharedPreferences,
        applyStyling: Boolean = true
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_couple_small)

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
                applyCoupleWidgetTheme(views, selectedWidgetTheme(prefs))
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

        views.setTextViewText(R.id.couple_names, "$myName ♥ $partnerName")
        views.setTextViewText(R.id.days_together, "${daysTogether}일")
        views.setTextViewText(R.id.start_date, "$startDate ~")

        if (nextAnniversaryName != null && nextAnniversaryDaysLeft != null) {
            views.setTextViewText(
                R.id.next_anniversary,
                "$nextAnniversaryName D-$nextAnniversaryDaysLeft"
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
                val views = buildSmallWidgetViews(context, prefs)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                val views = buildSmallWidgetViews(context, prefs, applyStyling = false)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
