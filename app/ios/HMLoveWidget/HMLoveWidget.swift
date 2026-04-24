//
//  HMLoveWidget.swift
//  HMLoveWidget
//
//  Created by 김미진 on 2/26/26.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Calendar Month Navigation Intents (iOS 17+)

private let calendarAppGroupId = "group.com.jiny.hmlove"
private let calendarMonthKey = "calendarYearMonth"
private let calendarEventMonthsKey = "widgetCalendarEventMonths"

struct CalendarWidgetTheme {
    let id: String
    let backgroundHex: String
    let primaryHex: String
    let textPrimaryHex: String
    let textSecondaryHex: String

    static let themes: [CalendarWidgetTheme] = [
        CalendarWidgetTheme(id: "blush", backgroundHex: "FFF5F8", primaryHex: "E91E63", textPrimaryHex: "424242", textSecondaryHex: "8E6B75"),
        CalendarWidgetTheme(id: "clean", backgroundHex: "FFFFFF", primaryHex: "E91E63", textPrimaryHex: "303030", textSecondaryHex: "757575"),
        CalendarWidgetTheme(id: "charcoal", backgroundHex: "242124", primaryHex: "FF7AA8", textPrimaryHex: "FFF7FA", textSecondaryHex: "E9B8C8"),
        CalendarWidgetTheme(id: "mint", backgroundHex: "F0FFF8", primaryHex: "00856F", textPrimaryHex: "20302B", textSecondaryHex: "53766B"),
        CalendarWidgetTheme(id: "sky", backgroundHex: "F3FAFF", primaryHex: "1D6FD6", textPrimaryHex: "25313D", textSecondaryHex: "5D728A"),
        CalendarWidgetTheme(id: "mono", backgroundHex: "F6F6F6", primaryHex: "555555", textPrimaryHex: "252525", textSecondaryHex: "6D6D6D")
    ]

    static let defaultTheme = themes[0]

    static func theme(for id: String?) -> CalendarWidgetTheme {
        themes.first { $0.id == id } ?? defaultTheme
    }
}

@available(iOS 17.0, *)
enum WidgetThemeOption: String, AppEnum {
    case blush
    case clean
    case charcoal
    case mint
    case sky
    case mono

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "테마")
    static var caseDisplayRepresentations: [WidgetThemeOption: DisplayRepresentation] = [
        .blush: DisplayRepresentation(title: "러브"),
        .clean: DisplayRepresentation(title: "화이트"),
        .charcoal: DisplayRepresentation(title: "차콜"),
        .mint: DisplayRepresentation(title: "민트"),
        .sky: DisplayRepresentation(title: "스카이"),
        .mono: DisplayRepresentation(title: "모노"),
    ]
}

@available(iOS 17.0, *)
struct HMLoveWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "위젯 설정"
    static var description = IntentDescription("우리연애 위젯 테마를 선택합니다.")

    @Parameter(title: "테마")
    var theme: WidgetThemeOption?
}

@available(iOS 16.0, *)
private func calendarMonthFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    return formatter
}

@available(iOS 16.0, *)
private func shiftCalendarWidgetMonth(by months: Int) {
    guard let defaults = UserDefaults(suiteName: calendarAppGroupId) else { return }
    let formatter = calendarMonthFormatter()
    let cached = defaults.string(forKey: calendarMonthKey) ?? ""
    let base = cached.isEmpty ? Date() : (formatter.date(from: cached) ?? Date())
    let calendar = Calendar(identifier: .gregorian)
    guard let newDate = calendar.date(byAdding: .month, value: months, to: base) else { return }
    defaults.set(formatter.string(from: newDate), forKey: calendarMonthKey)
}

@available(iOS 16.0, *)
private func resetCalendarWidgetMonthToToday() {
    guard let defaults = UserDefaults(suiteName: calendarAppGroupId) else { return }
    defaults.set(calendarMonthFormatter().string(from: Date()), forKey: calendarMonthKey)
}

private func trackCachedMonth(defaults: UserDefaults, storageKey: String, yearMonth: String) {
    let existing = defaults.string(forKey: storageKey) ?? ""
    let data = existing.data(using: .utf8)
    let decoded = (data.flatMap {
        try? JSONSerialization.jsonObject(with: $0) as? [String]
    }) ?? []
    var months = Set(decoded.filter { !$0.isEmpty })
    if months.insert(yearMonth).inserted {
        let sorted = months.sorted()
        if let jsonData = try? JSONSerialization.data(withJSONObject: sorted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            defaults.set(jsonString, forKey: storageKey)
        }
    }
}

@available(iOS 17.0, *)
struct PrevMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "이전 달"
    static var description = IntentDescription("캘린더 위젯에서 이전 달로 이동합니다.")

    func perform() async throws -> some IntentResult {
        shiftCalendarWidgetMonth(by: -1)
        WidgetCenter.shared.reloadTimelines(ofKind: "HMLoveWidget")
        return .result()
    }
}

@available(iOS 17.0, *)
struct NextMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "다음 달"
    static var description = IntentDescription("캘린더 위젯에서 다음 달로 이동합니다.")

    func perform() async throws -> some IntentResult {
        shiftCalendarWidgetMonth(by: 1)
        WidgetCenter.shared.reloadTimelines(ofKind: "HMLoveWidget")
        return .result()
    }
}

@available(iOS 17.0, *)
struct TodayMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "이번 달"
    static var description = IntentDescription("캘린더 위젯에서 오늘이 포함된 달로 이동합니다.")

    func perform() async throws -> some IntentResult {
        resetCalendarWidgetMonthToToday()
        WidgetCenter.shared.reloadTimelines(ofKind: "HMLoveWidget")
        return .result()
    }
}

// MARK: - Data

struct CalendarEventData {
    let date: Date
    let title: String
    let color: String
    let isAnniversary: Bool
    let eventType: String // "schedule", "anniversary", "feed"

    var sortPriority: Int {
        if isAnniversary { return 0 }
        switch eventType {
        case "schedule": return 1
        case "device": return 2
        default: return 3 // feed, etc.
        }
    }

    static func defaultColor(eventType: String, isAnniversary: Bool) -> String {
        if isAnniversary { return "#E91E63" }
        switch eventType {
        case "schedule": return "#1976D2"
        case "device": return "#4CAF50"
        case "feed": return "#FF9800"
        default: return "#E91E63"
        }
    }
}

struct CoupleData {
    let isConnected: Bool
    let myName: String
    let partnerName: String
    let daysTogether: Int
    let startDate: String
    let nextAnniversaryName: String?
    let nextAnniversaryDaysLeft: Int?
    let myMoodEmoji: String
    let partnerMoodEmoji: String
    let todaySchedule: String
    let calendarEvents: [CalendarEventData]
    let calendarYearMonth: String
    let calendarTheme: CalendarWidgetTheme
    /// yyyy-MM-dd strings for dates the OS flagged as holidays.
    /// Empty when the user has disabled the holiday overlay.
    let holidayDates: Set<String>

    static let placeholder = CoupleData(
        isConnected: true,
        myName: "나",
        partnerName: "상대방",
        daysTogether: 365,
        startDate: "2025.02.26",
        nextAnniversaryName: "500일",
        nextAnniversaryDaysLeft: 135,
        myMoodEmoji: "🥰",
        partnerMoodEmoji: "😊",
        todaySchedule: "데이트 약속",
        calendarEvents: [],
        calendarYearMonth: "",
        calendarTheme: .defaultTheme,
        holidayDates: []
    )

    static let notConnected = CoupleData(
        isConnected: false,
        myName: "", partnerName: "",
        daysTogether: 0, startDate: "",
        nextAnniversaryName: nil, nextAnniversaryDaysLeft: nil,
        myMoodEmoji: "", partnerMoodEmoji: "",
        todaySchedule: "",
        calendarEvents: [],
        calendarYearMonth: "",
        calendarTheme: .defaultTheme,
        holidayDates: []
    )
}

// MARK: - Timeline

struct CoupleEntry: TimelineEntry {
    let date: Date
    let data: CoupleData
}

@available(iOS 17.0, *)
struct CoupleTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = HMLoveWidgetConfigurationIntent
    let appGroupId = "group.com.jiny.hmlove"

    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: Date(), data: .placeholder)
    }

    func snapshot(for configuration: HMLoveWidgetConfigurationIntent, in context: Context) async -> CoupleEntry {
        CoupleEntry(date: Date(), data: loadData(configuration: configuration))
    }

    func timeline(for configuration: HMLoveWidgetConfigurationIntent, in context: Context) async -> Timeline<CoupleEntry> {
        await withCheckedContinuation { continuation in
            fetchFromServer(configuration: configuration) { serverData in
            let data = serverData ?? self.loadData(configuration: configuration)
            let now = Date()
            let calendar = Calendar.current

            // Create entry for now
            let currentEntry = CoupleEntry(date: now, data: data)

            // Schedule next update at midnight so D-Day rolls over
            var nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
            // Also refresh every 30 minutes for mood/schedule updates
            let next30Min = calendar.date(byAdding: .minute, value: 30, to: now)!
            let nextUpdate = min(nextMidnight, next30Min)

            // If midnight is within 30 min, create an entry for midnight with recalculated data
            var entries = [currentEntry]
            if nextMidnight.timeIntervalSince(now) < 30 * 60 {
                let midnightData = self.loadData(configuration: configuration)
                entries.append(CoupleEntry(date: nextMidnight, data: midnightData))
                // After midnight entry, schedule next refresh 30 min later
                nextMidnight = calendar.date(byAdding: .minute, value: 30, to: nextMidnight)!
            }

            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
                continuation.resume(returning: timeline)
            }
        }
    }

    private func fetchFromServer(
        configuration: HMLoveWidgetConfigurationIntent,
        completion: @escaping (CoupleData?) -> Void
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let token = defaults.string(forKey: "authToken"),
              let baseUrl = defaults.string(forKey: "apiBaseUrl"),
              !token.isEmpty else {
            completion(nil)
            return
        }

        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        // Fetch the month currently displayed in the widget (may differ from
        // the real current month due to user navigation via prev/next buttons).
        let displayedYearMonth: String = {
            let cached = defaults.string(forKey: "calendarYearMonth") ?? ""
            if !cached.isEmpty, formatter.date(from: cached) != nil {
                return cached
            }
            return formatter.string(from: now)
        }()
        let yearMonth = displayedYearMonth
        let currentYearMonth = formatter.string(from: now)

        guard let url = URL(string: "\(baseUrl)/calendar/\(yearMonth)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let events = json["events"] as? [[String: Any]] else {
                completion(nil)
                return
            }

            // Find today's events (only meaningful when fetching the current month)
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.calendar = Calendar(identifier: .gregorian)
            let todayStr = dayFormatter.string(from: now)

            if yearMonth == currentYearMonth {
                let todayEvents = events.filter { event in
                    guard let dateStr = event["date"] as? String else { return false }
                    return dateStr.hasPrefix(todayStr)
                }

                let titles = todayEvents.compactMap { $0["title"] as? String }
                let schedule = Array(titles.prefix(3)).map { "• \($0)" }.joined(separator: "\n")
                defaults.set(schedule, forKey: "todaySchedule")
            }

            // Save calendar events for large widget (filter out auto events only).
            // Cache per-month so navigation (prev/next) can render without re-fetching.
            let widgetEvents = events.filter { event in
                let isAuto = event["_auto"] as? Bool ?? false
                return !isAuto
            }
            if let eventsJsonData = try? JSONSerialization.data(withJSONObject: widgetEvents),
               let jsonString = String(data: eventsJsonData, encoding: .utf8) {
                defaults.set(jsonString, forKey: "calendarEvents_\(yearMonth)")
                trackCachedMonth(
                    defaults: defaults,
                    storageKey: calendarEventMonthsKey,
                    yearMonth: yearMonth
                )
                if yearMonth == currentYearMonth {
                    // Preserve legacy key for backwards compat
                    defaults.set(jsonString, forKey: "calendarEvents")
                }
            }

            // Also update mood from server
            if let moods = json["moods"] as? [String: Any],
               let todayMoods = moods[todayStr] as? [[String: Any]] {
                for mood in todayMoods {
                    if let emoji = mood["emoji"] as? String {
                        let moodEmoji = Self.moodToEmoji(emoji)
                        // Just update first mood found (could be improved)
                        if defaults.string(forKey: "myMoodEmoji") == "😶" || defaults.string(forKey: "myMoodEmoji") == nil {
                            defaults.set(moodEmoji, forKey: "myMoodEmoji")
                        }
                    }
                }
            }

            completion(self.loadData(configuration: configuration))
        }.resume()
    }

    private static func moodToEmoji(_ key: String) -> String {
        let map: [String: String] = [
            "happy": "😊", "love": "🥰", "excited": "🤩",
            "grateful": "🙏", "peaceful": "😌", "proud": "😎",
            "missing": "🥺", "bored": "😐", "sad": "😢",
            "angry": "😤", "tired": "😴", "stressed": "😩"
        ]
        return map[key] ?? "😶"
    }

    private func loadData(configuration: HMLoveWidgetConfigurationIntent) -> CoupleData {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return .notConnected
        }

        let isConnected = defaults.bool(forKey: "isConnected")
        if !isConnected {
            return .notConnected
        }

        let startDateStr = defaults.string(forKey: "startDate") ?? ""

        // Calculate daysTogether from startDate so it updates even without opening the app
        let daysTogether: Int
        let nextAnniversaryName: String?
        let nextAnniversaryDaysLeft: Int?

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        if let startDate = formatter.date(from: startDateStr) {
            let calendar = Calendar.current
            let now = Date()
            daysTogether = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: now)).day! + 1

            // Calculate next anniversary
            let result = Self.calcNextAnniversary(startDate: startDate, now: now)
            nextAnniversaryName = result?.name
            nextAnniversaryDaysLeft = result?.daysLeft
        } else {
            // Fallback to stored values if date parsing fails
            daysTogether = defaults.integer(forKey: "daysTogether")
            nextAnniversaryName = defaults.string(forKey: "nextAnniversaryName")
            nextAnniversaryDaysLeft = defaults.object(forKey: "nextAnniversaryDaysLeft") as? Int
        }

        // Parse calendar events for the currently displayed month.
        // Prefer per-month cache (calendarEvents_{ym}); fall back to legacy blob.
        let calendarYearMonth = defaults.string(forKey: "calendarYearMonth") ?? ""
        let perMonthEventsJson: String? = {
            if !calendarYearMonth.isEmpty {
                return defaults.string(forKey: "calendarEvents_\(calendarYearMonth)")
            }
            return nil
        }()
        let resolvedEventsJson = perMonthEventsJson ?? defaults.string(forKey: "calendarEvents")
        var calendarEvents: [CalendarEventData] =
            Self.parseWidgetEvents(resolvedEventsJson)

        // Merge device calendar overlay, if the user has device sync enabled.
        // Device events live under a separate per-month key so a server-side
        // timeline refresh doesn't accidentally wipe them.
        let deviceCalendarEnabled = defaults.bool(forKey: "deviceCalendarEnabled")
        if deviceCalendarEnabled && !calendarYearMonth.isEmpty {
            let deviceJson = defaults.string(
                forKey: "deviceCalendarEvents_\(calendarYearMonth)"
            )
            calendarEvents.append(contentsOf: Self.parseWidgetEvents(deviceJson))
        }

        // Auto-detected OS holiday overlay (separate toggle). Loaded as a
        // date Set so we can recolor matching day numbers without cluttering
        // the event chip list.
        var holidayDates: Set<String> = []
        let holidayEnabled = defaults.bool(forKey: "holidayOverlayEnabled")
        if holidayEnabled && !calendarYearMonth.isEmpty {
            let holidayJson = defaults.string(
                forKey: "holidayEvents_\(calendarYearMonth)"
            )
            holidayDates = Self.parseHolidayDates(holidayJson)
        }

        return CoupleData(
            isConnected: true,
            myName: defaults.string(forKey: "myName") ?? "나",
            partnerName: defaults.string(forKey: "partnerName") ?? "상대방",
            daysTogether: daysTogether,
            startDate: startDateStr,
            nextAnniversaryName: nextAnniversaryName,
            nextAnniversaryDaysLeft: nextAnniversaryDaysLeft,
            myMoodEmoji: defaults.string(forKey: "myMoodEmoji") ?? "😶",
            partnerMoodEmoji: defaults.string(forKey: "partnerMoodEmoji") ?? "😶",
            todaySchedule: defaults.string(forKey: "todaySchedule") ?? "",
            calendarEvents: calendarEvents,
            calendarYearMonth: calendarYearMonth,
            calendarTheme: CalendarWidgetTheme.theme(
                for: configuration.theme?.rawValue
            ),
            holidayDates: holidayDates
        )
    }

    private static func parseHolidayDates(_ json: String?) -> Set<String> {
        guard let json = json,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else {
            return []
        }
        var dates: Set<String> = []
        for dict in array {
            guard let raw = dict["date"] as? String else { continue }
            let prefix = String(raw.prefix(10))
            if !prefix.isEmpty { dates.insert(prefix) }
        }
        return dates
    }

    private func loadData() -> CoupleData {
        loadData(configuration: HMLoveWidgetConfigurationIntent())
    }

    /// Decode the widget-serialized event JSON blob into [CalendarEventData].
    /// Used for both the server events blob and the device-calendar overlay
    /// so the two can share a single parser.
    private static func parseWidgetEvents(_ json: String?) -> [CalendarEventData] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data)
                as? [[String: Any]] else {
            return []
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFrac = ISO8601DateFormatter()
        isoFormatterNoFrac.formatOptions = [.withInternetDateTime]
        return array.compactMap { dict in
            guard let dateStr = dict["date"] as? String,
                  let title = dict["title"] as? String else { return nil }
            let date = dateFormatter.date(from: String(dateStr.prefix(10)))
                ?? isoFormatter.date(from: dateStr)
                ?? isoFormatterNoFrac.date(from: dateStr)
            guard let parsedDate = date else { return nil }
            let isAnniversary = dict["isAnniversary"] as? Bool ?? false
            let eventType = dict["eventType"] as? String ?? "schedule"
            let rawColor = (dict["color"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let color = (rawColor?.isEmpty == false ? rawColor! : nil)
                ?? CalendarEventData.defaultColor(
                    eventType: eventType,
                    isAnniversary: isAnniversary
                )
            return CalendarEventData(
                date: parsedDate,
                title: title,
                color: color,
                isAnniversary: isAnniversary,
                eventType: eventType
            )
        }
    }

    /// Calculate next anniversary from start date (matches Dart logic)
    private static func calcNextAnniversary(startDate: Date, now: Date) -> (name: String, daysLeft: Int)? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // Check predefined milestones first
        let milestones = [100, 200, 300, 365, 500, 700, 730, 1000, 1095, 1461]
        for days in milestones {
            guard let date = calendar.date(byAdding: .day, value: days - 1, to: startDate) else { continue }
            let milestoneDay = calendar.startOfDay(for: date)
            if milestoneDay > today {
                let daysLeft = calendar.dateComponents([.day], from: today, to: milestoneDay).day ?? 0
                return (name: "\(days)일", daysLeft: daysLeft)
            }
        }

        // Fall back to annual anniversary
        let startComps = calendar.dateComponents([.month, .day], from: startDate)
        var year = calendar.component(.year, from: now) - calendar.component(.year, from: startDate)
        if let thisYearAnniv = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: now),
            month: startComps.month,
            day: startComps.day
        )), calendar.startOfDay(for: thisYearAnniv) <= today {
            year += 1
        }
        if let nextAnniv = calendar.date(from: DateComponents(
            year: calendar.component(.year, from: startDate) + year,
            month: startComps.month,
            day: startComps.day
        )) {
            let daysLeft = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: nextAnniv)).day ?? 0
            return (name: "\(year)주년", daysLeft: daysLeft)
        }

        return nil
    }
}

// MARK: - Small Widget (D-Day)

struct SmallWidgetView: View {
    let data: CoupleData
    private var theme: CalendarWidgetTheme { data.calendarTheme }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(data.myName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: theme.primaryHex))
                Text("♥")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: theme.primaryHex))
                Text(data.partnerName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: theme.primaryHex))
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(data.daysTogether)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: theme.primaryHex))
                Text("일")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: theme.primaryHex))
            }

            Text(data.startDate + " ~")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: theme.primaryHex).opacity(0.6))

            if let name = data.nextAnniversaryName,
               let daysLeft = data.nextAnniversaryDaysLeft {
                HStack(spacing: 3) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: theme.textSecondaryHex))
                    Text("D-\(daysLeft)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: theme.primaryHex))
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget (D-Day + Mood + Schedule)

struct MediumWidgetView: View {
    let data: CoupleData
    private var theme: CalendarWidgetTheme { data.calendarTheme }

    var body: some View {
        HStack(spacing: 0) {
            // Left: D-Day
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(data.myName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("♥")
                        .font(.system(size: 11))
                    Text(data.partnerName)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(hex: theme.primaryHex))

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(data.daysTogether)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: theme.primaryHex))
                    Text("일째")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: theme.primaryHex))
                }

                Text(data.startDate + " ~")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: theme.primaryHex).opacity(0.5))

                if let name = data.nextAnniversaryName,
                   let daysLeft = data.nextAnniversaryDaysLeft {
                    HStack(spacing: 3) {
                        Text("🎉 \(name)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: theme.textSecondaryHex))
                        Text("D-\(daysLeft)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: theme.primaryHex))
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Right: Mood + Schedule
            VStack(spacing: 8) {
                // Mood (compact)
                HStack(spacing: 6) {
                    Text(data.myMoodEmoji)
                        .font(.system(size: 24))
                    Text("♥")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: theme.primaryHex).opacity(0.6))
                    Text(data.partnerMoodEmoji)
                        .font(.system(size: 24))
                }

                // Today's schedule
                if !data.todaySchedule.isEmpty {
                    Text(data.todaySchedule)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: theme.textPrimaryHex))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                } else {
                    Text("오늘 일정 없음")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: theme.textSecondaryHex).opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Large Widget (Calendar)

struct LargeWidgetView: View {
    let data: CoupleData

    private let calendar = Calendar(identifier: .gregorian)
    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private var theme: CalendarWidgetTheme { data.calendarTheme }

    private var displayDate: Date {
        if !data.calendarYearMonth.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            if let date = formatter.date(from: data.calendarYearMonth) {
                return date
            }
        }
        return Date()
    }

    private var yearMonthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: displayDate)
    }

    private var calendarDays: [CalendarDay] {
        let components = calendar.dateComponents([.year, .month], from: displayDate)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1 // 0=Sun

        // Previous month days
        var days: [CalendarDay] = []
        if firstWeekday > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth)!
            let prevRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevLastDay = prevRange.upperBound - 1
            for i in 0..<firstWeekday {
                let day = prevLastDay - firstWeekday + 1 + i
                let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: prevMonth),
                    month: calendar.component(.month, from: prevMonth),
                    day: day
                ))!
                days.append(CalendarDay(day: day, date: date, isCurrentMonth: false))
            }
        }

        // Current month days
        for day in range {
            let date = calendar.date(from: DateComponents(
                year: components.year, month: components.month, day: day
            ))!
            days.append(CalendarDay(day: day, date: date, isCurrentMonth: true))
        }

        // Next month days to fill 6 rows
        let remaining = 42 - days.count
        if remaining > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth)!
            for day in 1...remaining {
                let date = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: nextMonth),
                    month: calendar.component(.month, from: nextMonth),
                    day: day
                ))!
                days.append(CalendarDay(day: day, date: date, isCurrentMonth: false))
            }
        }

        return days
    }

    private func eventsForDate(_ date: Date) -> [CalendarEventData] {
        data.calendarEvents
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.sortPriority < $1.sortPriority }
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private static let holidayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private func isHoliday(_ date: Date) -> Bool {
        guard !data.holidayDates.isEmpty else { return false }
        return data.holidayDates.contains(Self.holidayKeyFormatter.string(from: date))
    }

    @ViewBuilder
    private var monthHeader: some View {
        if #available(iOS 17.0, *) {
            HStack(spacing: 0) {
                Button(intent: PrevMonthIntent()) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: theme.primaryHex))
                        .frame(width: 26, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: theme.primaryHex).opacity(0.1))
                        )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 6)

                Text(yearMonthText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: theme.textPrimaryHex))

                Spacer(minLength: 6)

                Button(intent: TodayMonthIntent()) {
                    Text("오늘")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: theme.primaryHex))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: theme.primaryHex).opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)

                Button(intent: NextMonthIntent()) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: theme.primaryHex))
                        .frame(width: 26, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: theme.primaryHex).opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(yearMonthText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: theme.textPrimaryHex))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: couple name + D-Day
            HStack {
                Text("\(data.myName) ♥ \(data.partnerName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: theme.primaryHex))
                Spacer()
                Text("\(data.daysTogether)일")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: theme.primaryHex))
                if let name = data.nextAnniversaryName,
                   let daysLeft = data.nextAnniversaryDaysLeft {
                    Text("· \(name) D-\(daysLeft)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: theme.textSecondaryHex))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Month header with prev / title / today / next navigation
            monthHeader
                .padding(.horizontal, 10)
                .padding(.bottom, 3)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(index == 0 ? Color(hex: theme.primaryHex) : Color(hex: theme.textSecondaryHex))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)

            // Calendar grid 6x7
            let days = calendarDays
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let index = row * 7 + col
                            if index < days.count {
                                let dayItem = days[index]
                                let dayEvents = dayItem.isCurrentMonth ? Array(eventsForDate(dayItem.date).prefix(5)) : []
                                let today = dayItem.isCurrentMonth && isToday(dayItem.date)
                                let holiday = dayItem.isCurrentMonth && isHoliday(dayItem.date)

                                VStack(spacing: 0) {
                                    ZStack {
                                        if today {
                                            Circle()
                                                .fill(Color(hex: theme.primaryHex))
                                                .frame(width: 14, height: 14)
                                        }
                                        Text("\(dayItem.day)")
                                            .font(.system(size: 10, weight: (today || holiday) ? .bold : .regular))
                                            .foregroundColor(
                                                today ? .white :
                                                !dayItem.isCurrentMonth ? Color(hex: theme.textSecondaryHex).opacity(0.55) :
                                                holiday ? Color(hex: "D32F2F") :
                                                col == 0 ? Color(hex: theme.primaryHex) :
                                                Color(hex: theme.textPrimaryHex)
                                            )
                                    }
                                    .frame(height: 14)

                                    ForEach(Array(dayEvents.enumerated()), id: \.offset) { _, event in
                                        Text(event.title)
                                            .font(.system(size: 6, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .padding(.horizontal, 1)
                                            .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 1.5)
                                                    .fill(Color(hex: event.color.replacingOccurrences(of: "#", with: "")))
                                            )
                                            .clipped()
                                    }

                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }
}

struct CalendarDay {
    let day: Int
    let date: Date
    let isCurrentMonth: Bool
}

// MARK: - Widget Configuration

@available(iOS 17.0, *)
struct HMLoveWidget: Widget {
    let kind: String = "HMLoveWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HMLoveWidgetConfigurationIntent.self,
            provider: CoupleTimelineProvider()
        ) { entry in
            WidgetContentView(entry: entry)
        }
        .configurationDisplayName("우리연애")
        .description("D-Day와 오늘의 기분을 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct WidgetContentView: View {
    let entry: CoupleEntry

    var body: some View {
            if #available(iOS 17.0, *) {
                WidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(hex: entry.data.calendarTheme.backgroundHex)
                    }
            } else {
                WidgetView(entry: entry)
                    .background(Color(hex: entry.data.calendarTheme.backgroundHex))
            }
    }
}

// MARK: - Not Connected View

struct NotConnectedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("💕")
                .font(.system(size: 36))
            Text("우리연애")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "C2185B"))
            Text("앱에서 로그인하고\n커플을 연결해보세요")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "9E9E9E"))
                .multilineTextAlignment(.center)
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CoupleEntry

    var body: some View {
        if !entry.data.isConnected {
            NotConnectedView()
        } else {
            switch family {
            case .systemSmall:
                SmallWidgetView(data: entry.data)
            case .systemMedium:
                MediumWidgetView(data: entry.data)
            case .systemLarge:
                LargeWidgetView(data: entry.data)
                    .widgetURL(URL(string: "hmlove://calendar?homeWidget=true"))
            default:
                MediumWidgetView(data: entry.data)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
