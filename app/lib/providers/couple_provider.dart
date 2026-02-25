import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/couple.dart';
import 'auth_provider.dart';

// Couple state class
class CoupleState {
  final Couple? couple;
  final bool isLoading;
  final String? error;
  final String? generatedInviteCode;

  const CoupleState({
    this.couple,
    this.isLoading = false,
    this.error,
    this.generatedInviteCode,
  });

  CoupleState copyWith({
    Couple? couple,
    bool? isLoading,
    String? error,
    String? generatedInviteCode,
  }) {
    return CoupleState(
      couple: couple ?? this.couple,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      generatedInviteCode: generatedInviteCode ?? this.generatedInviteCode,
    );
  }
}

// Couple Notifier
class CoupleNotifier extends Notifier<CoupleState> {
  late final Dio _dio;

  @override
  CoupleState build() {
    _dio = ref.read(dioProvider);
    return const CoupleState();
  }

  /// Restore a pending invite code (e.g. from /auth/me on app restart).
  void restoreInviteCode(String code) {
    state = state.copyWith(generatedInviteCode: code);
  }

  /// Fetch the current couple info.
  Future<void> fetchCouple() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.get('/couple/info');
      final data = response.data as Map<String, dynamic>;
      final couple = Couple.fromJson(data['couple'] as Map<String, dynamic>);
      await ApiClient.saveCoupleId(couple.id);
      state = state.copyWith(couple: couple, isLoading: false);
    } on DioException catch (e) {
      final message = ((e.response?.data is Map) ? (e.response?.data['error'] ?? e.response?.data['message']) : null) as String? ?? '커플 정보를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  /// Create a new couple and get the invite code.
  Future<bool> createCouple({required DateTime startDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/couple/create', data: {
        'startDate': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T00:00:00.000Z',
      });

      final data = response.data as Map<String, dynamic>;
      final coupleData = data['couple'] as Map<String, dynamic>;
      final inviteCode = coupleData['inviteCode'] as String;
      final couple = Couple.fromJson(coupleData);

      // Don't update auth user's coupleId yet — partner hasn't joined.
      // Stay on couple-connect screen to show the invite code.
      state = state.copyWith(
        couple: couple,
        generatedInviteCode: inviteCode,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message = ((e.response?.data is Map) ? (e.response?.data['error'] ?? e.response?.data['message']) : null) as String? ?? '커플 생성에 실패했습니다';
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

  /// Join an existing couple with an invite code.
  Future<bool> joinCouple({required String inviteCode}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/couple/join', data: {
        'inviteCode': inviteCode,
      });

      final coupleData = (response.data as Map<String, dynamic>)['couple'] as Map<String, dynamic>;
      final couple = Couple.fromJson(coupleData);
      await ApiClient.saveCoupleId(couple.id);

      // Update the auth user with the couple ID
      final authNotifier = ref.read(authProvider.notifier);
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        authNotifier.updateUser(currentUser.copyWith(coupleId: couple.id, isCoupleComplete: true));
      }

      state = state.copyWith(couple: couple, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = ((e.response?.data is Map) ? (e.response?.data['error'] ?? e.response?.data['message']) : null) as String? ?? '커플 연결에 실패했습니다';
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

  /// Update the couple's start date.
  Future<bool> updateStartDate(DateTime newDate) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.patch('/couple/start-date', data: {
        'startDate': '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}T00:00:00.000Z',
      });

      // Refresh couple info to get updated data
      await fetchCouple();
      return true;
    } on DioException catch (e) {
      final message = ((e.response?.data is Map)
              ? (e.response?.data['error'] ?? e.response?.data['message'])
              : null) as String? ??
          '날짜 수정에 실패했습니다';
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

  /// Leave (disconnect) the current couple.
  Future<bool> leaveCouple() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.delete('/couple/leave');

      // Reset couple state
      state = const CoupleState();

      // Clear coupleId from auth user
      final authNotifier = ref.read(authProvider.notifier);
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        authNotifier.updateUser(
          currentUser.copyWith(
            coupleId: null,
            isCoupleComplete: false,
            hasExistingCoupleData: false,
          ),
        );
      }
      await ApiClient.saveCoupleId('');

      return true;
    } on DioException catch (e) {
      final message = ((e.response?.data is Map)
              ? (e.response?.data['error'] ?? e.response?.data['message'])
              : null) as String? ??
          '커플 해제에 실패했습니다';
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
final coupleProvider = NotifierProvider<CoupleNotifier, CoupleState>(
  CoupleNotifier.new,
);

final daysSinceStartProvider = Provider<int?>((ref) {
  final couple = ref.watch(coupleProvider).couple;
  if (couple == null) return null;
  return couple.daysTogether;
});
