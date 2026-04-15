import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/daily_question.dart';

class QuestionState {
  static const _sentinel = Object();

  final DailyQuestion? today;
  final List<QuestionHistoryItem> history;
  final bool isLoading;
  final bool isHistoryLoading;
  final String? error;
  final String? nextCursor;
  final bool hasMore;

  const QuestionState({
    this.today,
    this.history = const [],
    this.isLoading = false,
    this.isHistoryLoading = false,
    this.error,
    this.nextCursor,
    this.hasMore = true,
  });

  QuestionState copyWith({
    Object? today = _sentinel,
    List<QuestionHistoryItem>? history,
    bool? isLoading,
    bool? isHistoryLoading,
    Object? error = _sentinel,
    Object? nextCursor = _sentinel,
    bool? hasMore,
  }) {
    return QuestionState(
      today: identical(today, _sentinel)
          ? this.today
          : today as DailyQuestion?,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      nextCursor: identical(nextCursor, _sentinel)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class QuestionNotifier extends Notifier<QuestionState> {
  late final Dio _dio;

  @override
  QuestionState build() {
    _dio = ref.read(dioProvider);
    return const QuestionState();
  }

  Future<void> fetchToday() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _dio.get('/question/today');
      final data = response.data as Map<String, dynamic>;
      final question = DailyQuestion.fromJson(data);
      state = state.copyWith(today: question, isLoading: false, error: null);
    } catch (e) {
      debugPrint('[Question] fetchToday error: $e');
      state = state.copyWith(
        isLoading: false,
        error: '질문을 불러오는데 실패했습니다.',
      );
    }
  }

  Future<bool> submitAnswer(String answer) async {
    try {
      final response = await _dio.post('/question/today/answer', data: {
        'answer': answer,
      });
      final data = response.data as Map<String, dynamic>;
      final question = DailyQuestion.fromJson(data);
      state = state.copyWith(today: question);
      return true;
    } catch (e) {
      debugPrint('[Question] submitAnswer error: $e');
      return false;
    }
  }

  Future<void> fetchHistory({bool refresh = false}) async {
    if (state.isHistoryLoading) return;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isHistoryLoading: true);
    try {
      final params = <String, dynamic>{'limit': 20};
      if (!refresh && state.nextCursor != null) {
        params['cursor'] = state.nextCursor;
      }
      final response =
          await _dio.get('/question/history', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => QuestionHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final nextCursor = data['nextCursor'] as String?;

      if (refresh) {
        state = state.copyWith(
          history: items,
          nextCursor: nextCursor,
          hasMore: nextCursor != null,
          isHistoryLoading: false,
        );
      } else {
        state = state.copyWith(
          history: [...state.history, ...items],
          nextCursor: nextCursor,
          hasMore: nextCursor != null,
          isHistoryLoading: false,
        );
      }
    } catch (e) {
      debugPrint('[Question] fetchHistory error: $e');
      state = state.copyWith(isHistoryLoading: false);
    }
  }

  /// 소켓 이벤트: 파트너가 답변함
  void onPartnerAnswered() {
    fetchToday();
  }
}

final questionProvider = NotifierProvider<QuestionNotifier, QuestionState>(
  QuestionNotifier.new,
);
