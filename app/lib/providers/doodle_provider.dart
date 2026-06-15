import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/doodle.dart';

class DoodleState {
  static const _sentinel = Object();

  final List<Doodle> doodles;
  final Doodle? latestReceived;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const DoodleState({
    this.doodles = const [],
    this.latestReceived,
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  DoodleState copyWith({
    List<Doodle>? doodles,
    Doodle? latestReceived,
    bool clearLatest = false,
    bool? isLoading,
    bool? isSending,
    Object? error = _sentinel,
  }) {
    return DoodleState(
      doodles: doodles ?? this.doodles,
      latestReceived: clearLatest
          ? null
          : (latestReceived ?? this.latestReceived),
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class DoodleNotifier extends Notifier<DoodleState> {
  late final Dio _dio;

  @override
  DoodleState build() {
    _dio = ref.read(dioProvider);
    return const DoodleState();
  }

  Future<void> fetchHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/doodle');
      final data = response.data as Map<String, dynamic>;
      final list = (data['doodles'] as List<dynamic>)
          .map((e) => Doodle.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(doodles: list, isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: extractDioErrorMessage(e, fallback: '그림 기록을 불러오지 못했습니다'),
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
    }
  }

  Future<void> fetchLatestReceived() async {
    try {
      final response = await _dio.get('/doodle/latest');
      final data = response.data as Map<String, dynamic>;
      final raw = data['doodle'];
      if (raw == null) {
        state = state.copyWith(clearLatest: true);
        return;
      }
      state = state.copyWith(
        latestReceived: Doodle.fromJson(raw as Map<String, dynamic>),
      );
    } catch (_) {
      // ignore — 위젯/홈 미리보기용이라 실패해도 조용히 무시
    }
  }

  void applyLatestReceived(Map<String, dynamic>? data) {
    final raw = data?['doodle'];
    if (raw == null) {
      state = state.copyWith(clearLatest: true);
      return;
    }
    state = state.copyWith(
      latestReceived: Doodle.fromJson(raw as Map<String, dynamic>),
    );
  }

  /// PNG 바이트로 그림을 전송한다. 성공 시 history 와 latest 도 갱신.
  Future<Doodle?> sendDoodle(Uint8List pngBytes, {bool quiet = false}) async {
    state = state.copyWith(isSending: true, error: null);
    try {
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          pngBytes,
          filename: 'doodle.png',
          contentType: DioMediaType('image', 'png'),
        ),
        'quiet': quiet.toString(),
      });
      final response = await _dio.post(
        '/doodle',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = response.data as Map<String, dynamic>;
      final doodle = Doodle.fromJson(data['doodle'] as Map<String, dynamic>);
      state = state.copyWith(
        doodles: [doodle, ...state.doodles],
        isSending: false,
      );
      return doodle;
    } on DioException catch (e) {
      state = state.copyWith(
        isSending: false,
        error: extractDioErrorMessage(e, fallback: '그림 전송에 실패했습니다'),
      );
      return null;
    } catch (_) {
      state = state.copyWith(isSending: false, error: '알 수 없는 오류가 발생했습니다');
      return null;
    }
  }

  Future<bool> deleteDoodle(String id) async {
    try {
      await _dio.delete('/doodle/$id');
      state = state.copyWith(
        doodles: state.doodles.where((d) => d.id != id).toList(),
        error: null,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

final doodleProvider = NotifierProvider<DoodleNotifier, DoodleState>(
  DoodleNotifier.new,
);
