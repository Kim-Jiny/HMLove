import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/poke.dart';

class PokeState {
  final bool isSending;
  final DateTime? lastSentAt;

  const PokeState({this.isSending = false, this.lastSentAt});

  PokeState copyWith({bool? isSending, DateTime? lastSentAt}) => PokeState(
        isSending: isSending ?? this.isSending,
        lastSentAt: lastSentAt ?? this.lastSentAt,
      );
}

/// 보낸 결과. [error] 가 null 이면 성공.
class PokeResult {
  final String? error;
  const PokeResult.ok() : error = null;
  const PokeResult.fail(String this.error);
  bool get ok => error == null;
}

class PokeNotifier extends Notifier<PokeState> {
  late Dio _dio;

  // 같은 콕을 앱에서 두 번(소켓/푸시) 받아도 한 번만 보여주기 위한 최근 id.
  final _seen = <String>[];

  @override
  PokeState build() {
    _dio = ref.read(dioProvider);
    return const PokeState();
  }

  /// 상대에게 콕을 보낸다. 연타는 앱에서 먼저 막고(1.5초), 서버도 분당 8회로 제한한다.
  Future<PokeResult> send(PokeKind kind) async {
    final last = state.lastSentAt;
    if (state.isSending ||
        (last != null &&
            DateTime.now().difference(last) < const Duration(milliseconds: 1500))) {
      return const PokeResult.fail('조금만 천천히 보내주세요');
    }
    state = state.copyWith(isSending: true);
    try {
      await _dio.post('/poke', data: {'kind': kind.key});
      state = state.copyWith(isSending: false, lastSentAt: DateTime.now());
      return const PokeResult.ok();
    } on DioException catch (e) {
      state = state.copyWith(isSending: false);
      return PokeResult.fail(
        extractDioErrorMessage(e, fallback: '콕을 보내지 못했어요'),
      );
    } catch (_) {
      state = state.copyWith(isSending: false);
      return const PokeResult.fail('콕을 보내지 못했어요');
    }
  }

  /// 이미 보여준 콕인지 확인하고 기록한다. true 면 새 콕(보여줘야 함).
  bool markSeen(String? pokeId) {
    if (pokeId == null || pokeId.isEmpty) return true;
    if (_seen.contains(pokeId)) return false;
    _seen.add(pokeId);
    if (_seen.length > 20) _seen.removeAt(0);
    return true;
  }
}

final pokeProvider = NotifierProvider<PokeNotifier, PokeState>(
  PokeNotifier.new,
);
