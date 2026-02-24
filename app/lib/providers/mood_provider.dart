import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Mood model
class Mood {
  final String id;
  final String emoji;
  final String? message;
  final String userId;
  final String? nickname;
  final DateTime createdAt;

  const Mood({
    required this.id,
    required this.emoji,
    this.message,
    required this.userId,
    this.nickname,
    required this.createdAt,
  });

  factory Mood.fromJson(Map<String, dynamic> json) {
    return Mood(
      id: json['id'] as String,
      emoji: json['emoji'] as String,
      message: json['message'] as String?,
      userId: json['userId'] as String,
      nickname: json['nickname'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'message': message,
      'userId': userId,
      'nickname': nickname,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Mood state class
class MoodState {
  final Mood? myMood;
  final Mood? partnerMood;
  final bool isLoading;
  final String? error;

  const MoodState({
    this.myMood,
    this.partnerMood,
    this.isLoading = false,
    this.error,
  });

  MoodState copyWith({
    Mood? myMood,
    Mood? partnerMood,
    bool? isLoading,
    String? error,
  }) {
    return MoodState(
      myMood: myMood ?? this.myMood,
      partnerMood: partnerMood ?? this.partnerMood,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Mood Notifier
class MoodNotifier extends Notifier<MoodState> {
  late final Dio _dio;

  @override
  MoodState build() {
    _dio = ref.read(dioProvider);
    return const MoodState();
  }

  /// Fetch today's mood for both the user and partner.
  Future<void> fetchTodayMood() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/mood/today');
      final data = response.data as Map<String, dynamic>;
      final moods = data['moods'] as List<dynamic>;
      final currentUserId = ApiClient.getUserId();

      Mood? myMood;
      Mood? partnerMood;
      for (final m in moods) {
        final moodData = m as Map<String, dynamic>;
        final user = moodData['user'] as Map<String, dynamic>?;
        final mood = Mood.fromJson({
          ...moodData,
          if (user != null) 'nickname': user['nickname'],
        });
        if (mood.userId == currentUserId) {
          myMood = mood;
        } else {
          partnerMood = mood;
        }
      }

      state = state.copyWith(
        myMood: myMood,
        partnerMood: partnerMood,
        isLoading: false,
      );
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '기분 정보를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Set today's mood.
  Future<bool> setMood({
    required String emoji,
    String? message,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/mood', data: {
        'emoji': emoji,
        if (message != null) 'message': message,
      });

      final moodData = (response.data as Map<String, dynamic>)['mood'] as Map<String, dynamic>;
      final user = moodData['user'] as Map<String, dynamic>?;
      final mood = Mood.fromJson({
        ...moodData,
        if (user != null) 'nickname': user['nickname'],
      });
      state = state.copyWith(myMood: mood, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '기분 설정에 실패했습니다';
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
final moodProvider = NotifierProvider<MoodNotifier, MoodState>(
  MoodNotifier.new,
);
