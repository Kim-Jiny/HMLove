//
//  HMLoveWidget.swift
//  HMLoveWidget
//
//  Created by 김미진 on 2/26/26.
//

import WidgetKit
import SwiftUI

// MARK: - Data

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
        todaySchedule: "데이트 약속"
    )

    static let notConnected = CoupleData(
        isConnected: false,
        myName: "", partnerName: "",
        daysTogether: 0, startDate: "",
        nextAnniversaryName: nil, nextAnniversaryDaysLeft: nil,
        myMoodEmoji: "", partnerMoodEmoji: "",
        todaySchedule: ""
    )
}

// MARK: - Timeline

struct CoupleEntry: TimelineEntry {
    let date: Date
    let data: CoupleData
}

struct CoupleTimelineProvider: TimelineProvider {
    let appGroupId = "group.com.jiny.hmlove"

    func placeholder(in context: Context) -> CoupleEntry {
        CoupleEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CoupleEntry) -> Void) {
        completion(CoupleEntry(date: Date(), data: loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleEntry>) -> Void) {
        let localData = loadData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!

        // Try to fetch fresh data from server
        fetchFromServer { serverData in
            let data = serverData ?? localData
            let entry = CoupleEntry(date: Date(), data: data)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func fetchFromServer(completion: @escaping (CoupleData?) -> Void) {
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
        let yearMonth = formatter.string(from: now)

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

            // Find today's events
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            let todayStr = dayFormatter.string(from: now)

            let todayEvents = events.filter { event in
                guard let dateStr = event["date"] as? String else { return false }
                return dateStr.hasPrefix(todayStr)
            }

            let titles = todayEvents.compactMap { $0["title"] as? String }
            let schedule = Array(titles.prefix(3)).map { "• \($0)" }.joined(separator: "\n")

            // Save to UserDefaults so local loadData also has it
            defaults.set(schedule, forKey: "todaySchedule")

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

            completion(self.loadData())
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

    private func loadData() -> CoupleData {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return .notConnected
        }

        let isConnected = defaults.bool(forKey: "isConnected")
        if !isConnected {
            return .notConnected
        }

        return CoupleData(
            isConnected: true,
            myName: defaults.string(forKey: "myName") ?? "나",
            partnerName: defaults.string(forKey: "partnerName") ?? "상대방",
            daysTogether: defaults.integer(forKey: "daysTogether"),
            startDate: defaults.string(forKey: "startDate") ?? "",
            nextAnniversaryName: defaults.string(forKey: "nextAnniversaryName"),
            nextAnniversaryDaysLeft: defaults.object(forKey: "nextAnniversaryDaysLeft") as? Int,
            myMoodEmoji: defaults.string(forKey: "myMoodEmoji") ?? "😶",
            partnerMoodEmoji: defaults.string(forKey: "partnerMoodEmoji") ?? "😶",
            todaySchedule: defaults.string(forKey: "todaySchedule") ?? ""
        )
    }
}

// MARK: - Small Widget (D-Day)

struct SmallWidgetView: View {
    let data: CoupleData

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(data.myName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "E91E63"))
                Text("♥")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "E91E63"))
                Text(data.partnerName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "E91E63"))
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(data.daysTogether)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "C2185B"))
                Text("일")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "E91E63"))
            }

            Text(data.startDate + " ~")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "E91E63").opacity(0.6))

            if let name = data.nextAnniversaryName,
               let daysLeft = data.nextAnniversaryDaysLeft {
                HStack(spacing: 3) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9E9E9E"))
                    Text("D-\(daysLeft)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "E91E63"))
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Medium Widget (D-Day + Mood + Schedule)

struct MediumWidgetView: View {
    let data: CoupleData

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
                .foregroundColor(Color(hex: "E91E63"))

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(data.daysTogether)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "C2185B"))
                    Text("일째")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "E91E63"))
                }

                Text(data.startDate + " ~")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "E91E63").opacity(0.5))

                if let name = data.nextAnniversaryName,
                   let daysLeft = data.nextAnniversaryDaysLeft {
                    HStack(spacing: 3) {
                        Text("🎉 \(name)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "757575"))
                        Text("D-\(daysLeft)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "E91E63"))
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
                        .foregroundColor(Color(hex: "F48FB1"))
                    Text(data.partnerMoodEmoji)
                        .font(.system(size: 24))
                }

                // Today's schedule
                if !data.todaySchedule.isEmpty {
                    Text(data.todaySchedule)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "616161"))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                } else {
                    Text("오늘 일정 없음")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "BDBDBD"))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Widget Configuration

struct HMLoveWidget: Widget {
    let kind: String = "HMLoveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CoupleTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color(hex: "FFE4EC"), Color(hex: "FFF0F5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                WidgetView(entry: entry)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FFE4EC"), Color(hex: "FFF0F5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .configurationDisplayName("우리연애")
        .description("D-Day와 오늘의 기분을 확인하세요")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
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
