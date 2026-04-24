package com.jiny.hmlove

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.concurrent.ConcurrentHashMap

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

    companion object {
        const val ACTION_PREV_MONTH = "com.jiny.hmlove.CALENDAR_PREV_MONTH"
        const val ACTION_NEXT_MONTH = "com.jiny.hmlove.CALENDAR_NEXT_MONTH"
        const val ACTION_TODAY_MONTH = "com.jiny.hmlove.CALENDAR_TODAY_MONTH"
        private val MONTH_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM")
        private const val PREF_KEY_CALENDAR_EVENT_MONTHS = "widgetCalendarEventMonths"

        // Guard against spamming the server when the same month is in-flight.
        private val inFlightFetches = ConcurrentHashMap.newKeySet<String>()

        // Cooldown applied after a failed server fetch for a specific month so the
        // 30-minute widget update cycle doesn't retry a permanently-failing request
        // (e.g. expired auth token) on every tick.
        private const val FETCH_FAIL_COOLDOWN_MS = 15 * 60 * 1000L  // 15 minutes
        private const val PREF_KEY_FETCH_FAIL_PREFIX = "widgetFetchFail_"

        // Standalone holiday text color (theme-independent, 0xFFD32F2F).
        private val HOLIDAY_RED: Int = 0xFFD32F2F.toInt()
    }

    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun launchCalendarIntent(context: Context): PendingIntent {
        return HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("hmlove://calendar")
        )
    }

    private fun navPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, HMLoveCalendarWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun settingsPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, CalendarWidgetSettingsActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return PendingIntent.getActivity(
            context, 10, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Apply user-chosen background color/alpha to the widget root.
     *
     * If the user hasn't set a custom color, leave the default gradient drawable
     * (declared in widget_calendar.xml) untouched. Otherwise swap to a tintable
     * rounded-rect drawable and tint it via setBackgroundTintList on API 31+.
     * On older APIs we fall back to setBackgroundColor — corners are lost, but
     * the color is honored.
     */
    private fun applyCustomBackground(
        views: RemoteViews,
        prefs: SharedPreferences
    ): Int? {
        if (!prefs.contains(CalendarWidgetSettingsActivity.PREF_KEY_BG_ARGB)) return null
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
        return argb
    }

    private fun selectedTheme(
        prefs: SharedPreferences,
        bgArgb: Int?
    ): CalendarWidgetThemeOption {
        val savedThemeId = prefs.getString(CalendarWidgetSettingsActivity.PREF_KEY_THEME_ID, null)
        if (!savedThemeId.isNullOrEmpty()) {
            return CalendarWidgetSettingsActivity.themeFor(savedThemeId)
        }
        if (bgArgb != null) {
            val bgRgb = (bgArgb and 0x00FFFFFF) or 0xFF000000.toInt()
            return CalendarWidgetSettingsActivity.THEMES.minByOrNull {
                colorDistance(bgRgb, it.bgRgb)
            } ?: CalendarWidgetSettingsActivity.THEMES.first()
        }
        return CalendarWidgetSettingsActivity.THEMES.first()
    }

    private fun colorDistance(a: Int, b: Int): Int {
        val dr = Color.red(a) - Color.red(b)
        val dg = Color.green(a) - Color.green(b)
        val db = Color.blue(a) - Color.blue(b)
        return dr * dr + dg * dg + db * db
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        (alpha.coerceIn(0, 255) shl 24) or (color and 0x00FFFFFF)

    private fun tintBackground(
        views: RemoteViews,
        viewId: Int,
        drawableId: Int,
        color: Int
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setInt(viewId, "setBackgroundResource", drawableId)
            views.setColorStateList(
                viewId,
                "setBackgroundTintList",
                ColorStateList.valueOf(color)
            )
        }
    }

    private fun applyTheme(
        views: RemoteViews,
        theme: CalendarWidgetThemeOption
    ) {
        views.setTextColor(R.id.cal_couple_names, theme.primary)
        views.setTextColor(R.id.cal_dday_info, theme.primary)
        views.setTextColor(R.id.cal_settings_btn, theme.primary)
        views.setTextColor(R.id.cal_prev_month, theme.primary)
        views.setTextColor(R.id.cal_today_month, theme.primary)
        views.setTextColor(R.id.cal_next_month, theme.primary)
        views.setTextColor(R.id.cal_month_title, theme.textPrimary)

        val weekdayIds = intArrayOf(
            R.id.cal_weekday_sun,
            R.id.cal_weekday_mon,
            R.id.cal_weekday_tue,
            R.id.cal_weekday_wed,
            R.id.cal_weekday_thu,
            R.id.cal_weekday_fri,
            R.id.cal_weekday_sat
        )
        for ((index, id) in weekdayIds.withIndex()) {
            views.setTextColor(id, if (index == 0) theme.primary else theme.textSecondary)
        }

        val navBg = withAlpha(theme.primary, 26)
        tintBackground(views, R.id.cal_settings_btn, R.drawable.widget_calendar_nav_btn_bg, navBg)
        tintBackground(views, R.id.cal_prev_month, R.drawable.widget_calendar_nav_btn_bg, navBg)
        tintBackground(views, R.id.cal_today_month, R.drawable.widget_calendar_nav_btn_bg, navBg)
        tintBackground(views, R.id.cal_next_month, R.drawable.widget_calendar_nav_btn_bg, navBg)
    }

    private fun hasWidgetSession(prefs: SharedPreferences): Boolean {
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

    /**
     * Parse an events-JSON string (the widget's serialized event blob) and
     * accumulate the decoded events into [into], keyed by `yyyy-MM-dd` date.
     * Used to merge server events and device events from separate keys into
     * a single per-date map at render time.
     */
    private fun parseEventsInto(
        json: String,
        into: MutableMap<String, MutableList<WidgetEventInfo>>
    ) {
        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val date = obj.getString("date").take(10)
                val title = obj.optString("title", "")
                val color = obj.optString("color", "#E91E63")
                val isAnniversary = obj.optBoolean("isAnniversary", false)
                val eventType = obj.optString("eventType", "schedule")
                into.getOrPut(date) { mutableListOf() }.add(
                    WidgetEventInfo(title, color, isAnniversary, eventType)
                )
            }
        } catch (_: Exception) {
            // Malformed JSON is non-fatal — skip the blob.
        }
    }

    /**
     * Extract just the yyyy-MM-dd dates from a holiday events JSON blob.
     * We only need the dates (to recolor the day number), not the titles.
     */
    private fun parseHolidayDates(json: String?): Set<String> {
        if (json.isNullOrEmpty()) return emptySet()
        return try {
            val arr = JSONArray(json)
            val out = HashSet<String>(arr.length())
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val raw = obj.optString("date", "")
                val prefix = raw.take(10)
                if (prefix.isNotEmpty()) out.add(prefix)
            }
            out
        } catch (_: Exception) {
            emptySet()
        }
    }

    /**
     * Is this month within the post-failure cooldown? Callers should skip the
     * background fetch to avoid hammering the server when auth/network is broken.
     */
    private fun isFetchOnCooldown(prefs: SharedPreferences, yearMonth: String): Boolean {
        val lastFail = prefs.getLong(PREF_KEY_FETCH_FAIL_PREFIX + yearMonth, 0L)
        if (lastFail == 0L) return false
        return System.currentTimeMillis() - lastFail < FETCH_FAIL_COOLDOWN_MS
    }

    private fun trackCachedMonth(
        prefs: SharedPreferences,
        storageKey: String,
        yearMonth: String
    ) {
        try {
            val existing = prefs.getString(storageKey, null)
            val months = mutableSetOf<String>()
            if (!existing.isNullOrEmpty()) {
                val arr = JSONArray(existing)
                for (i in 0 until arr.length()) {
                    val value = arr.optString(i, "")
                    if (value.isNotEmpty()) months.add(value)
                }
            }
            if (months.add(yearMonth)) {
                val sorted = months.toMutableList().sorted()
                prefs.edit()
                    .putString(storageKey, JSONArray(sorted).toString())
                    .apply()
            }
        } catch (_: Exception) {
            prefs.edit()
                .putString(storageKey, JSONArray(listOf(yearMonth)).toString())
                .apply()
        }
    }

    /**
     * Background fetch of a month's events from the server when it isn't in the
     * per-month cache. Re-runs onUpdate on the main thread once events are saved
     * so the widget re-renders with the fetched data. On failure, stamps a
     * cooldown marker so subsequent 30-minute update ticks don't re-hammer a
     * permanently-failing request.
     */
    private fun fetchMonthFromServer(context: Context, yearMonth: String) {
        if (!inFlightFetches.add(yearMonth)) return  // Already fetching this month
        val appContext = context.applicationContext

        Thread {
            var conn: HttpURLConnection? = null
            var succeeded = false
            try {
                val prefs = HomeWidgetPlugin.getData(appContext)
                val token = prefs.getString("authToken", "") ?: ""
                val baseUrl = (prefs.getString("apiBaseUrl", "") ?: "").trimEnd('/')
                if (token.isEmpty() || baseUrl.isEmpty()) {
                    // Not a server failure — user simply isn't logged in.
                    // Don't stamp a cooldown; let it retry when creds appear.
                    succeeded = true
                    return@Thread
                }

                val url = URL("$baseUrl/calendar/$yearMonth")
                conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Authorization", "Bearer $token")
                    setRequestProperty("Accept", "application/json")
                    connectTimeout = 10000
                    readTimeout = 10000
                }
                if (conn.responseCode !in 200..299) return@Thread

                val body = conn.inputStream.bufferedReader().use { it.readText() }
                val json = JSONObject(body)
                val eventsArr = json.optJSONArray("events") ?: JSONArray()

                // Filter out _auto events (generated anniversaries) — widget renders
                // explicit events only, matching Dart's _updateWidgetCalendarEvents.
                val filtered = JSONArray()
                for (i in 0 until eventsArr.length()) {
                    val ev = eventsArr.optJSONObject(i) ?: continue
                    if (ev.optBoolean("_auto", false)) continue
                    filtered.put(ev)
                }

                prefs.edit()
                    .putString("calendarEvents_$yearMonth", filtered.toString())
                    .remove(PREF_KEY_FETCH_FAIL_PREFIX + yearMonth)
                    .apply()
                trackCachedMonth(prefs, PREF_KEY_CALENDAR_EVENT_MONTHS, yearMonth)
                succeeded = true

                // Re-render on main thread.
                Handler(Looper.getMainLooper()).post {
                    try {
                        val appWidgetManager = AppWidgetManager.getInstance(appContext)
                        val ids = appWidgetManager.getAppWidgetIds(
                            ComponentName(appContext, HMLoveCalendarWidgetProvider::class.java)
                        )
                        if (ids.isNotEmpty()) {
                            onUpdate(appContext, appWidgetManager, ids)
                        }
                    } catch (_: Exception) {}
                }
            } catch (_: Exception) {
                // Swallow — cooldown below prevents hammering on permanent failures.
            } finally {
                try { conn?.disconnect() } catch (_: Exception) {}
                if (!succeeded) {
                    try {
                        HomeWidgetPlugin.getData(appContext)
                            .edit()
                            .putLong(PREF_KEY_FETCH_FAIL_PREFIX + yearMonth, System.currentTimeMillis())
                            .apply()
                    } catch (_: Exception) {}
                }
                inFlightFetches.remove(yearMonth)
            }
        }.start()
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PREV_MONTH, ACTION_NEXT_MONTH, ACTION_TODAY_MONTH -> {
                try {
                    val prefs = HomeWidgetPlugin.getData(context)
                    val currentMonth = YearMonth.now()
                    val cached = prefs.getString("calendarYearMonth", "") ?: ""
                    val base = if (cached.isNotEmpty()) {
                        try {
                            YearMonth.parse(cached, MONTH_FORMATTER)
                        } catch (_: Exception) {
                            currentMonth
                        }
                    } else {
                        currentMonth
                    }
                    val newMonth = when (intent.action) {
                        ACTION_PREV_MONTH -> base.minusMonths(1)
                        ACTION_NEXT_MONTH -> base.plusMonths(1)
                        else -> currentMonth
                    }
                    // Explicit user navigation bypasses the fetch cooldown — the
                    // user is asking for that month's data right now.
                    prefs.edit()
                        .putString("calendarYearMonth", newMonth.format(MONTH_FORMATTER))
                        .remove(PREF_KEY_FETCH_FAIL_PREFIX + newMonth.format(MONTH_FORMATTER))
                        .apply()

                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val ids = appWidgetManager.getAppWidgetIds(
                        ComponentName(context, HMLoveCalendarWidgetProvider::class.java)
                    )
                    if (ids.isNotEmpty()) {
                        onUpdate(context, appWidgetManager, ids)
                    }
                } catch (_: Exception) {
                    // Swallow — widget will retry on next update cycle
                }
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                val prefs = HomeWidgetPlugin.getData(context)
                val isConnected = hasWidgetSession(prefs)

                if (!isConnected) {
                    val views = buildNotConnectedWidgetViews(context, prefs, launchAppIntent(context))
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                    continue
                }

                val views = RemoteViews(context.packageName, R.layout.widget_calendar)
                views.setOnClickPendingIntent(R.id.widget_root, launchCalendarIntent(context))

                // Month navigation buttons
                views.setOnClickPendingIntent(
                    R.id.cal_prev_month,
                    navPendingIntent(context, ACTION_PREV_MONTH, 1)
                )
                views.setOnClickPendingIntent(
                    R.id.cal_today_month,
                    navPendingIntent(context, ACTION_TODAY_MONTH, 2)
                )
                views.setOnClickPendingIntent(
                    R.id.cal_next_month,
                    navPendingIntent(context, ACTION_NEXT_MONTH, 3)
                )

                // Settings button (background color / alpha)
                views.setOnClickPendingIntent(
                    R.id.cal_settings_btn,
                    settingsPendingIntent(context)
                )

                // Apply custom background alpha only to the widget root, then
                // apply the paired text/accent colors from the selected theme.
                val theme = try {
                    val bgArgb = applyCustomBackground(views, prefs)
                    selectedTheme(prefs, bgArgb)
                } catch (_: Exception) {
                    CalendarWidgetSettingsActivity.THEMES.first()
                }
                applyTheme(views, theme)

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
                // Widget owns its own month state via prev/next/today buttons.
                // Dart pushes events for whatever month it fetches into `calendarEvents_{ym}`.
                val calendarYearMonth = prefs.getString("calendarYearMonth", "") ?: ""
                val currentMonth = YearMonth.now()
                val displayMonth = if (calendarYearMonth.isNotEmpty()) {
                    try {
                        YearMonth.parse(calendarYearMonth, MONTH_FORMATTER)
                    } catch (_: Exception) {
                        currentMonth
                    }
                } else {
                    currentMonth
                }

                views.setTextViewText(R.id.cal_month_title, "${displayMonth.year}년 ${displayMonth.monthValue}월")

                // Parse calendar events for the displayed month.
                // Prefer per-month cache; fall back to the generic blob (legacy).
                val displayMonthKey = displayMonth.format(MONTH_FORMATTER)
                val perMonthJson = prefs.getString("calendarEvents_$displayMonthKey", null)
                val eventsJson = perMonthJson
                    ?: if (displayMonth == currentMonth) {
                        prefs.getString("calendarEvents", "[]") ?: "[]"
                    } else {
                        "[]"
                    }

                // Trigger a native server fetch in the background if this month
                // has never been cached AND we aren't inside a post-failure cooldown.
                // Widget renders immediately with whatever is available now, and
                // re-renders once the fetch completes.
                if (perMonthJson == null && !isFetchOnCooldown(prefs, displayMonthKey)) {
                    fetchMonthFromServer(context, displayMonthKey)
                }
                val eventDates = mutableMapOf<String, MutableList<WidgetEventInfo>>()
                parseEventsInto(eventsJson, eventDates)

                // Merge device calendar overlay, if the user has device sync
                // enabled. These events live under a separate per-month key so
                // a server-side fetch doesn't accidentally wipe them.
                val deviceCalendarEnabled = prefs.getBoolean("deviceCalendarEnabled", false)
                if (deviceCalendarEnabled) {
                    val deviceJson = prefs.getString(
                        "deviceCalendarEvents_$displayMonthKey",
                        null
                    )
                    if (deviceJson != null) {
                        parseEventsInto(deviceJson, eventDates)
                    }
                }

                // Sort each date's events by priority (anniversary → schedule →
                // device → feed) now that server + device events are combined.
                for ((_, list) in eventDates) {
                    list.sortBy { it.sortPriority }
                }

                // Auto-detected OS holidays (separate toggle). We only need the
                // dates — they recolor the day number red without adding chips.
                val holidayEnabled = prefs.getBoolean("holidayOverlayEnabled", false)
                val holidayDates: Set<String> = if (holidayEnabled) {
                    parseHolidayDates(prefs.getString("holidayEvents_$displayMonthKey", null))
                } else {
                    emptySet()
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

                    val isHoliday = isCurrentMonth && holidayDates.contains(dateStr)

                    if (isToday) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            cellView.setInt(
                                R.id.cell_day,
                                "setBackgroundResource",
                                R.drawable.widget_calendar_today_bg
                            )
                            cellView.setColorStateList(
                                R.id.cell_day,
                                "setBackgroundTintList",
                                ColorStateList.valueOf(theme.primary)
                            )
                        } else {
                            cellView.setInt(R.id.cell_day, "setBackgroundResource", R.drawable.widget_calendar_today_bg)
                        }
                        cellView.setTextColor(R.id.cell_day, Color.WHITE)
                    } else if (!isCurrentMonth) {
                        cellView.setTextColor(R.id.cell_day, withAlpha(theme.textSecondary, 130))
                    } else if (isHoliday) {
                        cellView.setTextColor(R.id.cell_day, HOLIDAY_RED)
                    } else if (col == 0) {
                        cellView.setTextColor(R.id.cell_day, theme.primary)
                    } else {
                        cellView.setTextColor(R.id.cell_day, theme.textPrimary)
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
                val prefs = HomeWidgetPlugin.getData(context)
                val views = buildNotConnectedWidgetViews(context, prefs, launchAppIntent(context))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}
