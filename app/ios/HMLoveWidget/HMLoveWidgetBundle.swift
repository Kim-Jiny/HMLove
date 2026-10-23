//
//  HMLoveWidgetBundle.swift
//  HMLoveWidget
//
//  Created by 김미진 on 2/26/26.
//

import WidgetKit
import SwiftUI

@main
struct HMLoveWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 17.0, *) {
            HMLoveWidget()
            HMLoveDoodleWidget()
        }
        HMLoveLockWidget()
    }
}

// MARK: - 잠금화면 위젯 (원형 / 직사각형 / 한 줄)

struct LockEntry: TimelineEntry {
    let date: Date
    let connected: Bool
    let names: String
    let days: Int
}

struct LockProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockEntry {
        LockEntry(date: Date(), connected: true, names: "나 ♥ 너", days: 365)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockEntry>) -> Void) {
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
        completion(Timeline(entries: [load()], policy: .after(midnight)))
    }

    private func load() -> LockEntry {
        guard let d = UserDefaults(suiteName: "group.com.jiny.hmlove"),
              d.bool(forKey: "isConnected") else {
            return LockEntry(date: Date(), connected: false, names: "", days: 0)
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        var days = d.integer(forKey: "daysTogether")
        if let start = f.date(from: d.string(forKey: "startDate") ?? "") {
            let cal = Calendar.current
            days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: Date())).day! + 1
        }
        let my = d.string(forKey: "myName") ?? "나"
        let partner = d.string(forKey: "partnerName") ?? "상대방"
        return LockEntry(date: Date(), connected: true, names: "\(my) ♥ \(partner)", days: days)
    }
}

struct LockWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: LockEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill").font(.system(size: 10))
                    Text(entry.connected ? "\(entry.days)" : "-")
                        .font(.system(size: entry.days >= 1000 ? 16 : 20, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                    Text("일").font(.system(size: 9, weight: .bold))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.connected ? entry.names : "우리연애")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(entry.connected ? "D+\(entry.days)" : "앱에서 로그인해 주세요")
                    .font(.system(size: entry.connected ? 24 : 12, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(entry.connected ? "♥ D+\(entry.days)" : "♥ 우리연애")
        }
    }
}

struct HMLoveLockWidget: Widget {
    let kind = "HMLoveLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { entry in
            if #available(iOS 17.0, *) {
                LockWidgetView(entry: entry)
                    .containerBackground(.clear, for: .widget)
                    .widgetURL(URL(string: "hmlove://home?homeWidget=true"))
            } else {
                LockWidgetView(entry: entry)
                    .widgetURL(URL(string: "hmlove://home?homeWidget=true"))
            }
        }
        .configurationDisplayName("우리 D-Day")
        .description("잠금화면에서 함께한 날을 확인하세요")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
