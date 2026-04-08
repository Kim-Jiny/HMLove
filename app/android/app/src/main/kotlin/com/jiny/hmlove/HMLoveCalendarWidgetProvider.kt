package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

data class WidgetEventInfo(
    val title: String,
    val color: String,
    val isAnniversary: Boolean,
    val eventType: String
) {
    val sortPriority: Int
        get() = when {
            isAnniversary -> 0
            eventType == "schedule" -> 1
            eventType == "device" -> 2
            else -> 3 // feed, etc.
        }
}

class HMLoveCalendarWidgetProvider : AppWidgetProvider() {

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

                val views = RemoteViews(context.packageName, R.layout.widget_calendar)
                views.setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))

                val myName = prefs.getString("myName", "나") ?: "나"
                val partnerName = prefs.getString("partnerName", "상대방") ?: "상대방"
                val startDate = prefs.getString("startDate", "") ?: ""

                // Calculate D-Day
                val parsed = parseStartDate(startDate)
                val daysTogether = if (parsed != null) {
                    java.time.temporal.ChronoUnit.DAYS.between(parsed, LocalDate.now()) + 1
                } else {
                    prefs.getSafeLong("daysTogether", 0)
                }

                val anniversary = if (parsed != null) calcNextAnniversary(parsed) else null

                views.setTextViewText(R.id.cal_couple_names, "$myName ♥ $partnerName")

                var ddayText = "${daysTogether}일"
                if (anniversary != null) {
                    ddayText += " · ${anniversary.first} D-${anniversary.second}"
                }
                views.setTextViewText(R.id.cal_dday_info, ddayText)

                // Determine display month.
                // If cached month is stale, prefer the real current month so the widget
                // doesn't stay stuck on the previous month until the app is opened again.
                val calendarYearMonth = prefs.getString("calendarYearMonth", "") ?: ""
                val monthFormatter = DateTimeFormatter.ofPattern("yyyy-MM")
                val currentMonth = YearMonth.now()
                val displayMonth = if (calendarYearMonth.isNotEmpty()) {
                    try {
                        val cachedMonth = YearMonth.parse(calendarYearMonth, monthFormatter)
                        if (cachedMonth == currentMonth) cachedMonth else currentMonth
                    } catch (e: Exception) {
                        currentMonth
                    }
                } else {
                    currentMonth
                }

                views.setTextViewText(R.id.cal_month_title, "${displayMonth.year}년 ${displayMonth.monthValue}월")

                // Parse calendar events — multiple per date, sorted by priority
                val eventsJson = prefs.getString("calendarEvents", "[]") ?: "[]"
                val eventDates = mutableMapOf<String, MutableList<WidgetEventInfo>>()
                try {
                    val jsonArray = JSONArray(eventsJson)
                    for (i in 0 until jsonArray.length()) {
                        val obj = jsonArray.getJSONObject(i)
                        val date = obj.getString("date").take(10)
                        val title = obj.optString("title", "")
                        val color = obj.optString("color", "#E91E63")
                        val isAnniversary = obj.optBoolean("isAnniversary", false)
                        val eventType = obj.optString("eventType", "schedule")
                        val info = WidgetEventInfo(title, color, isAnniversary, eventType)
                        eventDates.getOrPut(date) { mutableListOf() }.add(info)
                    }
                } catch (_: Exception) {}
                // Sort each date's events by priority
                for ((_, list) in eventDates) {
                    list.sortBy { it.sortPriority }
                }

                // Build calendar grid
                val firstOfMonth = displayMonth.atDay(1)
                val firstWeekday = firstOfMonth.dayOfWeek.value % 7 // 0=Sun
                val daysInMonth = displayMonth.lengthOfMonth()
                val prevMonth = displayMonth.minusMonths(1)
                val daysInPrevMonth = prevMonth.lengthOfMonth()
                val today = LocalDate.now()
                val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")

                val rowIds = intArrayOf(
                    R.id.cal_row_0, R.id.cal_row_1, R.id.cal_row_2,
                    R.id.cal_row_3, R.id.cal_row_4, R.id.cal_row_5
                )

                // Clear all rows first
                for (rowId in rowIds) {
                    views.removeAllViews(rowId)
                }

                for (cellIndex in 0 until 42) {
                    val row = cellIndex / 7
                    val col = cellIndex % 7

                    val day: Int
                    val dateStr: String
                    val isCurrentMonth: Boolean

                    when {
                        cellIndex < firstWeekday -> {
                            day = daysInPrevMonth - firstWeekday + 1 + cellIndex
                            dateStr = prevMonth.atDay(day).format(dateFormatter)
                            isCurrentMonth = false
                        }
                        cellIndex < firstWeekday + daysInMonth -> {
                            day = cellIndex - firstWeekday + 1
                            dateStr = displayMonth.atDay(day).format(dateFormatter)
                            isCurrentMonth = true
                        }
                        else -> {
                            day = cellIndex - firstWeekday - daysInMonth + 1
                            val nextMonth = displayMonth.plusMonths(1)
                            dateStr = nextMonth.atDay(day).format(dateFormatter)
                            isCurrentMonth = false
                        }
                    }

                    val events = if (isCurrentMonth) eventDates[dateStr]?.take(5) else null
                    val hasEvents = !events.isNullOrEmpty()

                    val cellView = if (hasEvents) {
                        RemoteViews(context.packageName, R.layout.widget_calendar_cell_event)
                    } else {
                        RemoteViews(context.packageName, R.layout.widget_calendar_cell)
                    }

                    val isToday = isCurrentMonth &&
                        today.year == displayMonth.year &&
                        today.monthValue == displayMonth.monthValue &&
                        day == today.dayOfMonth

                    cellView.setTextViewText(R.id.cell_day, day.toString())

                    if (isToday) {
                        cellView.setInt(R.id.cell_day, "setBackgroundResource", R.drawable.widget_calendar_today_bg)
                        cellView.setTextColor(R.id.cell_day, Color.WHITE)
                    } else if (!isCurrentMonth) {
                        cellView.setTextColor(R.id.cell_day, Color.parseColor("#BDBDBD"))
                    } else if (col == 0) {
                        cellView.setTextColor(R.id.cell_day, Color.parseColor("#E91E63"))
                    } else {
                        cellView.setTextColor(R.id.cell_day, Color.parseColor("#424242"))
                    }

                    // Add event bars dynamically
                    if (hasEvents) {
                        for (event in events!!) {
                            val barView = RemoteViews(context.packageName, R.layout.widget_event_bar_item)
                            barView.setTextViewText(R.id.event_bar_text, event.title)
                            val barColor = try {
                                Color.parseColor(event.color)
                            } catch (_: Exception) {
                                Color.parseColor("#E91E63")
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                barView.setColorStateList(
                                    R.id.event_bar_text,
                                    "setBackgroundTintList",
                                    ColorStateList.valueOf(barColor)
                                )
                            } else {
                                barView.setInt(R.id.event_bar_text, "setBackgroundColor", barColor)
                            }
                            cellView.addView(R.id.cell_events_container, barView)
                        }
                    }

                    views.addView(rowIds[row], cellView)
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
