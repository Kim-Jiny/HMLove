//
//  HMLoveDoodleWidget.swift
//  HMLoveWidget
//
//  2x2 그림 위젯 — 상대방이 마지막으로 보낸 그림을 표시.
//

import WidgetKit
import SwiftUI
import ImageIO
import CoreGraphics

private let doodleAppGroupId = "group.com.jiny.hmlove"

private enum DoodlePalette {
    static let background = Color(red: 1.0, green: 245.0 / 255, blue: 248.0 / 255)      // #FFF5F8
    static let accent     = Color(red: 224.0 / 255, green: 122.0 / 255, blue: 95.0 / 255)  // #E07A5F
    static let secondary  = Color(red: 142.0 / 255, green: 107.0 / 255, blue: 117.0 / 255) // #8E6B75
    static let hint       = Color(red: 185.0 / 255, green: 160.0 / 255, blue: 150.0 / 255) // #B9A096
    static let primary    = Color(red: 194.0 / 255, green: 24.0 / 255, blue: 91.0 / 255)   // #C2185B
    static let muted      = Color(red: 158.0 / 255, green: 158.0 / 255, blue: 158.0 / 255) // #9E9E9E
}

// 위젯 디스크 캐시: imageUrl(절대) → 다운로드된 PNG 파일 경로
// App Group 컨테이너에 캐싱해서 위젯 익스텐션이 매번 다시 다운받지 않게 함.
// UIKit를 끌어오지 않기 위해 CGImage 기반으로 로드.
private enum DoodleCache {
    static func cachedImage(for urlString: String) -> CGImage? {
        guard let path = cachePath(for: urlString),
              FileManager.default.fileExists(atPath: path.path),
              let source = CGImageSourceCreateWithURL(path as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return cg
    }

    static func write(_ data: Data, for urlString: String) {
        guard let path = cachePath(for: urlString) else { return }
        try? FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: path)
    }

    private static func cachePath(for urlString: String) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: doodleAppGroupId
        ) else { return nil }
        let folder = container.appendingPathComponent("doodleCache", isDirectory: true)
        let fileName = String(urlString.hashValue) + ".png"
        return folder.appendingPathComponent(fileName)
    }
}

// MARK: - Data

struct DoodleData {
    let imageUrl: String?
    let receivedAt: Date?
    let senderName: String?
    let image: CGImage?
    let isConnected: Bool

    static let placeholder = DoodleData(
        imageUrl: nil,
        receivedAt: Date(),
        senderName: "상대방",
        image: nil as CGImage?,
        isConnected: true
    )

    static let notConnected = DoodleData(
        imageUrl: nil,
        receivedAt: nil,
        senderName: nil,
        image: nil as CGImage?,
        isConnected: false
    )
}

// MARK: - Timeline

struct DoodleEntry: TimelineEntry {
    let date: Date
    let data: DoodleData
}

struct DoodleTimelineProvider: TimelineProvider {
    let appGroupId = doodleAppGroupId

    func placeholder(in context: Context) -> DoodleEntry {
        DoodleEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoodleEntry) -> Void) {
        completion(DoodleEntry(date: Date(), data: loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoodleEntry>) -> Void) {
        fetchImageIfNeeded { _ in
            let data = self.loadData()
            let now = Date()
            // 1시간마다 한 번씩 timeline 갱신. push silent 알림이 즉시 깨우긴 하지만
            // 시간 표시(받은지 N분 전 등)는 주기적으로도 갱신되어야 함.
            let next = Calendar.current.date(byAdding: .minute, value: 60, to: now) ?? now
            let entry = DoodleEntry(date: now, data: data)
            let timeline = Timeline(entries: [entry], policy: .after(next))
            completion(timeline)
        }
    }

    /// 캐시에 없으면 imageUrl에서 PNG를 다운받아 캐시.
    private func fetchImageIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let urlString = defaults.string(forKey: "doodleImageUrl"),
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            completion(false)
            return
        }

        if DoodleCache.cachedImage(for: urlString) != nil {
            completion(true)
            return
        }

        var request = URLRequest(url: url)
        if let token = defaults.string(forKey: "authToken"), !token.isEmpty {
            // Bearer 보호된 URL일 수도, 공개 URL일 수도 있음. 토큰이 있으면 같이 보냄.
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data, !data.isEmpty {
                DoodleCache.write(data, for: urlString)
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    private func loadData() -> DoodleData {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return .notConnected
        }
        let isConnected = defaults.bool(forKey: "isConnected")
        if !isConnected {
            return .notConnected
        }

        let urlString = defaults.string(forKey: "doodleImageUrl")
        let receivedAtStr = defaults.string(forKey: "doodleReceivedAt")
        let senderName = defaults.string(forKey: "doodleSenderName")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterNoFrac = ISO8601DateFormatter()
        formatterNoFrac.formatOptions = [.withInternetDateTime]
        let receivedAt = receivedAtStr.flatMap {
            formatter.date(from: $0) ?? formatterNoFrac.date(from: $0)
        }

        let image: CGImage? = {
            guard let urlString = urlString, !urlString.isEmpty else { return nil }
            return DoodleCache.cachedImage(for: urlString)
        }()

        return DoodleData(
            imageUrl: urlString,
            receivedAt: receivedAt,
            senderName: senderName,
            image: image,
            isConnected: true
        )
    }
}

// MARK: - View

struct DoodleWidgetView: View {
    let entry: DoodleEntry

    var body: some View {
        ZStack {
            if !entry.data.isConnected {
                DoodleNotConnectedView()
            } else if let image = entry.data.image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        // 받은 사람 / 시간 캡션
                        captionOverlay
                    }
            } else if entry.data.imageUrl != nil {
                // URL은 있지만 캐시 미스 (위젯이 첫 fetch 중)
                VStack(spacing: 6) {
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 28))
                        .foregroundColor(DoodlePalette.accent)
                    Text("그림을\n불러오는 중...")
                        .font(.system(size: 12))
                        .foregroundColor(DoodlePalette.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                DoodleEmptyView()
            }
        }
        .widgetURL(URL(string: "hmlove://doodle?homeWidget=true"))
    }

    @ViewBuilder
    private var captionOverlay: some View {
        if let received = entry.data.receivedAt {
            HStack(spacing: 6) {
                Text(entry.data.senderName?.isEmpty == false
                     ? entry.data.senderName!
                     : "상대방")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                Text("·")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.8))
                Text(received, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.black.opacity(0.5))
            )
            .padding(8)
        }
    }
}

struct DoodleEmptyView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 32))
                .foregroundColor(DoodlePalette.accent)
            Text("아직 받은\n그림이 없어요")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DoodlePalette.secondary)
                .multilineTextAlignment(.center)
            Text("앱에서 그림을\n보내달라고 해보세요")
                .font(.system(size: 10))
                .foregroundColor(DoodlePalette.hint)
                .multilineTextAlignment(.center)
        }
    }
}

struct DoodleNotConnectedView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("💕")
                .font(.system(size: 28))
            Text("우리연애")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(DoodlePalette.primary)
            Text("로그인 후\n사용 가능")
                .font(.system(size: 11))
                .foregroundColor(DoodlePalette.muted)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Widget

@available(iOS 17.0, *)
struct HMLoveDoodleWidget: Widget {
    let kind: String = "HMLoveDoodleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DoodleTimelineProvider()) { entry in
            DoodleWidgetContainer(entry: entry)
        }
        .configurationDisplayName("그림 보내기")
        .description("상대방이 보낸 그림을 위젯으로 받아보세요")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct DoodleWidgetContainer: View {
    let entry: DoodleEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            DoodleWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    DoodlePalette.background
                }
        } else {
            DoodleWidgetView(entry: entry)
                .background(DoodlePalette.background)
        }
    }
}
