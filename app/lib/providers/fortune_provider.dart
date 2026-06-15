import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Fortune model
class Fortune {
  final String id;
  final String generalLuck;
  final String coupleLuck;
  final String dateTip;
  final String caution;
  final int luckyScore;
  final String? user1Id;
  final String? user1Luck;
  final String? user2Id;
  final String? user2Luck;
  final DateTime date;
  final DateTime createdAt;

  const Fortune({
    required this.id,
    required this.generalLuck,
    required this.coupleLuck,
    required this.dateTip,
    required this.caution,
    required this.luckyScore,
    this.user1Id,
    this.user1Luck,
    this.user2Id,
    this.user2Luck,
    required this.date,
    required this.createdAt,
  });

  factory Fortune.fromJson(Map<String, dynamic> json) {
    return Fortune(
      id: json['id'] as String? ?? '',
      generalLuck: json['generalLuck'] as String? ?? '',
      coupleLuck: json['coupleLuck'] as String? ?? '',
      dateTip: json['dateTip'] as String? ?? '',
      caution: json['caution'] as String? ?? '',
      luckyScore: (json['luckyScore'] as num?)?.toInt() ?? 0,
      user1Id: json['user1Id'] as String?,
      user1Luck: json['user1Luck'] as String?,
      user2Id: json['user2Id'] as String?,
      user2Luck: json['user2Luck'] as String?,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'generalLuck': generalLuck,
      'coupleLuck': coupleLuck,
      'dateTip': dateTip,
      'caution': caution,
      'luckyScore': luckyScore,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Fortune state class
class FortuneState {
  final Fortune? fortune;
  final bool isLoading;
  final String? error;
  final bool? exists; // null=미확인, true/false=확인됨

  const FortuneState({
    this.fortune,
    this.isLoading = false,
    this.error,
    this.exists,
  });

  FortuneState copyWith({
    Fortune? fortune,
    bool? isLoading,
    String? error,
    bool? exists,
  }) {
    return FortuneState(
      fortune: fortune ?? this.fortune,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      exists: exists ?? this.exists,
    );
  }
}

// Fortune Notifier
class FortuneNotifier extends Notifier<FortuneState> {
  late final Dio _dio;

  @override
  FortuneState build() {
    _dio = ref.read(dioProvider);
    return const FortuneState();
  }

  /// Check today's fortune (GET, 확인만)
  void applyTodaySummary(Map<String, dynamic>? data) {
    if (data == null) return;
    final exists = data['exists'] as bool? ?? false;
    final raw = data['fortune'];
    state = FortuneState(
      fortune: raw != null
          ? Fortune.fromJson(raw as Map<String, dynamic>)
          : null,
      isLoading: false,
      exists: exists,
    );
  }

  /// Check today's fortune (GET, 확인만)
  Future<void> checkTodayFortune() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get(
        '/fortune/today',
        queryParameters: {'check': 'true'},
      );
      final data = response.data as Map<String, dynamic>;
      final exists = data['exists'] as bool;

      if (exists && data['fortune'] != null) {
        final fortune = Fortune.fromJson(
          data['fortune'] as Map<String, dynamic>,
        );
        state = FortuneState(fortune: fortune, isLoading: false, exists: true);
      } else {
        state = const FortuneState(
          fortune: null,
          isLoading: false,
          exists: false,
        );
      }
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '오늘의 운세를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
    }
  }

  /// Generate today's fortune (POST, 생성)
  Future<void> generateFortune() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/fortune/today');
      final data = response.data as Map<String, dynamic>;
      final fortune = Fortune.fromJson(data['fortune'] as Map<String, dynamic>);
      state = FortuneState(fortune: fortune, isLoading: false, exists: true);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '운세 생성에 실패했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
    }
  }
}

// Providers
final fortuneProvider = NotifierProvider<FortuneNotifier, FortuneState>(
  FortuneNotifier.new,
);

final luckyScoreProvider = Provider<int?>((ref) {
  return ref.watch(fortuneProvider).fortune?.luckyScore;
});
