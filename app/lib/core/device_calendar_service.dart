import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'constants.dart';

class DeviceCalendarService {
  static final _plugin = DeviceCalendarPlugin();
  static bool _tzInitialized = false;

  static void _ensureTz() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  // --- 권한 ---

  /// 권한 확인 (플러그인 API + 실제 접근 fallback)
  static Future<bool> hasPermission() async {
    try {
      final result = await _plugin.hasPermissions();
      debugPrint('[DeviceCalendar] hasPermissions: isSuccess=${result.isSuccess}, data=${result.data}');
      if (result.isSuccess && (result.data ?? false)) return true;

      // fallback: 실제로 캘린더 접근 가능한지 확인
      final calendars = await _plugin.retrieveCalendars();
      if (calendars.isSuccess && calendars.data != null && calendars.data!.isNotEmpty) {
        debugPrint('[DeviceCalendar] hasPermission fallback: calendars accessible');
        return true;
      }
    } catch (e) {
      debugPrint('[DeviceCalendar] hasPermission error: $e');
    }
    return false;
  }

  /// 권한 요청 → 실제 접근 확인
  static Future<bool> requestPermission() async {
    try {
      // 1. 플러그인 권한 요청
      final result = await _plugin.requestPermissions();
      debugPrint('[DeviceCalendar] requestPermissions: isSuccess=${result.isSuccess}, data=${result.data}');
      if (result.isSuccess && (result.data ?? false)) return true;

      // 2. fallback: 실제 캘린더 접근 확인 (일부 기기에서 플러그인 API가 부정확)
      final calendars = await _plugin.retrieveCalendars();
      if (calendars.isSuccess && calendars.data != null && calendars.data!.isNotEmpty) {
        debugPrint('[DeviceCalendar] requestPermission fallback: calendars accessible');
        return true;
      }
    } catch (e) {
      debugPrint('[DeviceCalendar] requestPermission error: $e');
    }
    return false;
  }

  // --- 읽기 ---

  static Future<List<Calendar>> getCalendars() async {
    try {
      final result = await _plugin.retrieveCalendars();
      if (result.isSuccess && result.data != null) {
        return result.data!.where((c) => c.id != null).toList();
      }
      debugPrint('[DeviceCalendar] getCalendars: isSuccess=${result.isSuccess}, errors=${result.errors}');
    } catch (e) {
      debugPrint('[DeviceCalendar] getCalendars error: $e');
    }
    return [];
  }

  /// 쓰기 가능한 캘린더만 반환
  static Future<List<Calendar>> getWritableCalendars() async {
    final all = await getCalendars();
    return all.where((c) => c.isReadOnly == false).toList();
  }

  /// OS가 제공하는 공휴일 캘린더 자동 감지. 읽기전용 구독 캘린더 중
  /// 캘린더 이름에 "공휴일/휴일" 키워드를 포함하는 항목만 반환하므로
  /// 한국/일본/영어권/유럽권 등 지역 무관하게 자동 동작한다.
  ///
  /// 매칭은 **calendar.name 만** 검색한다 — Google Calendar는 절기/세시풍속/
  /// 기념일까지 모두 `*holiday@group.v.calendar.google.com` 라는 같은 account
  /// 네임스페이스를 쓰기 때문에 accountName 으로 매칭하면 절기·세시풍속이
  /// 빨간 공휴일로 잘못 표시된다. (실제 공휴일 캘린더의 name 은 "대한민국의
  /// 휴일" / "Holidays in South Korea" 처럼 키워드를 포함하므로 name 만으로 충분.)
  ///
  /// 키워드는 "공휴일/휴일" 의미를 직접 담는 단어만 사용한다.
  /// `한국`/`korean`/`south korea` 같은 국가명 단독은 비공휴일 구독(예:
  /// "Korean Drama", "한국 야구")과 충돌할 수 있어 제외.
  /// 읽기전용(=구독) 캘린더로 제한해 "내 휴가" 같은 사용자 일정과 충돌 방지.
  /// `isReadOnly` 가 null로 오는 OEM(샤오미·일부 삼성 등)도 있어 명시적으로
  /// `false`인 경우만 배제한다 (null은 통과).
  static const _holidayKeywords = [
    'holiday', 'holidays', 'public holiday',
    '공휴일', '휴일',
    '祝日', '祝祭日', '節日', '节日',
    'feriado', 'feriados', 'feriados nacionales',
    'férié', 'fériés', 'jour férié', 'jours fériés',
    'feiertag', 'feiertage',
    'festivo', 'festivi', 'festività',
    'helgdag', 'helgdagar', 'helligdag', 'helligdage',
    'święto', 'święta',
    'feestdag', 'feestdagen',
    'праздник', 'праздники',
    'חג', 'חגים',
    'hari libur', 'hari raya',
    'วันหยุด',
    'ngày lễ',
  ];

  static Future<List<Calendar>> getHolidayCalendars() async {
    final all = await getCalendars();
    final matched = all.where((c) => _looksLikeHolidayCalendar(c)).toList();
    if (matched.isNotEmpty) return matched;

    // 디버그: 어떤 후보들이 있었는지 한 줄로 남김 (사용자 문의 디버깅용)
    debugPrint(
      '[DeviceCalendar] No holiday calendar matched. Candidates: '
      '${all.map((c) => '${c.name}/${c.accountName}/ro=${c.isReadOnly}').join(', ')}',
    );
    return matched;
  }

  /// 휴일 캘린더 후보 판정. UI 진단 화면도 같은 로직을 쓸 수 있도록 노출.
  static bool _looksLikeHolidayCalendar(Calendar c) {
    if (c.isReadOnly == false) return false; // 명시적 false만 배제
    final name = (c.name ?? '').toLowerCase();
    if (name.isEmpty) return false;
    return _holidayKeywords.any((kw) => name.contains(kw.toLowerCase()));
  }

  /// 진단 UI용 — 캘린더 한 건이 공휴일 후보로 매칭되는지 외부에서 조회.
  static bool isHolidayCalendarCandidate(Calendar c) =>
      _looksLikeHolidayCalendar(c);

  // --- 공휴일 오버레이 설정 ---

  /// 유저가 최초로 공휴일 토글을 평가받은 적이 있는지.
  /// false면 캘린더 화면 진입 시 1회 자동 권한 요청 + 기본 ON 시도.
  static bool isHolidayOverlayInitialized() {
    final box = Hive.box(AppConstants.authBox);
    return box.get('holidayOverlayInitialized', defaultValue: false) as bool;
  }

  static Future<void> setHolidayOverlayInitialized(bool value) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put('holidayOverlayInitialized', value);
  }

  static bool isHolidayOverlayEnabled() {
    final box = Hive.box(AppConstants.authBox);
    return box.get('holidayOverlayEnabled', defaultValue: false) as bool;
  }

  static Future<void> setHolidayOverlayEnabled(bool enabled) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put('holidayOverlayEnabled', enabled);
  }

  static Future<List<Event>> getEvents({
    required List<String> calendarIds,
    required DateTime start,
    required DateTime end,
  }) async {
    final events = <Event>[];
    for (final id in calendarIds) {
      try {
        final result = await _plugin.retrieveEvents(
          id,
          RetrieveEventsParams(startDate: start, endDate: end),
        );
        if (result.isSuccess && result.data != null) {
          events.addAll(result.data!);
        }
      } catch (e) {
        debugPrint('[DeviceCalendar] Error fetching from $id: $e');
      }
    }
    return events;
  }

  // --- 쓰기 (앱 일정 → 기기 캘린더) ---

  static Future<String?> createEvent({
    required String calendarId,
    required String title,
    required DateTime date,
    String? description,
  }) async {
    _ensureTz();
    try {
      final start = tz.TZDateTime.utc(date.year, date.month, date.day);
      final end = tz.TZDateTime.utc(date.year, date.month, date.day, 23, 59);

      final event = Event(
        calendarId,
        title: title,
        start: start,
        end: end,
        allDay: true,
        description: description,
      );

      final result = await _plugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true && result?.data != null) {
        debugPrint('[DeviceCalendar] Created event: ${result!.data}');
        return result.data;
      }
      debugPrint('[DeviceCalendar] createEvent failed: ${result?.errors}');
    } catch (e) {
      debugPrint('[DeviceCalendar] createEvent error: $e');
    }
    return null;
  }

  static Future<bool> updateEvent({
    required String calendarId,
    required String eventId,
    required String title,
    required DateTime date,
    String? description,
  }) async {
    _ensureTz();
    try {
      final start = tz.TZDateTime.utc(date.year, date.month, date.day);
      final end = tz.TZDateTime.utc(date.year, date.month, date.day, 23, 59);

      final event = Event(
        calendarId,
        eventId: eventId,
        title: title,
        start: start,
        end: end,
        allDay: true,
        description: description,
      );

      final result = await _plugin.createOrUpdateEvent(event);
      return result?.isSuccess == true;
    } catch (e) {
      debugPrint('[DeviceCalendar] updateEvent error: $e');
    }
    return false;
  }

  static Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    try {
      final result = await _plugin.deleteEvent(calendarId, eventId);
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      debugPrint('[DeviceCalendar] deleteEvent error: $e');
    }
    return false;
  }

  // --- Hive 설정 ---

  static bool isSyncEnabled() {
    final box = Hive.box(AppConstants.authBox);
    return box.get('deviceCalendarSync', defaultValue: false) as bool;
  }

  static Future<void> setSyncEnabled(bool enabled) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put('deviceCalendarSync', enabled);
  }

  static List<String> getSelectedCalendarIds() {
    final box = Hive.box(AppConstants.authBox);
    final ids = box.get('selectedCalendarIds');
    if (ids == null) return [];
    return List<String>.from(ids as List);
  }

  static Future<void> saveSelectedCalendarIds(List<String> ids) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put('selectedCalendarIds', ids);
  }

  /// 상대방 일정도 기기 캘린더에 동기화 (기본값: true)
  static bool isSyncPartnerEnabled() {
    final box = Hive.box(AppConstants.authBox);
    return box.get('deviceCalendarSyncPartner', defaultValue: true) as bool;
  }

  static Future<void> setSyncPartnerEnabled(bool enabled) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put('deviceCalendarSyncPartner', enabled);
  }

  static String? getDefaultWriteCalendarId() {
    final box = Hive.box(AppConstants.authBox);
    return box.get('defaultWriteCalendarId') as String?;
  }

  static Future<void> setDefaultWriteCalendarId(String? id) async {
    final box = Hive.box(AppConstants.authBox);
    if (id == null) {
      await box.delete('defaultWriteCalendarId');
    } else {
      await box.put('defaultWriteCalendarId', id);
    }
  }

  // --- 앱 이벤트 ↔ 기기 이벤트 매핑 ---

  static String? getDeviceEventId(String appEventId) {
    final box = Hive.box(AppConstants.authBox);
    final map = box.get('deviceEventMap');
    if (map == null) return null;
    return (map as Map)[appEventId] as String?;
  }

  static Future<void> saveEventMapping(
      String appEventId, String deviceEventId) async {
    final box = Hive.box(AppConstants.authBox);
    final map =
        Map<String, String>.from(box.get('deviceEventMap', defaultValue: {}) as Map);
    map[appEventId] = deviceEventId;
    await box.put('deviceEventMap', map);
  }

  static Future<void> deleteEventMapping(String appEventId) async {
    final box = Hive.box(AppConstants.authBox);
    final map =
        Map<String, String>.from(box.get('deviceEventMap', defaultValue: {}) as Map);
    map.remove(appEventId);
    await box.put('deviceEventMap', map);
  }

  /// 전체 매핑 맵 반환 (appEventId → deviceEventId)
  static Map<String, String> getAllEventMappings() {
    final box = Hive.box(AppConstants.authBox);
    final map = box.get('deviceEventMap');
    if (map == null) return {};
    return Map<String, String>.from(map as Map);
  }

  // --- 월별 동기화 추적 ---

  /// 해당 월에 동기화된 앱 이벤트 ID 목록
  static List<String> getSyncedIdsForMonth(String yearMonth) {
    final box = Hive.box(AppConstants.authBox);
    final map = box.get('deviceSyncMonthMap');
    if (map == null) return [];
    final monthData = (map as Map)[yearMonth];
    if (monthData == null) return [];
    return List<String>.from(monthData as List);
  }

  /// 해당 월의 동기화된 앱 이벤트 ID 목록 저장
  static Future<void> saveSyncedIdsForMonth(
      String yearMonth, List<String> ids) async {
    final box = Hive.box(AppConstants.authBox);
    final map = Map<String, dynamic>.from(
        box.get('deviceSyncMonthMap', defaultValue: {}) as Map);
    map[yearMonth] = ids;
    await box.put('deviceSyncMonthMap', map);
  }
}
