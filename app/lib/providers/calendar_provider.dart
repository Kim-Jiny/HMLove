import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Calendar Event model
class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final String? description;
  final bool isAnniversary;
  final String? repeatType;
  final String? color;
  final String coupleId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.description,
    this.isAnniversary = false,
    this.repeatType,
    this.color,
    required this.coupleId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
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
      coupleId: json['coupleId'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'isAnniversary': isAnniversary,
      'repeatType': repeatType,
      'color': color,
      'coupleId': coupleId,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Calendar state class
class CalendarState {
  final List<CalendarEvent> events;
  final DateTime? selectedDay;
  final bool isLoading;
  final String? error;

  const CalendarState({
    this.events = const [],
    this.selectedDay,
    this.isLoading = false,
    this.error,
  });

  CalendarState copyWith({
    List<CalendarEvent>? events,
    DateTime? selectedDay,
    bool? isLoading,
    String? error,
  }) {
    return CalendarState(
      events: events ?? this.events,
      selectedDay: selectedDay ?? this.selectedDay,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get events for a specific day.
  List<CalendarEvent> getEventsForDay(DateTime day) {
    return events.where((event) {
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList();
  }
}

// Calendar Notifier
class CalendarNotifier extends Notifier<CalendarState> {
  late final Dio _dio;

  @override
  CalendarState build() {
    _dio = ref.read(dioProvider);
    return const CalendarState();
  }

  /// Fetch events for a given year-month (e.g. '2026-02').
  Future<void> fetchEvents(String yearMonth) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/calendar/$yearMonth');
      final data = response.data as Map<String, dynamic>;
      final events = (data['events'] as List<dynamic>)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(events: events, isLoading: false);
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
        'date': date.toIso8601String(),
        if (description != null) 'description': description,
        if (isAnniversary != null) 'isAnniversary': isAnniversary,
        if (repeatType != null) 'repeatType': repeatType,
        if (color != null) 'color': color,
      });

      final event =
          CalendarEvent.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        events: [...state.events, event],
        isLoading: false,
      );
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
        if (date != null) 'date': date.toIso8601String(),
        if (description != null) 'description': description,
        if (isAnniversary != null) 'isAnniversary': isAnniversary,
        if (repeatType != null) 'repeatType': repeatType,
        if (color != null) 'color': color,
      });

      final updatedEvent =
          CalendarEvent.fromJson(response.data as Map<String, dynamic>);
      final updatedEvents = state.events.map((event) {
        return event.id == id ? updatedEvent : event;
      }).toList();

      state = state.copyWith(events: updatedEvents, isLoading: false);
      return true;
    } on DioException catch (e) {
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
      return true;
    } on DioException catch (e) {
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
