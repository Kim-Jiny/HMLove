import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/diary_entry.dart';

class DiaryState {
  final Map<DiaryScope, List<DiaryEntry>> entries;
  final Set<DiaryScope> loading;
  final String? error;

  const DiaryState({
    this.entries = const {},
    this.loading = const {},
    this.error,
  });

  List<DiaryEntry> of(DiaryScope scope) => entries[scope] ?? const [];
}

class DiaryNotifier extends Notifier<DiaryState> {
  late Dio _dio;

  @override
  DiaryState build() {
    _dio = ref.read(dioProvider);
    return const DiaryState();
  }

  Future<void> fetch(DiaryScope scope) async {
    state = DiaryState(
      entries: state.entries,
      loading: {...state.loading, scope},
    );
    String? error;
    var next = state.entries;
    try {
      final res = await _dio.get(
        '/diary',
        queryParameters: {'scope': scope.value, 'limit': 50},
      );
      final list = (res.data['entries'] as List)
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      next = {...next, scope: list};
    } catch (e) {
      error = extractDioErrorMessage(e, fallback: '일기를 불러오지 못했어요');
    }
    state = DiaryState(
      entries: next,
      loading: {...state.loading}..remove(scope),
      error: error,
    );
  }

  /// 저장 후 null, 실패하면 에러 메시지.
  Future<String?> save({
    String? id,
    required DiaryKind kind,
    required String content,
    required DateTime entryDate,
    String? mood,
    DateTime? revealAt,
  }) async {
    final body = {
      'content': content,
      'entryDate': entryDate.toUtc().toIso8601String(),
      'mood': mood,
      if (kind == DiaryKind.private)
        'revealAt': revealAt?.toUtc().toIso8601String(),
    };
    try {
      if (id == null) {
        await _dio.post('/diary', data: {...body, 'kind': kind.value});
      } else {
        await _dio.patch('/diary/$id', data: body);
      }
      await fetch(
        kind == DiaryKind.shared ? DiaryScope.shared : DiaryScope.mine,
      );
      return null;
    } catch (e) {
      return extractDioErrorMessage(e, fallback: '일기를 저장하지 못했어요');
    }
  }

  Future<String?> delete(DiaryEntry entry) async {
    try {
      await _dio.delete('/diary/${entry.id}');
      await fetch(
        entry.kind == DiaryKind.shared ? DiaryScope.shared : DiaryScope.mine,
      );
      return null;
    } catch (e) {
      return extractDioErrorMessage(e, fallback: '일기를 삭제하지 못했어요');
    }
  }
}

final diaryProvider = NotifierProvider<DiaryNotifier, DiaryState>(
  DiaryNotifier.new,
);
