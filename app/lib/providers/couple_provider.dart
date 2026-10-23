import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_error.dart';
import '../models/couple.dart';
import 'auth_provider.dart';

// Couple state class
class CoupleState {
  static const _sentinel = Object();

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
    Object? error = _sentinel,
    String? generatedInviteCode,
  }) {
    return CoupleState(
      couple: couple ?? this.couple,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      generatedInviteCode: generatedInviteCode ?? this.generatedInviteCode,
    );
  }
}

// Couple Notifier
class CoupleNotifier extends Notifier<CoupleState> {
  late Dio _dio;

  @override
  CoupleState build() {
    _dio = ref.read(dioProvider);
    return const CoupleState();
  }

  /// Restore a pending invite code (e.g. from /auth/me on app restart).
  void restoreInviteCode(String code) {
    state = state.copyWith(generatedInviteCode: code);
  }

  Future<void> applySummary(Map<String, dynamic>? data) async {
    if (data == null) return;
    final couple = Couple.fromJson(data);
    await ApiClient.saveCoupleId(couple.id);
    state = state.copyWith(couple: couple, isLoading: false, error: null);
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
      final message = extractDioErrorMessage(e, fallback: '커플 정보를 불러오지 못했습니다');
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
    }
  }

  /// Create a new couple and get the invite code.
  Future<bool> createCouple({required DateTime startDate}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post(
        '/couple/create',
        data: {
          'startDate':
              '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T00:00:00.000Z',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final coupleData = data['couple'] as Map<String, dynamic>;
      final inviteCode = coupleData['inviteCode'] as String;
      final couple = Couple.fromJson(coupleData);

      // 상대가 아직 합류하지 않았어도 커플이 생겼으므로 바로 메인에 들어간다.
      // (router 가 coupleId 를 보고 /home 으로 보낸다. 초대 코드는 홈/더보기에서 확인)
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref
            .read(authProvider.notifier)
            .updateUser(currentUser.copyWith(coupleId: couple.id));
      }
      state = state.copyWith(
        couple: couple,
        generatedInviteCode: inviteCode,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message = extractDioErrorMessage(e, fallback: '커플 생성에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
      return false;
    }
  }

  /// 상대가 아직 앱을 설치하기 전에 먼저 시작한다. 이후 초대 코드로 상대를 연결할 수 있다.
  Future<bool> startWithoutPartner({
    required DateTime startDate,
    String? partnerName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post(
        '/couple/create',
        data: {
          'solo': true,
          if (partnerName != null && partnerName.trim().isNotEmpty)
            'partnerName': partnerName.trim(),
          'startDate':
              '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T00:00:00.000Z',
        },
      );
      final coupleData =
          (response.data as Map<String, dynamic>)['couple']
              as Map<String, dynamic>;
      final couple = Couple.fromJson(coupleData);
      await ApiClient.saveCoupleId(couple.id);

      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        // router redirect 가 이 변경을 보고 /home 으로 보낸다.
        ref
            .read(authProvider.notifier)
            .updateUser(
              currentUser.copyWith(coupleId: couple.id, isSolo: true),
            );
      }

      state = state.copyWith(couple: couple, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = extractDioErrorMessage(e, fallback: '시작하지 못했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
      return false;
    }
  }

  /// 상대 연결 전 미리 적어둔 이름/애칭을 수정한다. 빈 문자열이면 지운다.
  Future<bool> updatePartnerName(String name) async {
    try {
      final res = await _dio.patch(
        '/couple/partner-name',
        data: {'partnerName': name},
      );
      final saved =
          (res.data as Map<String, dynamic>)['pendingPartnerName'] as String?;
      final couple = state.couple;
      if (couple != null) {
        // copyWith 는 null 로 지우지 못하므로 새 인스턴스로 교체한다.
        state = state.copyWith(
          couple: Couple(
            id: couple.id,
            inviteCode: couple.inviteCode,
            startDate: couple.startDate,
            pendingPartnerName: saved,
            users: couple.users,
            createdAt: couple.createdAt,
            updatedAt: couple.updatedAt,
          ),
        );
      }
      return true;
    } on DioException {
      return false;
    }
  }

  /// Join an existing couple with an invite code.
  Future<bool> joinCouple({required String inviteCode}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post(
        '/couple/join',
        data: {'inviteCode': inviteCode},
      );

      final coupleData =
          (response.data as Map<String, dynamic>)['couple']
              as Map<String, dynamic>;
      final couple = Couple.fromJson(coupleData);
      await ApiClient.saveCoupleId(couple.id);

      // Update the auth user with the couple ID
      final authNotifier = ref.read(authProvider.notifier);
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        authNotifier.updateUser(
          currentUser.copyWith(
            coupleId: couple.id,
            isCoupleComplete: true,
            isSolo: false,
          ),
        );
      }

      state = state.copyWith(couple: couple, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = extractDioErrorMessage(e, fallback: '커플 연결에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
      return false;
    }
  }

  /// Update the couple's start date.
  Future<bool> updateStartDate(DateTime newDate) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.patch(
        '/couple/start-date',
        data: {
          'startDate':
              '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}T00:00:00.000Z',
        },
      );

      // Refresh couple info to get updated data
      await fetchCouple();
      return true;
    } on DioException catch (e) {
      final message = extractDioErrorMessage(e, fallback: '날짜 수정에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
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
            isSolo: false,
            hasExistingCoupleData: false,
          ),
        );
      }
      await ApiClient.saveCoupleId('');

      return true;
    } on DioException catch (e) {
      final message = extractDioErrorMessage(e, fallback: '커플 해제에 실패했습니다');
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
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
