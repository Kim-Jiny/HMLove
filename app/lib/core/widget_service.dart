import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'api_client.dart';
import 'constants.dart';

/// debugPrint 는 release 에서도 실행돼 콘솔 노이즈가 남으므로 dev-only 헬퍼로 감쌈.
void _devLog(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// App Group ID (iOS) - must match Widget Extension's App Group
const _appGroupId = 'group.com.jiny.hmlove';

/// Widget names
const _iosWidgetName = 'HMLoveWidget';
const _iosDoodleWidgetName = 'HMLoveDoodleWidget';
const _androidWidgetName = 'HMLoveWidgetProvider';
const _androidSmallWidgetName = 'HMLoveSmallWidgetProvider';
const _androidCalendarWidgetName = 'HMLoveCalendarWidgetProvider';
const _androidDoodleWidgetName = 'HMLoveDoodleWidgetProvider';
const _calendarEventMonthsKey = 'widgetCalendarEventMonths';
const _deviceCalendarEventMonthsKey = 'widgetDeviceCalendarEventMonths';
const _holidayEventMonthsKey = 'widgetHolidayEventMonths';

/// 위젯 prev/next 네비게이션이 발생한 월(앱 캐시가 비어있을 수 있음).
/// 앱이 포어그라운드 복귀 시 읽어 device/holiday 캐시를 채우고 비운다.
const _pendingHydrationKey = 'widgetPendingHydrationMonths';

class WidgetService {
  WidgetService._();

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);

    // 앱 시작 시 Hive 에 캐시된 access token 이 있으면 home_widget prefs 에도
    // 동기화. saveAuthInfo 는 로그인/refresh 시점에만 호출되므로, 이미 로그인된
    // 상태로 앱을 켜면 이 prefs 가 영영 비어있어서 위젯의 백그라운드 fetch
    // (Android Kotlin Provider, iOS NSE) 가 토큰을 못 찾는 문제 방지.
    try {
      final token = ApiClient.getAccessToken();
      final refresh = ApiClient.getRefreshToken();
      if (token != null && token.isNotEmpty) {
        await saveAuthInfo(token, AppConstants.apiBaseUrl, refresh);
      }
    } catch (e) {
      _devLog('[WidgetService] auth sync on init failed: $e');
    }
  }

  /// Save auth info so widget extension can fetch data independently.
  /// [refreshToken] 도 같이 저장하면 위젯/NSE 가 access token 만료 시 자체적으로
  /// /auth/refresh 를 호출해 갱신할 수 있음 (app 안 열어도 stale 안 됨).
  static Future<void> saveAuthInfo(
    String token,
    String apiBaseUrl, [
    String? refreshToken,
  ]) async {
    await HomeWidget.setAppGroupId(_appGroupId);
    await Future.wait([
      HomeWidget.saveWidgetData('authToken', token),
      HomeWidget.saveWidgetData('apiBaseUrl', apiBaseUrl),
      if (refreshToken != null)
        HomeWidget.saveWidgetData('refreshToken', refreshToken),
    ]);
  }

  /// Update D-day / couple data
  static Future<void> updateCoupleData({
    required String myName,
    required String partnerName,
    required int daysTogether,
    required String startDate,
    String? nextAnniversaryName,
    int? nextAnniversaryDaysLeft,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData('isConnected', true),
      HomeWidget.saveWidgetData('myName', myName),
      HomeWidget.saveWidgetData('partnerName', partnerName),
      HomeWidget.saveWidgetData('daysTogether', daysTogether),
      HomeWidget.saveWidgetData('startDate', startDate),
      if (nextAnniversaryName != null)
        HomeWidget.saveWidgetData('nextAnniversaryName', nextAnniversaryName),
      if (nextAnniversaryDaysLeft != null)
        HomeWidget.saveWidgetData(
          'nextAnniversaryDaysLeft',
          nextAnniversaryDaysLeft,
        ),
    ]);
    await _refresh();
  }

  /// Clear widget data on logout
  static Future<void> clearData() async {
    final calendarMonths = await _loadTrackedMonths(_calendarEventMonthsKey);
    final deviceMonths = await _loadTrackedMonths(
      _deviceCalendarEventMonthsKey,
    );
    final holidayMonths = await _loadTrackedMonths(_holidayEventMonthsKey);

    final clears = <Future<bool?>>[
      HomeWidget.saveWidgetData('isConnected', false),
      HomeWidget.saveWidgetData<String?>('authToken', null),
      HomeWidget.saveWidgetData<String?>('refreshToken', null),
      HomeWidget.saveWidgetData<String?>('apiBaseUrl', null),
      HomeWidget.saveWidgetData<String?>('myName', null),
      HomeWidget.saveWidgetData<String?>('partnerName', null),
      HomeWidget.saveWidgetData<int?>('daysTogether', null),
      HomeWidget.saveWidgetData<String?>('startDate', null),
      HomeWidget.saveWidgetData<String?>('nextAnniversaryName', null),
      HomeWidget.saveWidgetData<int?>('nextAnniversaryDaysLeft', null),
      HomeWidget.saveWidgetData<String?>('myMoodEmoji', null),
      HomeWidget.saveWidgetData<String?>('partnerMoodEmoji', null),
      HomeWidget.saveWidgetData<String?>('todaySchedule', null),
      HomeWidget.saveWidgetData<String?>('doodleImageUrl', null),
      HomeWidget.saveWidgetData<String?>('doodleReceivedAt', null),
      HomeWidget.saveWidgetData<String?>('doodleSenderName', null),
      HomeWidget.saveWidgetData<String?>('calendarYearMonth', null),
      HomeWidget.saveWidgetData<String?>('calendarEvents', null),
      HomeWidget.saveWidgetData<bool?>('deviceCalendarEnabled', null),
      HomeWidget.saveWidgetData<bool?>('holidayOverlayEnabled', null),
      HomeWidget.saveWidgetData<String?>(_calendarEventMonthsKey, null),
      HomeWidget.saveWidgetData<String?>(_deviceCalendarEventMonthsKey, null),
      HomeWidget.saveWidgetData<String?>(_holidayEventMonthsKey, null),
      HomeWidget.saveWidgetData<String?>(_pendingHydrationKey, null),
    ];

    for (final yearMonth in calendarMonths) {
      clears.add(
        HomeWidget.saveWidgetData<String?>('calendarEvents_$yearMonth', null),
      );
    }
    for (final yearMonth in deviceMonths) {
      clears.add(
        HomeWidget.saveWidgetData<String?>(
          'deviceCalendarEvents_$yearMonth',
          null,
        ),
      );
    }
    for (final yearMonth in holidayMonths) {
      clears.add(
        HomeWidget.saveWidgetData<String?>('holidayEvents_$yearMonth', null),
      );
    }

    await Future.wait(clears);
    await _refresh();
  }

  /// Update mood data
  static Future<void> updateMoodData({
    String? myMoodKey,
    String? partnerMoodKey,
  }) async {
    final myEmoji = _moodEmoji(myMoodKey);
    final partnerEmoji = _moodEmoji(partnerMoodKey);

    await Future.wait([
      HomeWidget.saveWidgetData('myMoodEmoji', myEmoji),
      HomeWidget.saveWidgetData('partnerMoodEmoji', partnerEmoji),
    ]);
    await _refresh();
  }

  /// Update today's schedule text for medium widget
  static Future<void> updateTodaySchedule(String? schedule) async {
    await HomeWidget.saveWidgetData('todaySchedule', schedule ?? '');
    await _refresh();
  }

  /// 서버에서 /doodle/latest 를 직접 받아 위젯용 prefs 를 갱신하고 위젯 update broadcast.
  /// 백그라운드 isolate (FCM background handler) 와 foreground 핸들러 양쪽에서 호출 가능하도록
  /// HomeWidget + HttpClient 만 사용 (riverpod 의존성 없음).
  /// Foreground 에서는 home_widget 플러그인을 통해 prefs 갱신 + 위젯 broadcast.
  /// Background isolate 에서는 home_widget method channel 이 동작 안 해 token 조회가
  /// null 로 떨어지므로, prefs fetch 는 Kotlin Provider (HMLoveDoodleWidgetProvider) /
  /// iOS NSE 가 직접 담당하고 여기선 무조건 broadcast 만 시도한다.
  static Future<void> refreshDoodleFromServer() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
      final token = await HomeWidget.getWidgetData<String>('authToken');
      final baseUrl = await HomeWidget.getWidgetData<String>('apiBaseUrl');
      _devLog(
        '[Doodle refresh] token=${token == null ? "null" : "(set)"} '
        'baseUrl=$baseUrl',
      );

      if (token != null && baseUrl != null) {
        // Foreground 또는 plugin 이 BG 에서도 살아있는 경우 — 직접 fetch.
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('$baseUrl/doodle/latest'),
          );
          request.headers.set('Authorization', 'Bearer $token');
          final response = await request.close();
          _devLog(
            '[Doodle refresh] /doodle/latest → ${response.statusCode}',
          );
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final data = jsonDecode(body) as Map<String, dynamic>;
            final doodle = data['doodle'] as Map<String, dynamic>?;
            if (doodle != null) {
              final imageUrl = doodle['imageUrl'] as String?;
              final createdAt = doodle['createdAt'] as String?;
              final sender = doodle['sender'] as Map<String, dynamic>?;
              final senderName = sender?['nickname'] as String?;
              _devLog('[Doodle refresh] new url=$imageUrl @ $createdAt');
              await HomeWidget.saveWidgetData<String?>(
                'doodleImageUrl',
                imageUrl,
              );
              await HomeWidget.saveWidgetData<String?>(
                'doodleReceivedAt',
                createdAt,
              );
              await HomeWidget.saveWidgetData<String?>(
                'doodleSenderName',
                senderName,
              );
            } else {
              _devLog('[Doodle refresh] no doodle — clearing keys');
              await HomeWidget.saveWidgetData<String?>('doodleImageUrl', null);
              await HomeWidget.saveWidgetData<String?>(
                'doodleReceivedAt',
                null,
              );
              await HomeWidget.saveWidgetData<String?>(
                'doodleSenderName',
                null,
              );
            }
          }
        } finally {
          client.close();
        }
      } else {
        _devLog(
          '[Doodle refresh] no token in plugin prefs '
          '(BG isolate?) — native widget provider 가 직접 fetch 할 것',
        );
      }
    } catch (e) {
      _devLog('[Doodle refresh] error: $e');
    }

    // 어느 경우든 위젯 broadcast 시도. BG 에서는 fetch 못 했더라도
    // Kotlin Provider 의 onUpdate 가 깨어나 직접 서버에서 받아온다.
    // iOS 는 kind 별 reload — doodle 위젯 kind 는 'HMLoveDoodleWidget' 으로 명시.
    try {
      await HomeWidget.updateWidget(
        androidName: _androidDoodleWidgetName,
        iOSName: _iosDoodleWidgetName,
      );
      _devLog('[Doodle refresh] HomeWidget.updateWidget broadcast sent');
    } catch (e) {
      _devLog('[Doodle refresh] updateWidget failed: $e');
    }
  }

  /// Update the doodle (그림) shown on the 2x2 doodle widget.
  /// [imageUrl] - 마지막으로 받은 그림의 PNG URL (null 이면 위젯이 빈 상태로 표시)
  /// [receivedAt] - 받은 시각 (ISO8601). 위젯에서 상대 시간으로 표시.
  /// [senderName] - 보낸 사람 닉네임.
  static Future<void> updateDoodleData({
    String? imageUrl,
    DateTime? receivedAt,
    String? senderName,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData<String?>('doodleImageUrl', imageUrl),
      HomeWidget.saveWidgetData<String?>(
        'doodleReceivedAt',
        receivedAt?.toIso8601String(),
      ),
      HomeWidget.saveWidgetData<String?>('doodleSenderName', senderName),
    ]);
    await _refresh();
  }

  /// 위젯이 현재 표시 중인 월(prev/next 네비게이션 반영). null/빈문자면 미설정 상태.
  static Future<String?> getDisplayedCalendarYearMonth() async {
    return HomeWidget.getWidgetData<String>('calendarYearMonth');
  }

  /// 위젯이 표시했지만 앱이 device/holiday 데이터를 채우지 못했을 수 있는 월 목록.
  /// 위젯 익스텐션은 EventKit 권한이 없어 직접 채우지 못하므로 앱이 따라잡아야 함.
  static Future<List<String>> getPendingHydrationMonths() async {
    return _loadTrackedMonths(_pendingHydrationKey);
  }

  /// pending hydration 집합을 비움. 앱이 처리 완료한 뒤 호출.
  static Future<void> clearPendingHydrationMonths() async {
    await HomeWidget.saveWidgetData<String?>(_pendingHydrationKey, null);
  }

  /// Update calendar events for large calendar widget.
  ///
  /// Events are cached per-month under `calendarEvents_{yearMonth}` so the
  /// widget's prev/next navigation can render any month the app has fetched.
  /// The legacy `calendarEvents` key is kept in sync for the current month
  /// (for any native code that still reads the unsuffixed key).
  /// The widget owns its own displayed month state (`calendarYearMonth`), so
  /// we intentionally do NOT overwrite it here — doing so would snap the
  /// widget back to the current month whenever the app pushes data.
  static Future<void> updateCalendarEvents(
    List<Map<String, dynamic>> events,
    String yearMonth,
  ) async {
    final jsonStr = jsonEncode(events);
    final now = DateTime.now();
    final currentYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final futures = <Future<void>>[
      HomeWidget.saveWidgetData('calendarEvents_$yearMonth', jsonStr),
      _trackMonth(_calendarEventMonthsKey, yearMonth),
    ];
    if (yearMonth == currentYm) {
      futures.add(HomeWidget.saveWidgetData('calendarEvents', jsonStr));
    }
    await Future.wait(futures);
    await _refresh();
  }

  /// Enable or disable the device-calendar overlay for the widget.
  /// Widgets gate their read of `deviceCalendarEvents_{ym}` keys on this flag.
  static Future<void> setDeviceCalendarEnabled(bool enabled) async {
    await HomeWidget.saveWidgetData('deviceCalendarEnabled', enabled);
    await _refresh();
  }

  /// Push the user's device-calendar events for [yearMonth] to the widget.
  /// Stored under `deviceCalendarEvents_{yearMonth}` so the widget can merge
  /// them with the server events at render time.
  static Future<void> updateDeviceCalendarEvents(
    List<Map<String, dynamic>> events,
    String yearMonth,
  ) async {
    await Future.wait([
      HomeWidget.saveWidgetData(
        'deviceCalendarEvents_$yearMonth',
        jsonEncode(events),
      ),
      _trackMonth(_deviceCalendarEventMonthsKey, yearMonth),
    ]);
    await _refresh();
  }

  /// Enable or disable holiday display in widgets.
  /// Widgets gate their read of `holidayEvents_{ym}` on this flag.
  static Future<void> setHolidayOverlayEnabled(bool enabled) async {
    await HomeWidget.saveWidgetData('holidayOverlayEnabled', enabled);
    await _refresh();
  }

  /// Push auto-detected OS holiday events for [yearMonth] to the widget.
  /// Widget reads these under `holidayEvents_{yearMonth}` and paints the
  /// matching day numbers red.
  static Future<void> updateHolidayEvents(
    List<Map<String, dynamic>> events,
    String yearMonth,
  ) async {
    await Future.wait([
      HomeWidget.saveWidgetData('holidayEvents_$yearMonth', jsonEncode(events)),
      _trackMonth(_holidayEventMonthsKey, yearMonth),
    ]);
    await _refresh();
  }

  static Future<void> _trackMonth(String storageKey, String yearMonth) async {
    final months = await _loadTrackedMonths(storageKey);
    if (months.contains(yearMonth)) return;
    months.add(yearMonth);
    months.sort();
    await HomeWidget.saveWidgetData(storageKey, jsonEncode(months));
  }

  static Future<List<String>> _loadTrackedMonths(String storageKey) async {
    final raw = await HomeWidget.getWidgetData<String>(storageKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return <String>[];
  }

  static Future<void> _refresh() async {
    // iOS는 동일 위젯 이름이므로 1회만 리로드, Android는 각 provider별 호출
    await HomeWidget.updateWidget(
      iOSName: _iosWidgetName,
      androidName: _androidWidgetName,
    );
    await Future.wait([
      HomeWidget.updateWidget(
        iOSName: _iosWidgetName,
        androidName: _androidSmallWidgetName,
      ),
      HomeWidget.updateWidget(
        iOSName: _iosWidgetName,
        androidName: _androidCalendarWidgetName,
      ),
      // Doodle widget 은 iOS 에서 별도 kind ('HMLoveDoodleWidget') 라
      // iOSName 도 다르게 줘야 reloadTimelines 가 doodle 위젯에 적용됨.
      HomeWidget.updateWidget(
        iOSName: _iosDoodleWidgetName,
        androidName: _androidDoodleWidgetName,
      ),
    ]);
  }

  static String _moodEmoji(String? key) {
    const map = {
      'happy': '😊',
      'love': '🥰',
      'excited': '🤩',
      'grateful': '🙏',
      'peaceful': '😌',
      'proud': '😎',
      'missing': '🥺',
      'bored': '😐',
      'sad': '😢',
      'angry': '😤',
      'tired': '😴',
      'stressed': '😩',
    };
    return map[key] ?? '😶';
  }
}
