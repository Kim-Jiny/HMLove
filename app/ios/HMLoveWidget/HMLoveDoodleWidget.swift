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
        let fileName = stableCacheFileName(for: urlString)
        return folder.appendingPathComponent(fileName)
    }

    private static func stableCacheFileName(for text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16) + ".png"
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
        fetchLatestDoodle { _ in
            self.fetchImageIfNeeded { _ in
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
    }

    /// silent push가 timeline만 깨우는 경우에도 위젯 extension이 직접 최신 그림 메타를 받는다.
    /// 401 받으면 한 번 refresh 후 재시도 (token 만료된 상태에서도 위젯 stale 안 되게).
    private func fetchLatestDoodle(completion: @escaping (Bool) -> Void) {
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let token = defaults.string(forKey: "authToken"),
              let baseUrl = defaults.string(forKey: "apiBaseUrl"),
              !token.isEmpty,
              !baseUrl.isEmpty else {
            completion(false)
            return
        }

        let trimmedBaseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        guard let url = URL(string: "\(trimmedBaseUrl)/doodle/latest") else {
            completion(false)
            return
        }

        func attempt(authToken: String, allowRefresh: Bool) {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 8

            URLSession.shared.dataTask(with: request) { data, response, error in
                if allowRefresh,
                   let http = response as? HTTPURLResponse,
                   http.statusCode == 401 || http.statusCode == 403 {
                    DoodleWidgetTokenRefresher.refresh(
                        defaults: defaults, baseUrl: trimmedBaseUrl
                    ) { newToken in
                        if let newToken = newToken {
                            attempt(authToken: newToken, allowRefresh: false)
                        } else {
                            completion(false)
                        }
                    }
                    return
                }

                guard let data = data,
                      error == nil,
                      let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(false)
                    return
                }

                guard let doodle = json["doodle"] as? [String: Any] else {
                    defaults.removeObject(forKey: "doodleImageUrl")
                    defaults.removeObject(forKey: "doodleReceivedAt")
                    defaults.removeObject(forKey: "doodleSenderName")
                    defaults.synchronize()
                    completion(true)
                    return
                }

                defaults.set(doodle["imageUrl"] as? String ?? "", forKey: "doodleImageUrl")
                defaults.set(doodle["createdAt"] as? String ?? "", forKey: "doodleReceivedAt")
                let senderName = ((doodle["sender"] as? [String: Any])?["nickname"] as? String) ?? ""
                defaults.set(senderName, forKey: "doodleSenderName")
                defaults.synchronize()
                completion(true)
            }.resume()
        }

        attempt(authToken: token, allowRefresh: true)
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
        // 토큰은 API 와 같은 호스트일 때만 보낸다(이미지가 다른 도메인이면 토큰이 새지 않게).
        let apiHost = defaults.string(forKey: "apiBaseUrl").flatMap { URL(string: $0)?.host }
        if apiHost != nil, apiHost == url.host,
           let token = defaults.string(forKey: "authToken"), !token.isEmpty {
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
        DoodlePolaroidCard {
            if !entry.data.isConnected {
                DoodleNotConnectedView()
            } else if let image = entry.data.image {
                DoodlePhotoView(
                    image: image,
                    senderName: entry.data.senderName,
                    receivedAt: entry.data.receivedAt
                )
            } else if entry.data.imageUrl != nil {
                // URL은 있지만 캐시 미스 (위젯이 첫 fetch 중)
                VStack(spacing: 6) {
                    Image(systemName: "paintbrush.pointed")
                        .font(.system(size: 28))
                        .foregroundColor(WidgetPalette.rose)
                    Text("그림을\n불러오는 중...")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                DoodleEmptyView()
            }
        }
        .widgetURL(URL(string: "hmlove://doodle?homeWidget=true"))
    }
}

/// 흰 폴라로이드 카드(잉크 윤곽선 + 하드 아래 모서리) + 분홍 테이프 + 뒤에 깔린 라벤더 종이.
struct DoodlePolaroidCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                PaperCardBackground(
                    fill: .white,
                    ink: WidgetPalette.ink,
                    radius: 14,
                    edge: 5,
                    lineWidth: 2,
                    backs: [PaperBack(color: PaperKit.backLavender, angle: 2.5)]
                )
            )
            .overlay(alignment: .top) {
                WashiTape(color: PaperKit.washiPink, width: 54, height: 16, angle: -3)
                    .offset(y: -8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 15)
    }
}

struct DoodlePhotoView: View {
    let image: CGImage
    let senderName: String?
    var receivedAt: Date? = nil

    private var caption: String {
        if let name = senderName, !name.isEmpty { return "\(name)의 그림" }
        return "받은 그림"
    }

    private var dateText: String? {
        guard let date = receivedAt else { return nil }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Color.clear
                .overlay(
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(WidgetPalette.ink.opacity(0.18), lineWidth: 1)
                )

            HStack(spacing: 4) {
                Text(caption)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(WidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                if let dateText = dateText {
                    Text(dateText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WidgetPalette.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(.top, 9)
        .padding(.horizontal, 8)
        .padding(.bottom, 7)
    }
}

struct DoodleEmptyView: View {
    var body: some View {
        VStack(spacing: 3) {
            MoodFaceView(moodKey: "peaceful", size: 40)
            Text("아직 받은\n그림이 없어요")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(WidgetPalette.textPrimary)
                .multilineTextAlignment(.center)
            Text("앱에서 그림을\n보내달라고 해보세요")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(WidgetPalette.textHint)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }
}

struct DoodleNotConnectedView: View {
    var body: some View {
        VStack(spacing: 4) {
            MoodFaceView(moodKey: "missing", size: 46)
            Text("우리연애")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(WidgetPalette.rose)
            Text("로그인 후\n사용 가능")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(WidgetPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
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
                    WidgetPalette.heroGradient
                }
        } else {
            DoodleWidgetView(entry: entry)
                .background(WidgetPalette.heroGradient)
        }
    }
}

// MARK: - Token Refresh

/// 위젯 extension 이 401 받으면 refresh token 으로 새 access token 받아 prefs 갱신.
/// HMLoveWidget 타겟 (calendar / doodle 위젯) 공통으로 쓸 수 있게 enum 으로 정의.
enum DoodleWidgetTokenRefresher {
    static func refresh(
        defaults: UserDefaults,
        baseUrl: String,
        completion: @escaping (String?) -> Void
    ) {
        guard let refreshToken = defaults.string(forKey: "refreshToken"),
              !refreshToken.isEmpty else {
            completion(nil)
            return
        }
        let trimmed = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        guard let url = URL(string: "\(trimmed)/auth/refresh") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["refreshToken": refreshToken]
        )

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newToken = json["accessToken"] as? String,
                  !newToken.isEmpty else {
                completion(nil)
                return
            }
            defaults.set(newToken, forKey: "authToken")
            defaults.synchronize()
            completion(newToken)
        }.resume()
    }
}
