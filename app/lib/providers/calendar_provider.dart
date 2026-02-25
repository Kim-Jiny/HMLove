import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/device_calendar_service.dart';
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
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime.parse(json['date'] as String),
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
  final Map<String, List<CalendarMood>> moodMap;
  final DateTime? selectedDay;
  final bool isLoading;
  final String? error;
  final bool deviceCalendarEnabled;

  const CalendarState({
    this.events = const [],
    this.deviceEvents = const [],
    this.moodMap = const {},
    this.selectedDay,
    this.isLoading = false,
    this.error,
    this.deviceCalendarEnabled = false,
  });

  CalendarState copyWith({
    List<CalendarEvent>? events,
    List<CalendarEvent>? deviceEvents,
    Map<String, List<CalendarMood>>? moodMap,
    DateTime? selectedDay,
    bool? isLoading,
    String? error,
    bool? deviceCalendarEnabled,
  }) {
    return CalendarState(
      events: events ?? this.events,
      deviceEvents: deviceEvents ?? this.deviceEvents,
      moodMap: moodMap ?? this.moodMap,
      selectedDay: selectedDay ?? this.selectedDay,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      deviceCalendarEnabled: deviceCalendarEnabled ?? this.deviceCalendarEnabled,
    );
  }

  /// Get moods for a specific day.
  List<CalendarMood> getMoodsForDay(DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return moodMap[key] ?? [];
  }

  /// Get events for a specific day (app + device).
  List<CalendarEvent> getEventsForDay(DateTime day) {
    final allEvents = [...events, ...deviceEvents];
    return allEvents.where((event) {
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList();
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
    return CalendarState(deviceCalendarEnabled: enabled);
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

      // 기기 캘린더 연동
      if (state.deviceCalendarEnabled) {
        _fetchDeviceEvents(yearMonth);
        _syncServerEventsToDevice(events);
      }
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '일정을 불러오지 못했습니다';
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

      // 선택된 캘린더 없으면 전체 선택
      var ids = DeviceCalendarService.getSelectedCalendarIds();
      if (ids.isEmpty) {
        final calendars = await DeviceCalendarService.getCalendars();
        ids = calendars.map((c) => c.id!).toList();
        await DeviceCalendarService.saveSelectedCalendarIds(ids);
      }

      if (_currentYearMonth.isNotEmpty) {
        await _fetchDeviceEvents(_currentYearMonth);
      }
    } else {
      await DeviceCalendarService.setSyncEnabled(false);
      state = state.copyWith(deviceCalendarEnabled: false, deviceEvents: []);
    }
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
      await _fetchDeviceEvents(_currentYearMonth);
    }
  }

  /// 기기 캘린더 이벤트 가져오기
  Future<void> _fetchDeviceEvents(String yearMonth) async {
    try {
      final calendarIds = DeviceCalendarService.getSelectedCalendarIds();
      if (calendarIds.isEmpty) {
        state = state.copyWith(deviceEvents: []);
        return;
      }

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
        final eventDate = e.start ?? DateTime.now();
        return CalendarEvent(
          id: 'device_${e.eventId}',
          title: e.title ?? '(제목 없음)',
          date: eventDate,
          description: e.description,
          eventType: 'device',
        );
      }).toList();

      state = state.copyWith(deviceEvents: calendarEvents);
    } catch (e) {
      debugPrint('[DeviceCalendar] fetchDeviceEvents error: $e');
    }
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

      // 기기 캘린더에도 추가
      _syncToDeviceCalendar(event.id, title, date, description);

      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '일정 생성에 실패했습니다';
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
          e.response?.data?['message'] as String? ?? '일정 수정에 실패했습니다';
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
          e.response?.data?['message'] as String? ?? '일정 삭제에 실패했습니다';
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
