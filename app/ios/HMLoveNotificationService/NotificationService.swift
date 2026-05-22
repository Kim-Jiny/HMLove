//
//  NotificationService.swift
//  HMLoveNotificationService
//
//  Notification Service Extension — `mutable-content: 1`이 포함된 alert push가
//  도착하면 OS가 알림을 사용자에게 표시하기 직전에 본 extension을 깨운다.
//  (silent push와 달리 alert push는 OS throttling이 거의 없어 즉시 전달됨.)
//
//  여기서 캘린더 데이터를 서버에서 받아 App Group UserDefaults에 저장하고
//  WidgetCenter로 위젯 timeline을 reload하면, 사용자가 알림을 보는 시점에는
//  이미 위젯이 최신 데이터로 갱신돼 있다.
//

import UserNotifications
import WidgetKit

class NotificationService: UNNotificationServiceExtension {
    private static let appGroupId = "group.com.jiny.hmlove"

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent = self.bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // 위젯 데이터를 갱신해야 하는 type만 처리. 그 외는 즉시 통과.
        let type = request.content.userInfo["type"] as? String
        switch type {
        case "calendar":
            refreshCalendarWidget {
                contentHandler(bestAttemptContent)
            }
        case "doodle":
            refreshDoodleWidget(userInfo: request.content.userInfo) {
                contentHandler(bestAttemptContent)
            }
        default:
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // OS가 NSE 실행 시간(~30초) 만료 직전에 호출. 가능한 데이터로 알림 표시.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func refreshCalendarWidget(completion: @escaping () -> Void) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let token = defaults.string(forKey: "authToken"),
              let baseUrl = defaults.string(forKey: "apiBaseUrl"),
              !token.isEmpty, !baseUrl.isEmpty else {
            completion()
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let currentYearMonth = formatter.string(from: Date())
        let cached = defaults.string(forKey: "calendarYearMonth") ?? ""
        let displayedYearMonth: String = {
            if !cached.isEmpty, formatter.date(from: cached) != nil {
                return cached
            }
            return currentYearMonth
        }()

        // 위젯이 보고 있는 월(prev/next 네비게이션 반영) + 현재 월 모두 갱신.
        // 위젯이 다른 달을 보고 있어도 prev/next로 돌아왔을 때 stale하지 않게.
        var months = [displayedYearMonth]
        if displayedYearMonth != currentYearMonth {
            months.append(currentYearMonth)
        }

        let group = DispatchGroup()
        for ym in months {
            group.enter()
            fetchMonth(
                ym: ym,
                baseUrl: baseUrl,
                token: token,
                currentYearMonth: currentYearMonth,
                defaults: defaults
            ) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            completion()
        }
    }

    private func fetchMonth(
        ym: String,
        baseUrl: String,
        token: String,
        currentYearMonth: String,
        defaults: UserDefaults,
        completion: @escaping () -> Void
    ) {
        let trimmedBaseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        guard let url = URL(string: "\(trimmedBaseUrl)/calendar/\(ym)") else {
            completion()
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8 // NSE 실행시간 30초 한도, 두 달 fetch 대비 보수적으로

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { completion() }

            guard let data = data, error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let events = json["events"] as? [[String: Any]] else {
                return
            }

            // _auto 이벤트(자동 생성 기념일) 제외 — 위젯은 명시적 이벤트만 렌더.
            let widgetEvents = events.filter { event in
                let isAuto = event["_auto"] as? Bool ?? false
                return !isAuto
            }

            guard let eventsJsonData = try? JSONSerialization.data(withJSONObject: widgetEvents),
                  let jsonString = String(data: eventsJsonData, encoding: .utf8) else {
                return
            }

            defaults.set(jsonString, forKey: "calendarEvents_\(ym)")
            if ym == currentYearMonth {
                defaults.set(jsonString, forKey: "calendarEvents")
            }
        }.resume()
    }

    /// 그림 push 도착 시 푸시 payload의 그림 메타를 우선 App Group에 저장한다.
    /// 이 경로는 서버 재조회나 auth token 없이도 동작해서 TestFlight/백그라운드에서 더 안정적이다.
    private func refreshDoodleWidget(
        userInfo: [AnyHashable: Any],
        completion: @escaping () -> Void
    ) {
        if applyDoodlePayload(userInfo: userInfo, completion: completion) {
            return
        }
        refreshDoodleWidgetFromServer(completion: completion)
    }

    private func applyDoodlePayload(
        userInfo: [AnyHashable: Any],
        completion: @escaping () -> Void
    ) -> Bool {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let imageUrl = userInfo["doodleImageUrl"] as? String,
              !imageUrl.isEmpty else {
            return false
        }

        defaults.set(imageUrl, forKey: "doodleImageUrl")
        defaults.set((userInfo["doodleCreatedAt"] as? String) ?? "", forKey: "doodleReceivedAt")
        defaults.set((userInfo["doodleSenderName"] as? String) ?? "", forKey: "doodleSenderName")
        defaults.synchronize()

        cacheDoodleImageIfNeeded(imageUrl: imageUrl, defaults: defaults, completion: completion)
        return true
    }

    /// Payload에 메타가 없는 오래된 서버/푸시를 위한 fallback.
    private func refreshDoodleWidgetFromServer(completion: @escaping () -> Void) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let token = defaults.string(forKey: "authToken"),
              let baseUrl = defaults.string(forKey: "apiBaseUrl"),
              !token.isEmpty, !baseUrl.isEmpty else {
            completion()
            return
        }
        let trimmedBaseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        guard let url = URL(string: "\(trimmedBaseUrl)/doodle/latest") else {
            completion()
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion()
                return
            }

            guard let doodle = json["doodle"] as? [String: Any] else {
                // 받은 그림이 없음 — 키 정리
                defaults.removeObject(forKey: "doodleImageUrl")
                defaults.removeObject(forKey: "doodleReceivedAt")
                defaults.removeObject(forKey: "doodleSenderName")
                self.reloadWidgetsAndComplete(completion: completion)
                return
            }

            let imageUrl = doodle["imageUrl"] as? String ?? ""
            let createdAt = doodle["createdAt"] as? String ?? ""
            let senderName = ((doodle["sender"] as? [String: Any])?["nickname"] as? String) ?? ""

            defaults.set(imageUrl, forKey: "doodleImageUrl")
            defaults.set(createdAt, forKey: "doodleReceivedAt")
            defaults.set(senderName, forKey: "doodleSenderName")
            defaults.synchronize()

            self.cacheDoodleImageIfNeeded(imageUrl: imageUrl, defaults: defaults, completion: completion)
        }.resume()
    }

    private func cacheDoodleImageIfNeeded(
        imageUrl: String,
        defaults: UserDefaults,
        completion: @escaping () -> Void
    ) {
        guard let img = URL(string: imageUrl) else {
            reloadWidgetsAndComplete(completion: completion)
            return
        }

        var imageRequest = URLRequest(url: img)
        if let token = defaults.string(forKey: "authToken"), !token.isEmpty {
            imageRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        imageRequest.timeoutInterval = 12
        URLSession.shared.dataTask(with: imageRequest) { imgData, _, _ in
            if let imgData = imgData, !imgData.isEmpty {
                Self.writeDoodleCache(imgData, for: imageUrl)
            }
            self.reloadWidgetsAndComplete(completion: completion)
        }.resume()
    }

    private func reloadWidgetsAndComplete(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            completion()
        }
    }

    /// HMLoveDoodleWidget.swift의 DoodleCache와 동일한 경로 규칙을 사용.
    /// (App Group container/doodleCache/{stableHash}.png)
    private static func writeDoodleCache(_ data: Data, for urlString: String) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupId
        ) else { return }
        let folder = container.appendingPathComponent("doodleCache", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true
        )
        let fileName = stableDoodleCacheFileName(for: urlString)
        let path = folder.appendingPathComponent(fileName)
        try? data.write(to: path)
    }

    private static func stableDoodleCacheFileName(for text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16) + ".png"
    }
}
