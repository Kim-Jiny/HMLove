import 'dart:io' show Platform;

import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../core/device_calendar_service.dart';
import '../core/widget_service.dart';
import 'auth_provider.dart';

// Calendar Event model
class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final String? description;
  final bool isAnniversary;
  final String? repeatType;
  final String? color;
  final String? coupleId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isAuto;
  final String eventType; // 'schedule', 'anniversary', 'feed'

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.description,
    this.isAnniversary = false,
    this.repeatType,
    this.color,
    this.coupleId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.isAuto = false,
    this.eventType = 'schedule',
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      date: (DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now()).toLocal(),
      description: json['description'] as String?,
      isAnniversary: json['isAnniversary'] as bool? ?? false,
      repeatType: json['repeatType'] as String?,
      color: json['color'] as String?,
      coupleId: json['coupleId'] as String?,
      createdBy: json['createdBy'] as String? ?? json['authorId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isAuto: json['_auto'] as bool? ?? false,
      eventType: json['eventType'] as String? ?? 'schedule',
    );
  }
}

// Mood entry for calendar
class CalendarMood {
  final String emoji;
  final String nickname;

  const CalendarMood({required this.emoji, required this.nickname});

  factory CalendarMood.fromJson(Map<String, dynamic> json) {
    return CalendarMood(
      emoji: json['emoji'] as String,
      nickname: json['nickname'] as String? ?? '',
    );
  }
}

// Calendar state class
class CalendarState {
  final List<CalendarEvent> events;
  final List<CalendarEvent> deviceEvents;
  final List<CalendarEvent> holidayEvents;
  final Map<String, List<CalendarMood>> moodMap;
  final DateTime? selectedDay;
  final bool isLoading;
  final String? error;
  final bool deviceCalendarEnabled;
  final bool holidayOverlayEnabled;

  const CalendarState({
    this.events = const [],
    this.deviceEvents = const [],
    this.holidayEvents = const [],
    this.moodMap = const {},
    this.selectedDay,
    this.isLoading = false,
    this.error,
    this.deviceCalendarEnabled = false,
    this.holidayOverlayEnabled = false,
  });

  CalendarState copyWith({
    List<CalendarEvent>? events,
    List<CalendarEvent>? deviceEvents,
    List<CalendarEvent>? holidayEvents,
    Map<String, List<CalendarMood>>? moodMap,
    DateTime? selectedDay,
    bool? isLoading,
    String? error,
    bool? deviceCalendarEnabled,
    bool? holidayOverlayEnabled,
  }) {
    return CalendarState(
      events: events ?? this.events,
      deviceEvents: deviceEvents ?? this.deviceEvents,
      holidayEvents: holidayEvents ?? this.holidayEvents,
      moodMap: moodMap ?? this.moodMap,
      selectedDay: selectedDay ?? this.selectedDay,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      deviceCalendarEnabled: deviceCalendarEnabled ?? this.deviceCalendarEnabled,
      holidayOverlayEnabled:
          holidayOverlayEnabled ?? this.holidayOverlayEnabled,
    );
  }

  /// Get moods for a specific day.
  List<CalendarMood> getMoodsForDay(DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return moodMap[key] ?? [];
  }

  /// Get events for a specific day (app + device + holiday).
  List<CalendarEvent> getEventsForDay(DateTime day) {
    final allEvents = [...events, ...deviceEvents, ...holidayEvents];
    return allEvents.where((event) {
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList();
  }

  /// True if [day] has any auto-detected holiday event.
  bool isHoliday(DateTime day) {
    for (final e in holidayEvents) {
      if (e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day) {
        return true;
      }
    }
    return false;
  }
}

// Calendar Notifier
class CalendarNotifier extends Notifier<CalendarState> {
  late final Dio _dio;
  String _currentYearMonth = '';

  @override
  CalendarState build() {
    _dio = ref.read(dioProvider);
    final enabled = DeviceCalendarService.isSyncEnabled();
    final holidayEnabled = DeviceCalendarService.isHolidayOverlayEnabled();
    return CalendarState(
      deviceCalendarEnabled: enabled,
      holidayOverlayEnabled: holidayEnabled,
    );
  }

  /// 현재 보고 있는 월의 데이터를 재조회 (소켓 실시간 동기화용).
  /// 캘린더 화면을 아직 열지 않았으면 현재 달 기준으로 조회.
  Future<void> refreshCurrentMonth() async {
    final ym = _currentYearMonth.isNotEmpty
        ? _currentYearMonth
        : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    await fetchEvents(ym);
  }

  /// 위젯에서 prev/next 네비게이션이 일어난 월(pending) + 현재 위젯 표시 월의
  /// device/holiday 캐시를 채운다. 위젯 익스텐션은 EventKit 권한이 없어 직접
  /// 채울 수 없으므로 앱이 포어그라운드 복귀 시 따라잡는 보완 흐름.
  Future<void> catchUpWidgetMissingMonths() async {
    try {
      final pending = await WidgetService.getPendingHydrationMonths();
      final extras = <String>{...pending};
      final widgetYm = await WidgetService.getDisplayedCalendarYearMonth();
      if (widgetYm != null && _isValidYearMonth(widgetYm)) {
        extras.add(widgetYm);
      }
      if (extras.isEmpty) return;

      final anchor = _currentYearMonth.isNotEmpty
          ? _currentYearMonth
          : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

      if (state.holidayOverlayEnabled) {
        await _fetchHolidayEventsForRange(anchor, extraMonths: extras);
      }
      if (state.deviceCalendarEnabled) {
        await _fetchDeviceEventsForRange(anchor, extraMonths: extras);
      }
      await WidgetService.clearPendingHydrationMonths();
    } catch (e) {
      debugPrint('[Widget] catchUpWidgetMissingMonths error: $e');
    }
  }

  /// Fetch events for a given year-month (e.g. '2026-02').
  Future<void> fetchEvents(String yearMonth) async {
    _currentYearMonth = yearMonth;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/calendar/$yearMonth');
      final data = response.data as Map<String, dynamic>;
      final events = (data['events'] as List<dynamic>)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      final rawMoods = data['moods'] as Map<String, dynamic>? ?? {};
      final moodMap = rawMoods.map((key, value) => MapEntry(
            key,
            (value as List<dynamic>)
                .map((e) =>
                    CalendarMood.fromJson(e as Map<String, dynamic>))
                .toList(),
          ));
      state = state.copyWith(events: events, moodMap: moodMap, isLoading: false);

      // 위젯 캘린더 데이터 갱신
      _updateWidgetCalendarEvents(events, yearMonth);

      // 기기 캘린더 연동
      if (state.deviceCalendarEnabled) {
        _fetchDeviceEventsForRange(yearMonth);
        _syncServerEventsToDevice(events);
      }

      // 공휴일 오버레이 (기기 캘린더 연동과 독립)
      // 위젯이 다른 월을 보고 있을 수 있어 range로 fetch.
      if (state.holidayOverlayEnabled) {
        _fetchHolidayEventsForRange(yearMonth);
      }
    } on DioException catch (e) {
      final message =
          extractDioErrorMessage(e, fallback: '일정을 불러오지 못했습니다');
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  // --- 기기 캘린더 연동 ---

  /// 기기 캘린더 동기화 토글 (권한은 UI에서 사전 처리)
  Future<void> toggleDeviceCalendar(bool enabled) async {
    if (enabled) {
      await DeviceCalendarService.setSyncEnabled(true);
      state = state.copyWith(deviceCalendarEnabled: true);
      // 위젯도 기기 캘린더 오버레이를 켜도록 알림
      await WidgetService.setDeviceCalendarEnabled(true);

      // 선택된 캘린더 없으면 전체 선택
      var ids = DeviceCalendarService.getSelectedCalendarIds();
      if (ids.isEmpty) {
        final calendars = await DeviceCalendarService.getCalendars();
        ids = calendars.map((c) => c.id!).toList();
        await DeviceCalendarService.saveSelectedCalendarIds(ids);
      }

      if (_currentYearMonth.isNotEmpty) {
        await _fetchDeviceEventsForRange(_currentYearMonth);
      }
    } else {
      await DeviceCalendarService.setSyncEnabled(false);
      state = state.copyWith(deviceCalendarEnabled: false, deviceEvents: []);
      // 위젯에서도 기기 캘린더 이벤트가 더 이상 병합되지 않도록 플래그 끄기.
      // 캐시된 per-month 데이터는 남아있어도 플래그가 false면 위젯이 무시함.
      await WidgetService.setDeviceCalendarEnabled(false);
      if (_currentYearMonth.isNotEmpty) {
        // 현재 달의 오버레이를 즉시 비워 깜빡임을 줄임.
        await WidgetService.updateDeviceCalendarEvents(
            const [], _currentYearMonth);
      }
    }
  }

  /// 캘린더 화면 최초 진입 시 1회 호출. 아직 한 번도 평가된 적 없고
  /// OS 권한이 (자동 요청으로) 허용되면 공휴일 오버레이를 기본 ON으로 켠다.
  /// 사용자가 이미 명시적으로 끈 적이 있거나 권한을 거부한 경우엔 아무 것도 안 함.
  Future<void> bootstrapHolidayOverlay() async {
    if (DeviceCalendarService.isHolidayOverlayInitialized()) {
      if (state.holidayOverlayEnabled && _currentYearMonth.isNotEmpty) {
        await _fetchHolidayEventsForRange(_currentYearMonth);
        await WidgetService.setHolidayOverlayEnabled(true);
      }
      return;
    }

    // 최초 평가: 권한을 (필요 시) 요청. 이미 허용돼 있으면 프롬프트 없이 true.
    final hasPerm = await DeviceCalendarService.hasPermission();
    final granted =
        hasPerm || await DeviceCalendarService.requestPermission();

    await DeviceCalendarService.setHolidayOverlayInitialized(true);
    if (granted) {
      await DeviceCalendarService.setHolidayOverlayEnabled(true);
      await WidgetService.setHolidayOverlayEnabled(true);
      state = state.copyWith(holidayOverlayEnabled: true);
      if (_currentYearMonth.isNotEmpty) {
        await _fetchHolidayEventsForRange(_currentYearMonth);
      }
    }
  }

  /// 공휴일 오버레이 on/off. 권한은 UI에서 사전 처리(거부 시 설정 이동).
  Future<void> toggleHolidayOverlay(bool enabled) async {
    await DeviceCalendarService.setHolidayOverlayInitialized(true);
    await DeviceCalendarService.setHolidayOverlayEnabled(enabled);
    state = state.copyWith(
      holidayOverlayEnabled: enabled,
      holidayEvents: enabled ? state.holidayEvents : const [],
    );
    await WidgetService.setHolidayOverlayEnabled(enabled);
    if (enabled) {
      if (_currentYearMonth.isNotEmpty) {
        await _fetchHolidayEventsForRange(_currentYearMonth);
      }
    } else if (_currentYearMonth.isNotEmpty) {
      // OFF: prefetch 반경 내 모든 월의 휴일 데이터를 위젯에서 비움.
      final months = await _buildPrefetchMonths(_currentYearMonth);
      for (final ym in months) {
        await WidgetService.updateHolidayEvents(const [], ym);
      }
    }
  }

  /// device_calendar 플러그인의 [dc.Event.start]에서 사용자가 의도한 "달력 날짜"를
  /// year/month/day로 추출한다.
  ///
  /// 두 가지 플랫폼 함정을 모두 처리:
  ///
  /// 1) Android allDay 시프트:
  ///    플러그인이 `device_calendar/lib/src/models/event.dart` 4.x에서
  ///    `Platform.isAndroid && allDay`인 경우 timezone offset만큼 timestamp를
  ///    빼버림. 로컬 자정 저장 캘린더(한국 OS 공휴일 등)는 전날로 밀린다.
  ///    → 같은 offset을 다시 더해 원본 timestamp 복원.
  ///
  /// 2) iOS floating allDay + timezone 패키지 미초기화:
  ///    iOS 플러그인은 floating 이벤트에 대해 timezone identifier를 nil로 보내고,
  ///    플러그인 Dart 코드는 `tz.local`로 fallback. 앱이 `tz.setLocalLocation()`을
  ///    호출하지 않았으면 `tz.local`은 UTC라서 TZDateTime이 UTC 기준이 됨.
  ///    `TZDateTime.toLocal()`은 location == _local이면 변환 안 하므로 UTC 그대로 반환.
  ///    → millisecondsSinceEpoch를 통해 Dart 표준 DateTime.toLocal()로 우회하여
  ///    OS의 실제 로컬 TZ로 변환.
  DateTime _normalizeEventStartDate(dc.Event e) {
    final raw = e.start ?? DateTime.now();
    final adjusted = (Platform.isAndroid && (e.allDay ?? false))
        ? raw.add(Duration(milliseconds: raw.timeZoneOffset.inMilliseconds))
        : raw;
    final asLocal = DateTime.fromMillisecondsSinceEpoch(
      adjusted.millisecondsSinceEpoch,
      isUtc: true,
    ).toLocal();
    return DateTime(asLocal.year, asLocal.month, asLocal.day);
  }

  /// 'yyyy-MM' 형식인지 검증
  bool _isValidYearMonth(String s) {
    final parts = s.split('-');
    if (parts.length != 2) return false;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return y != null && m != null && m >= 1 && m <= 12;
  }

  /// 'yyyy-MM'에 [delta]개월을 더한 'yyyy-MM' 반환
  String _shiftYearMonth(String yearMonth, int delta) {
    final parts = yearMonth.split('-');
    int y = int.parse(parts[0]);
    int m = int.parse(parts[1]) + delta;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    return '$y-${m.toString().padLeft(2, '0')}';
  }

  /// 위젯 prefetch 반경 (anchor / widgetYm 기준 ±N개월).
  /// 앱이 보고 있는 달 기준으로 ±N을 미리 캐시해 두면 사용자가 위젯에서 N칸까지
  /// 이동해도 device/holiday 데이터가 즉시 보인다. EventKit 호출이 가벼워 ±3 사용.
  static const int _widgetPrefetchRadius = 3;

  /// anchor / widget 표시 월 / 추가 월의 ±radius 합집합. 항상 anchor 자체 포함.
  Future<Set<String>> _buildPrefetchMonths(
    String anchorYearMonth, {
    Iterable<String> extraMonths = const [],
  }) async {
    final months = <String>{};
    void addRange(String center) {
      if (!_isValidYearMonth(center)) return;
      for (var i = -_widgetPrefetchRadius; i <= _widgetPrefetchRadius; i++) {
        months.add(_shiftYearMonth(center, i));
      }
    }

    addRange(anchorYearMonth);
    final widgetYm = await WidgetService.getDisplayedCalendarYearMonth();
    if (widgetYm != null && widgetYm.isNotEmpty) {
      addRange(widgetYm);
    }
    for (final ym in extraMonths) {
      if (_isValidYearMonth(ym)) months.add(ym);
    }
    return months;
  }

  /// 공휴일을 앵커 월 ±radius + 위젯이 표시 중인 월 ±radius + extraMonths 에 대해
  /// 모두 가져와 위젯에 월별 푸시 + 앱 state는 누적 결과로 한 번에 갱신.
  Future<void> _fetchHolidayEventsForRange(
    String anchorYearMonth, {
    Iterable<String> extraMonths = const [],
  }) async {
    try {
      final months = await _buildPrefetchMonths(
        anchorYearMonth,
        extraMonths: extraMonths,
      );

      final holidayCalendars =
          await DeviceCalendarService.getHolidayCalendars();
      if (holidayCalendars.isEmpty) {
        state = state.copyWith(holidayEvents: const []);
        for (final ym in months) {
          await WidgetService.updateHolidayEvents(const [], ym);
        }
        return;
      }

      final calendarIds =
          holidayCalendars.map((c) => c.id!).whereType<String>().toList();

      // 월별로 fetch → 위젯에는 그 월만 저장(per-month key), 앱 state에는 누적
      final all = <CalendarEvent>[];
      for (final ym in months) {
        final list = await _fetchHolidayEventsForMonth(ym, calendarIds);
        all.addAll(list);
      }
      state = state.copyWith(holidayEvents: all);
    } catch (e) {
      debugPrint('[Holidays] range fetch error: $e');
    }
  }

  /// 단일 월의 공휴일을 fetch해서 위젯의 per-month 키에 저장하고 리스트 반환.
  /// state는 건드리지 않음 — 호출자가 누적해서 한 번에 갱신해야 함.
  Future<List<CalendarEvent>> _fetchHolidayEventsForMonth(
    String yearMonth,
    List<String> calendarIds,
  ) async {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final rawEvents = await DeviceCalendarService.getEvents(
      calendarIds: calendarIds,
      start: start,
      end: end,
    );

    final holidayEvents = rawEvents.map((e) {
      final dateOnly = _normalizeEventStartDate(e);
      return CalendarEvent(
        id: 'holiday_${e.calendarId ?? ''}_${e.eventId ?? ''}',
        title: e.title ?? '',
        date: dateOnly,
        eventType: 'holiday',
        color: '#D32F2F',
      );
    }).toList();

    await WidgetService.updateHolidayEvents(
      holidayEvents
          .map((e) => {
                'date': DateFormat('yyyy-MM-dd').format(e.date),
                'title': e.title,
                'color': e.color ?? '#D32F2F',
                'isAnniversary': false,
                'eventType': 'holiday',
              })
          .toList(),
      yearMonth,
    );
    return holidayEvents;
  }

  /// 기기 캘린더 목록 조회
  Future<List<dc.Calendar>> getAvailableCalendars() async {
    return DeviceCalendarService.getCalendars();
  }

  /// 선택된 캘린더 ID 목록
  List<String> getSelectedCalendarIds() {
    return DeviceCalendarService.getSelectedCalendarIds();
  }

  /// 캘린더 선택/해제
  Future<void> toggleCalendarSelection(String calendarId, bool selected) async {
    final ids = List<String>.from(DeviceCalendarService.getSelectedCalendarIds());
    if (selected) {
      if (!ids.contains(calendarId)) ids.add(calendarId);
    } else {
      ids.remove(calendarId);
    }
    await DeviceCalendarService.saveSelectedCalendarIds(ids);

    if (_currentYearMonth.isNotEmpty) {
      await _fetchDeviceEventsForRange(_currentYearMonth);
    }
  }

  /// 기기 캘린더 이벤트를 prefetch 반경(±radius + 위젯월 + extras)에 대해 fetch.
  /// 위젯에는 월별 키로 푸시하고 앱 state에는 누적 결과로 갱신.
  Future<void> _fetchDeviceEventsForRange(
    String anchorYearMonth, {
    Iterable<String> extraMonths = const [],
  }) async {
    try {
      final months = await _buildPrefetchMonths(
        anchorYearMonth,
        extraMonths: extraMonths,
      );
      final calendarIds = DeviceCalendarService.getSelectedCalendarIds();

      if (calendarIds.isEmpty) {
        state = state.copyWith(deviceEvents: []);
        for (final ym in months) {
          await WidgetService.updateDeviceCalendarEvents(const [], ym);
        }
        return;
      }

      final all = <CalendarEvent>[];
      for (final ym in months) {
        all.addAll(await _fetchDeviceEventsForMonth(ym, calendarIds));
      }
      state = state.copyWith(deviceEvents: all);
    } catch (e) {
      debugPrint('[DeviceCalendar] range fetch error: $e');
    }
  }

  /// 단일 월의 기기 캘린더 이벤트를 fetch + 위젯 per-month 키로 푸시 후 리스트 반환.
  /// state는 건드리지 않음 — 호출자가 누적해서 한 번에 갱신.
  Future<List<CalendarEvent>> _fetchDeviceEventsForMonth(
    String yearMonth,
    List<String> calendarIds,
  ) async {
    try {
      final parts = yearMonth.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);

      final deviceEvents = await DeviceCalendarService.getEvents(
        calendarIds: calendarIds,
        start: start,
        end: end,
      );

      final calendarEvents = deviceEvents.map((e) {
        final dateOnly = _normalizeEventStartDate(e);
        return CalendarEvent(
          id: 'device_${e.eventId}',
          title: e.title ?? '(제목 없음)',
          date: dateOnly,
          description: e.description,
          eventType: 'device',
        );
      }).toList();

      await WidgetService.updateDeviceCalendarEvents(
        _toWidgetEventJson(calendarEvents),
        yearMonth,
      );
      return calendarEvents;
    } catch (e) {
      debugPrint('[DeviceCalendar] fetch month $yearMonth error: $e');
      return const [];
    }
  }

  /// [CalendarEvent] 리스트를 위젯이 읽기 편한 JSON-ish 맵 리스트로 변환.
  /// server events / device events 양쪽에서 재사용.
  List<Map<String, dynamic>> _toWidgetEventJson(List<CalendarEvent> events) {
    return events
        .where((e) => !e.isAuto)
        .map((e) => {
              'date': DateFormat('yyyy-MM-dd').format(e.date),
              'title': e.title,
              'color': e.color ??
                  _defaultColorForEventType(e.eventType, e.isAnniversary),
              'isAnniversary': e.isAnniversary,
              'eventType': e.eventType,
            })
        .toList();
  }

  /// 기본 쓰기 캘린더 ID
  String? getDefaultWriteCalendarId() {
    return DeviceCalendarService.getDefaultWriteCalendarId();
  }

  /// 기본 쓰기 캘린더 설정
  Future<void> setDefaultWriteCalendarId(String? id) async {
    await DeviceCalendarService.setDefaultWriteCalendarId(id);
  }

  /// 쓰기 가능한 캘린더 목록
  Future<List<dc.Calendar>> getWritableCalendars() async {
    return DeviceCalendarService.getWritableCalendars();
  }

  /// Create a new calendar event.
  Future<bool> createEvent({
    required String title,
    required DateTime date,
    String? description,
    bool? isAnniversary,
    String? repeatType,
    String? color,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/calendar', data: {
        'title': title,
        'date': DateFormat('yyyy-MM-dd').format(date),
        if (description != null) 'description': description,
        if (isAnniversary != null) 'isAnniversary': isAnniversary,
        if (repeatType != null) 'repeatType': repeatType,
        if (color != null) 'color': color,
      });

      final data = response.data as Map<String, dynamic>;
      final eventJson = data['event'] as Map<String, dynamic>? ?? data;
      final event = CalendarEvent.fromJson(eventJson);
      state = state.copyWith(
        events: [...state.events, event],
        isLoading: false,
      );

      // 위젯 캘린더 데이터 갱신
      if (_currentYearMonth.isNotEmpty) {
        _updateWidgetCalendarEvents(state.events, _currentYearMonth);
      }

      // 기기 캘린더에도 추가
      _syncToDeviceCalendar(event.id, title, date, description);

      return true;
    } on DioException catch (e) {
      final message =
          extractDioErrorMessage(e, fallback: '일정 생성에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  /// Update an existing calendar event.
  Future<bool> updateEvent({
    required String id,
    String? title,
    DateTime? date,
    String? description,
    bool? isAnniversary,
    String? repeatType,
    String? color,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.put('/calendar/$id', data: {
        if (title != null) 'title': title,
        if (date != null) 'date': DateFormat('yyyy-MM-dd').format(date),
        if (description != null) 'description': description,
        if (isAnniversary != null) 'isAnniversary': isAnniversary,
        if (repeatType != null) 'repeatType': repeatType,
        if (color != null) 'color': color,
      });

      final data = response.data as Map<String, dynamic>;
      final eventJson = data['event'] as Map<String, dynamic>? ?? data;
      final updatedEvent = CalendarEvent.fromJson(eventJson);
      final updatedEvents = state.events.map((event) {
        return event.id == id ? updatedEvent : event;
      }).toList();

      state = state.copyWith(events: updatedEvents, isLoading: false);

      // 위젯 캘린더 데이터 갱신
      if (_currentYearMonth.isNotEmpty) {
        _updateWidgetCalendarEvents(state.events, _currentYearMonth);
      }

      // 기기 캘린더에도 수정
      if (title != null && date != null) {
        _updateDeviceCalendarEvent(id, title, date, description);
      }

      return true;
    } on DioException catch (e) {
      // 404 = 이미 삭제된 일정 → 로컬에서 제거 + 새로고침
      if (e.response?.statusCode == 404) {
        final updatedEvents =
            state.events.where((event) => event.id != id).toList();
        state = state.copyWith(events: updatedEvents, isLoading: false);
        _deleteDeviceCalendarEvent(id);
        if (_currentYearMonth.isNotEmpty) {
          fetchEvents(_currentYearMonth);
        }
        return false;
      }
      final message =
          extractDioErrorMessage(e, fallback: '일정 수정에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  /// Delete a calendar event.
  Future<bool> deleteEvent(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.delete('/calendar/$id');
      final updatedEvents =
          state.events.where((event) => event.id != id).toList();
      state = state.copyWith(events: updatedEvents, isLoading: false);

      // 위젯 캘린더 데이터 갱신
      if (_currentYearMonth.isNotEmpty) {
        _updateWidgetCalendarEvents(state.events, _currentYearMonth);
      }

      // 기기 캘린더에서도 삭제
      _deleteDeviceCalendarEvent(id);

      return true;
    } on DioException catch (e) {
      // 404 = 이미 삭제됨 → 로컬에서도 제거 + 기기 캘린더 정리
      if (e.response?.statusCode == 404) {
        final updatedEvents =
            state.events.where((event) => event.id != id).toList();
        state = state.copyWith(events: updatedEvents, isLoading: false);
        _deleteDeviceCalendarEvent(id);
        return true;
      }
      final message =
          extractDioErrorMessage(e, fallback: '일정 삭제에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  // --- 상대방 일정 동기화 설정 ---

  bool isSyncPartnerEnabled() {
    return DeviceCalendarService.isSyncPartnerEnabled();
  }

  Future<void> setSyncPartnerEnabled(bool enabled) async {
    await DeviceCalendarService.setSyncPartnerEnabled(enabled);
    // 켜면 현재 월 서버 이벤트를 기기 캘린더에 동기화
    if (enabled && _currentYearMonth.isNotEmpty) {
      _syncServerEventsToDevice(state.events);
    }
  }

  // --- 기기 캘린더 쓰기 헬퍼 ---

  /// 서버 일정을 기기 캘린더에 동기화 (내 일정 + 상대방 일정)
  Future<void> _syncServerEventsToDevice(List<CalendarEvent> events) async {
    if (!state.deviceCalendarEnabled) return;
    final calendarId = DeviceCalendarService.getDefaultWriteCalendarId();
    if (calendarId == null || _currentYearMonth.isEmpty) return;

    final syncPartner = DeviceCalendarService.isSyncPartnerEnabled();
    final myUserId = ref.read(authProvider).user?.id;

    // 이번 달 동기화 대상 서버 이벤트 ID 수집
    final currentMonthIds = <String>{};
    for (final event in events) {
      if (event.isAuto || event.eventType == 'feed' || event.eventType == 'device') {
        continue;
      }
      if (!syncPartner && event.createdBy != myUserId) continue;
      currentMonthIds.add(event.id);
    }

    // 이전에 이번 달에 동기화했던 이벤트 중, 서버에서 사라진 것 삭제
    final prevSyncedIds =
        DeviceCalendarService.getSyncedIdsForMonth(_currentYearMonth);
    for (final appEventId in prevSyncedIds) {
      if (!currentMonthIds.contains(appEventId)) {
        final deviceEventId = DeviceCalendarService.getDeviceEventId(appEventId);
        if (deviceEventId != null) {
          await DeviceCalendarService.deleteEvent(
            calendarId: calendarId,
            eventId: deviceEventId,
          );
          await DeviceCalendarService.deleteEventMapping(appEventId);
        }
      }
    }

    // 새 이벤트 → 기기 캘린더에 추가
    final syncedIds = <String>[];
    for (final event in events) {
      if (event.isAuto || event.eventType == 'feed' || event.eventType == 'device') {
        continue;
      }
      if (!syncPartner && event.createdBy != myUserId) continue;

      syncedIds.add(event.id);

      // 이미 매핑된 이벤트는 스킵
      if (DeviceCalendarService.getDeviceEventId(event.id) != null) continue;

      final deviceEventId = await DeviceCalendarService.createEvent(
        calendarId: calendarId,
        title: event.title,
        date: event.date,
        description: event.description,
      );
      if (deviceEventId != null) {
        await DeviceCalendarService.saveEventMapping(event.id, deviceEventId);
      }
    }

    // 이번 달 동기화된 ID 목록 저장
    await DeviceCalendarService.saveSyncedIdsForMonth(
        _currentYearMonth, syncedIds);
  }

  Future<void> _syncToDeviceCalendar(
    String appEventId,
    String title,
    DateTime date,
    String? description,
  ) async {
    if (!state.deviceCalendarEnabled) return;
    final calendarId = DeviceCalendarService.getDefaultWriteCalendarId();
    if (calendarId == null) return;

    final deviceEventId = await DeviceCalendarService.createEvent(
      calendarId: calendarId,
      title: title,
      date: date,
      description: description,
    );
    if (deviceEventId != null) {
      await DeviceCalendarService.saveEventMapping(appEventId, deviceEventId);
    }
  }

  Future<void> _updateDeviceCalendarEvent(
    String appEventId,
    String title,
    DateTime date,
    String? description,
  ) async {
    if (!state.deviceCalendarEnabled) return;
    final calendarId = DeviceCalendarService.getDefaultWriteCalendarId();
    final deviceEventId = DeviceCalendarService.getDeviceEventId(appEventId);
    if (calendarId == null || deviceEventId == null) return;

    await DeviceCalendarService.updateEvent(
      calendarId: calendarId,
      eventId: deviceEventId,
      title: title,
      date: date,
      description: description,
    );
  }

  Future<void> _deleteDeviceCalendarEvent(String appEventId) async {
    final calendarId = DeviceCalendarService.getDefaultWriteCalendarId();
    final deviceEventId = DeviceCalendarService.getDeviceEventId(appEventId);
    if (calendarId == null || deviceEventId == null) return;

    await DeviceCalendarService.deleteEvent(
      calendarId: calendarId,
      eventId: deviceEventId,
    );
    await DeviceCalendarService.deleteEventMapping(appEventId);
  }

  /// 위젯 캘린더 이벤트 데이터 갱신
  ///
  /// 위젯의 이전/다음 달 이동을 지원하기 위해, 앱에서 조회한 모든 월의 이벤트를
  /// `calendarEvents_{yearMonth}` 키로 캐싱한다. 위젯 측에서는 표시 중인 달에
  /// 해당하는 키를 우선 읽고, 없으면 비워 둔다.
  Future<void> _updateWidgetCalendarEvents(
      List<CalendarEvent> events, String yearMonth) async {
    try {
      await WidgetService.updateCalendarEvents(
        _toWidgetEventJson(events),
        yearMonth,
      );
    } catch (e) {
      debugPrint('[Widget] updateCalendarEvents error: $e');
    }
  }

  static String _defaultColorForEventType(String eventType, bool isAnniversary) {
    if (isAnniversary) return '#E91E63'; // Pink
    switch (eventType) {
      case 'schedule':
        return '#1976D2'; // Blue
      case 'device':
        return '#4CAF50'; // Green
      case 'feed':
        return '#FF9800'; // Orange
      default:
        return '#E91E63'; // Pink
    }
  }

  /// Set the selected day.
  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: day);
  }
}

// Providers
final calendarProvider =
    NotifierProvider<CalendarNotifier, CalendarState>(
  CalendarNotifier.new,
);

final selectedDayEventsProvider = Provider<List<CalendarEvent>>((ref) {
  final calendarState = ref.watch(calendarProvider);
  final selectedDay = calendarState.selectedDay;
  if (selectedDay == null) return [];
  return calendarState.getEventsForDay(selectedDay);
});
