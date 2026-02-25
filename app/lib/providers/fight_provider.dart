import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Fight model
class Fight {
  final String id;
  final DateTime date;
  final String reason;
  final String? resolution;
  final String? reflection;
  final bool isResolved;
  final String coupleId;
  final String authorId;
  final String? authorNickname;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Fight({
    required this.id,
    required this.date,
    required this.reason,
    this.resolution,
    this.reflection,
    this.isResolved = false,
    required this.coupleId,
    required this.authorId,
    this.authorNickname,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Fight.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Fight(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      reason: json['reason'] as String,
      resolution: json['resolution'] as String?,
      reflection: json['reflection'] as String?,
      isResolved: json['isResolved'] as bool? ?? false,
      coupleId: json['coupleId'] as String,
      authorId: json['authorId'] as String,
      authorNickname: author?['nickname'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

// Fight state class
class FightState {
  final List<Fight> fights;
  final bool isLoading;
  final String? error;

  const FightState({
    this.fights = const [],
    this.isLoading = false,
    this.error,
  });

  FightState copyWith({
    List<Fight>? fights,
    bool? isLoading,
    String? error,
  }) {
    return FightState(
      fights: fights ?? this.fights,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Fight Notifier
class FightNotifier extends Notifier<FightState> {
  late final Dio _dio;

  @override
  FightState build() {
    _dio = ref.read(dioProvider);
    return const FightState();
  }

  /// Fetch fights. Optionally filter by resolved status.
  Future<void> fetchFights({bool? isResolved}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final queryParams = <String, dynamic>{
        if (isResolved != null) 'isResolved': isResolved,
      };

      final response =
          await _dio.get('/fight', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      final fights = (data['fights'] as List<dynamic>)
          .map((e) => Fight.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(fights: fights, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '다툼 기록을 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Create a new fight record.
  Future<bool> createFight({
    required DateTime date,
    required String reason,
    String? resolution,
    String? reflection,
    bool? isResolved,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/fight', data: {
        'date': date.toIso8601String(),
        'reason': reason,
        if (resolution != null) 'resolution': resolution,
        if (reflection != null) 'reflection': reflection,
        if (isResolved != null) 'isResolved': isResolved,
      });

      final data = response.data as Map<String, dynamic>;
      final fight = Fight.fromJson(data['fight'] as Map<String, dynamic>);
      state = state.copyWith(
        fights: [fight, ...state.fights],
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '다툼 기록 생성에 실패했습니다';
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

  /// Update an existing fight record.
  Future<bool> updateFight({
    required String id,
    DateTime? date,
    String? reason,
    String? resolution,
    String? reflection,
    bool? isResolved,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.put('/fight/$id', data: {
        if (date != null) 'date': date.toIso8601String(),
        if (reason != null) 'reason': reason,
        if (resolution != null) 'resolution': resolution,
        if (reflection != null) 'reflection': reflection,
        if (isResolved != null) 'isResolved': isResolved,
      });

      final data = response.data as Map<String, dynamic>;
      final updatedFight =
          Fight.fromJson(data['fight'] as Map<String, dynamic>);
      final updatedFights = state.fights.map((fight) {
        return fight.id == id ? updatedFight : fight;
      }).toList();

      state = state.copyWith(fights: updatedFights, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '다툼 기록 수정에 실패했습니다';
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

  /// Resolve a fight.
  Future<bool> resolveFight(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.patch('/fight/$id/resolve');
      final data = response.data as Map<String, dynamic>;
      final updatedFight =
          Fight.fromJson(data['fight'] as Map<String, dynamic>);
      final updatedFights = state.fights.map((fight) {
        return fight.id == id ? updatedFight : fight;
      }).toList();

      state = state.copyWith(fights: updatedFights, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '다툼 해결 처리에 실패했습니다';
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

  /// Delete a fight record.
  Future<bool> deleteFight(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.delete('/fight/$id');
      final updatedFights =
          state.fights.where((fight) => fight.id != id).toList();
      state = state.copyWith(fights: updatedFights, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['error'] as String? ?? '다툼 기록 삭제에 실패했습니다';
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
}

// Providers
final fightProvider = NotifierProvider<FightNotifier, FightState>(
  FightNotifier.new,
);

final unresolvedFightsProvider = Provider<List<Fight>>((ref) {
  final fights = ref.watch(fightProvider).fights;
  return fights.where((fight) => !fight.isResolved).toList();
});

final resolvedFightsProvider = Provider<List<Fight>>((ref) {
  final fights = ref.watch(fightProvider).fights;
  return fights.where((fight) => fight.isResolved).toList();
});
