import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

class Mission {
  final String id;
  final String type; // DAILY, WEEKLY
  final String title;
  final String description;
  final String emoji;
  final DateTime date;
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;

  const Mission({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    required this.date,
    required this.isCompleted,
    this.completedBy,
    this.completedAt,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      emoji: json['emoji'] as String? ?? '\u{1F49D}',
      date: DateTime.parse(json['date'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedBy: json['completedBy'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}

class MissionState {
  static const _sentinel = Object();

  final Mission? daily;
  final Mission? weekly;
  final bool isLoading;
  final Map<String, List<Mission>> completedDates; // date string -> missions
  final String? error;

  const MissionState({
    this.daily,
    this.weekly,
    this.isLoading = false,
    this.completedDates = const {},
    this.error,
  });

  MissionState copyWith({
    Mission? daily,
    Mission? weekly,
    bool? isLoading,
    Map<String, List<Mission>>? completedDates,
    Object? error = _sentinel,
  }) {
    return MissionState(
      daily: daily ?? this.daily,
      weekly: weekly ?? this.weekly,
      isLoading: isLoading ?? this.isLoading,
      completedDates: completedDates ?? this.completedDates,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class MissionNotifier extends Notifier<MissionState> {
  late final Dio _dio;

  @override
  MissionState build() {
    _dio = ref.read(dioProvider);
    return const MissionState();
  }

  Future<void> fetchTodayMissions() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get('/mission');
      final data = response.data as Map<String, dynamic>;
      final daily = data['daily'] != null
          ? Mission.fromJson(data['daily'] as Map<String, dynamic>)
          : null;
      final weekly = data['weekly'] != null
          ? Mission.fromJson(data['weekly'] as Map<String, dynamic>)
          : null;
      state = MissionState(
        daily: daily,
        weekly: weekly,
        isLoading: false,
        completedDates: state.completedDates,
      );
    } catch (e) {
      debugPrint('[Mission] fetchTodayMissions error: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void applyTodaySummary(Map<String, dynamic>? data) {
    if (data == null) return;
    final daily = data['daily'] != null
        ? Mission.fromJson(data['daily'] as Map<String, dynamic>)
        : null;
    final weekly = data['weekly'] != null
        ? Mission.fromJson(data['weekly'] as Map<String, dynamic>)
        : null;
    state = MissionState(
      daily: daily,
      weekly: weekly,
      isLoading: false,
      completedDates: state.completedDates,
    );
  }

  Future<bool> completeMission(String missionId) async {
    try {
      final response = await _dio.patch('/mission/$missionId/complete');
      final data = response.data as Map<String, dynamic>;
      final updated = Mission.fromJson(data['mission'] as Map<String, dynamic>);
      if (updated.type == 'DAILY') {
        state = state.copyWith(daily: updated);
      } else {
        state = state.copyWith(weekly: updated);
      }
      _refreshCalendar();
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '미션 완료에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Mission] completeMission error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  Future<bool> cancelMission(String missionId) async {
    try {
      final response = await _dio.patch('/mission/$missionId/cancel');
      final data = response.data as Map<String, dynamic>;
      final updated = Mission.fromJson(data['mission'] as Map<String, dynamic>);
      if (updated.type == 'DAILY') {
        state = state.copyWith(daily: updated);
      } else {
        state = state.copyWith(weekly: updated);
      }
      _refreshCalendar();
      return true;
    } on DioException catch (e) {
      final message =
          ((e.response?.data is Map)
                  ? (e.response?.data['error'] ?? e.response?.data['message'])
                  : null)
              as String? ??
          '미션 취소에 실패했습니다.';
      state = state.copyWith(error: message);
      return false;
    } catch (e) {
      debugPrint('[Mission] cancelMission error: $e');
      state = state.copyWith(error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  /// 소켓으로 받은 미션 완료/취소 업데이트
  void updateMissionFromSocket(Mission mission) {
    if (mission.type == 'DAILY') {
      if (state.daily?.id == mission.id) {
        state = state.copyWith(daily: mission);
      }
    } else {
      if (state.weekly?.id == mission.id) {
        state = state.copyWith(weekly: mission);
      }
    }
    _refreshCalendar();
  }

  void _refreshCalendar() {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    fetchCalendarMissions(month);
  }

  Future<void> fetchCalendarMissions(String month) async {
    try {
      final response = await _dio.get(
        '/mission/calendar',
        queryParameters: {'month': month},
      );
      final data = response.data as Map<String, dynamic>;
      final rawDates = data['completedDates'] as Map<String, dynamic>? ?? {};
      debugPrint('[Mission] calendar raw: $rawDates');
      final completedDates = rawDates.map(
        (key, value) => MapEntry(
          key,
          (value as List)
              .map((e) => Mission.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      debugPrint(
        '[Mission] completedDates keys: ${completedDates.keys.toList()}',
      );
      state = state.copyWith(completedDates: completedDates);
    } catch (e) {
      debugPrint('[Mission] fetchCalendarMissions error: $e');
    }
  }
}

final missionProvider = NotifierProvider<MissionNotifier, MissionState>(
  MissionNotifier.new,
);
