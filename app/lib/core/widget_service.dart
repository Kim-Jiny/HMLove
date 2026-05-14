import 'dart:convert';

import 'package:home_widget/home_widget.dart';

/// App Group ID (iOS) - must match Widget Extension's App Group
const _appGroupId = 'group.com.jiny.hmlove';

/// Widget names
const _iosWidgetName = 'HMLoveWidget';
const _androidWidgetName = 'HMLoveWidgetProvider';
const _androidSmallWidgetName = 'HMLoveSmallWidgetProvider';
const _androidCalendarWidgetName = 'HMLoveCalendarWidgetProvider';
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
  }

  /// Save auth info so widget extension can fetch data independently
  static Future<void> saveAuthInfo(String token, String apiBaseUrl) async {
    await Future.wait([
      HomeWidget.saveWidgetData('authToken', token),
      HomeWidget.saveWidgetData('apiBaseUrl', apiBaseUrl),
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
        HomeWidget.saveWidgetData<String?>(
          'holidayEvents_$yearMonth',
          null,
        ),
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
      HomeWidget.saveWidgetData(
        'holidayEvents_$yearMonth',
        jsonEncode(events),
      ),
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
