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
      id: json['id'] as String,
      generalLuck: json['generalLuck'] as String,
      coupleLuck: json['coupleLuck'] as String,
      dateTip: json['dateTip'] as String,
      caution: json['caution'] as String,
      luckyScore: json['luckyScore'] as int,
      user1Id: json['user1Id'] as String?,
      user1Luck: json['user1Luck'] as String?,
      user2Id: json['user2Id'] as String?,
      user2Luck: json['user2Luck'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
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

  const FortuneState({
    this.fortune,
    this.isLoading = false,
    this.error,
  });

  FortuneState copyWith({
    Fortune? fortune,
    bool? isLoading,
    String? error,
  }) {
    return FortuneState(
      fortune: fortune ?? this.fortune,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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

  /// Fetch today's fortune.
  Future<void> fetchTodayFortune() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/fortune/today');
      final data = response.data as Map<String, dynamic>;
      final fortune =
          Fortune.fromJson(data['fortune'] as Map<String, dynamic>);
      state = state.copyWith(fortune: fortune, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '오늘의 운세를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }
}

// Providers
final fortuneProvider =
    NotifierProvider<FortuneNotifier, FortuneState>(
  FortuneNotifier.new,
);

final luckyScoreProvider = Provider<int?>((ref) {
  return ref.watch(fortuneProvider).fortune?.luckyScore;
});
