import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/pending_route.dart';
import '../core/push_notification_service.dart';
import '../core/social_auth_service.dart';
import '../core/widget_service.dart';
import '../models/user.dart';
import 'chat_provider.dart';
import 'couple_provider.dart';
import 'session_reset.dart';

// Auth state enum
enum AuthStatus { initial, authenticated, unauthenticated }

/// 소셜 로그인 시도 결과를 LoginScreen 에 전달하기 위한 sealed-style 타입.
sealed class SocialLoginOutcome {
  const SocialLoginOutcome();
}

/// 가입 완료된 유저 → 바로 로그인됨 (state 가 이미 authenticated 로 갱신).
class SocialLoginSuccess extends SocialLoginOutcome {
  final User user;
  const SocialLoginSuccess(this.user);
}

/// 같은 이메일의 일반 계정이 이미 존재 → 사용자가 그쪽으로 로그인 후 연동.
class SocialLoginEmailExists extends SocialLoginOutcome {
  final String email;
  final SocialProvider provider;
  const SocialLoginEmailExists({required this.email, required this.provider});
}

/// 신규 유저 → 닉네임/생일 입력 화면으로 이동.
class SocialLoginNeedsSignup extends SocialLoginOutcome {
  final String signupToken;
  final SocialProvider provider;
  final String? suggestedName;
  final String? email;
  final String? picture;
  const SocialLoginNeedsSignup({
    required this.signupToken,
    required this.provider,
    this.suggestedName,
    this.email,
    this.picture,
  });
}

/// 사용자 취소 또는 일반 에러 — error 메시지를 표시.
class SocialLoginFailure extends SocialLoginOutcome {
  final String message;
  final bool cancelled;
  const SocialLoginFailure(this.message, {this.cancelled = false});
}

// Auth state class
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final bool isLoading;

  /// One-shot message shown on the login screen after a forced logout
  /// (e.g. "서버에 연결할 수 없습니다"). Cleared by [AuthNotifier.consumeForceLogoutReason].
  final String? forceLogoutReason;

  /// 신규 소셜 가입을 진행 중인 사용자의 임시 정보. /social-signup 라우트가
  /// 이 값을 읽음. GoRouter 의 state.extra 는 router refresh 시 손실될 수
  /// 있어서 Riverpod 으로 보관한다.
  final SocialLoginNeedsSignup? pendingSocialSignup;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
    this.forceLogoutReason,
    this.pendingSocialSignup,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
    String? forceLogoutReason,
    SocialLoginNeedsSignup? pendingSocialSignup,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      forceLogoutReason: forceLogoutReason ?? this.forceLogoutReason,
      pendingSocialSignup: pendingSocialSignup ?? this.pendingSocialSignup,
    );
  }
}

// Auth Notifier
class AuthNotifier extends Notifier<AuthState> {
  late final Dio _dio;

  @override
  AuthState build() {
    _dio = ref.read(dioProvider);
    return const AuthState();
  }

  /// Safely clear tokens, ignoring errors (e.g. Hive not initialized).
  Future<void> _safeClearTokens() async {
    try {
      await ApiClient.clearTokens();
      await WidgetService.clearData();
    } catch (_) {
      // Hive may not be open — ignore so the caller can still set state.
    }
  }

  /// Force the auth state to unauthenticated. Used as a safety net when
  /// checkAuthStatus fails with an unrecoverable error.
  void forceUnauthenticated() {
    if (state.status != AuthStatus.initial) return;
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// Check if user is already authenticated. Called on app startup (from the
  /// splash screen) and on app resume (from the root widget observer).
  ///
  /// Error handling strategy:
  ///   • 401/403 → auth is genuinely rejected → clear tokens, logout.
  ///   • Network error / timeout / 5xx (no response, or no status code) →
  ///     the server is temporarily unreachable, NOT an auth problem. Leave
  ///     the session alone so the user can keep using the app when the
  ///     server recovers.
  ///   • Any other error on startup (status == initial) → fall back to the
  ///     original conservative behavior: clear tokens so the user sees /login
  ///     instead of a stuck splash.
  Future<void> checkAuthStatus() async {
    final token = ApiClient.getAccessToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final wasAuthenticated = state.status == AuthStatus.authenticated;

    try {
      final response = await _dio.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      final user = User.fromJson(data);
      await ApiClient.saveUserId(user.id);
      if (user.coupleId != null) {
        await ApiClient.saveCoupleId(user.coupleId!);
      }

      // Restore pending invite code if couple exists but partner hasn't joined
      final pendingInviteCode = data['pendingInviteCode'] as String?;
      if (pendingInviteCode != null) {
        ref.read(coupleProvider.notifier).restoreInviteCode(pendingInviteCode);
      }

      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      // While this method was awaiting /auth/me the Dio interceptor may have
      // already run the 401-refresh-failed path, which triggers forceLogout
      // and sets both the unauthenticated status AND a forceLogoutReason.
      // Respect that and exit — otherwise we'd overwrite the reason with null.
      if (state.status == AuthStatus.unauthenticated &&
          state.forceLogoutReason != null) {
        return;
      }

      final code = e.response?.statusCode;
      final isAuthDenied = code == 401 || code == 403;

      if (isAuthDenied) {
        await _safeClearTokens();
        state = AuthState(
          status: AuthStatus.unauthenticated,
          forceLogoutReason: wasAuthenticated
              ? '세션이 만료되었어요. 다시 로그인해주세요.'
              : null,
        );
        return;
      }

      // Network-level failure (timeout, connection refused, 5xx, no status).
      if (wasAuthenticated) {
        // Mid-session re-check: server is temporarily down. Do NOT touch the
        // session — the user stays logged in and can retry when the server
        // comes back. Individual screens will show their own error states.
        return;
      }

      // Startup check with a network error — keep the original conservative
      // behavior so the user sees /login instead of a stuck splash.
      await _safeClearTokens();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    } catch (_) {
      // Same race guard as above.
      if (state.status == AuthStatus.unauthenticated &&
          state.forceLogoutReason != null) {
        return;
      }

      // Non-Dio error (parse error, Hive error, etc.). Treat as auth-dead
      // only on startup; leave mid-session users alone.
      if (wasAuthenticated) return;
      await _safeClearTokens();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Login with email and password.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      await ApiClient.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      final userData = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      await ApiClient.saveUserId(user.id);
      if (user.coupleId != null) {
        await ApiClient.saveCoupleId(user.coupleId!);
      }

      // Restore pending invite code if couple exists but partner hasn't joined
      final pendingInviteCode = userData['pendingInviteCode'] as String?;
      if (pendingInviteCode != null) {
        ref.read(coupleProvider.notifier).restoreInviteCode(pendingInviteCode);
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message =
          (data is Map ? data['error'] ?? data['message'] : null) as String? ??
          '로그인에 실패했습니다';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
      return false;
    }
  }

  /// Register a new user.
  Future<bool> register({
    required String email,
    required String password,
    required String nickname,
    DateTime? birthDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'nickname': nickname,
          if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      await ApiClient.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );

      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await ApiClient.saveUserId(user.id);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message =
          (data is Map ? data['error'] ?? data['message'] : null) as String? ??
          '회원가입에 실패했습니다';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
      return false;
    }
  }

  /// Logout.
  Future<void> logout() async {
    ref.read(chatProvider.notifier).disconnect();
    clearPendingWidgetRoute();
    resetFeatureProviders(ref);
    await ApiClient.clearTokens();
    await WidgetService.clearData();
    PushNotificationService.reset();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Force logout triggered by persistent server/auth failure (e.g. the
  /// server was redeployed and the session is no longer valid).
  ///
  /// Unlike [logout] this:
  ///  - does NOT hit any `/auth/logout` endpoint (the server is the problem)
  ///  - stashes a [reason] message so the login screen can show a banner
  ///  - is a no-op if the user is already unauthenticated (prevents redundant
  ///    state churn when multiple in-flight requests fail at once)
  Future<void> forceLogout(String reason) async {
    if (state.status == AuthStatus.unauthenticated) {
      // Keep the reason fresh even if we're already unauthenticated so the
      // login screen still shows the banner.
      if (state.forceLogoutReason != reason) {
        state = state.copyWith(forceLogoutReason: reason);
      }
      return;
    }
    ref.read(chatProvider.notifier).disconnect();
    clearPendingWidgetRoute();
    resetFeatureProviders(ref);
    await ApiClient.clearTokens();
    await WidgetService.clearData();
    PushNotificationService.reset();
    state = AuthState(
      status: AuthStatus.unauthenticated,
      forceLogoutReason: reason,
    );
  }

  /// Read-and-clear the force-logout reason. Called by the login screen
  /// after it has shown the banner to the user so the message doesn't
  /// reappear on subsequent visits to the screen.
  ///
  /// Bypasses [AuthState.copyWith] because its `??` fallback cannot express
  /// "set this field to null".
  String? consumeForceLogoutReason() {
    final reason = state.forceLogoutReason;
    if (reason == null) return null;
    state = AuthState(
      status: state.status,
      user: state.user,
      error: state.error,
      isLoading: state.isLoading,
      forceLogoutReason: null,
    );
    return reason;
  }

  /// Update user profile.
  void updateUser(User user) {
    state = state.copyWith(user: user);
  }

  /// /social-signup 화면에서 가입 완료/취소 시 보관 중인 정보 삭제.
  /// copyWith 의 `??` fallback 으로는 null 설정이 불가능해서 별도 메서드.
  void clearPendingSocialSignup() {
    if (state.pendingSocialSignup == null) return;
    state = AuthState(
      status: state.status,
      user: state.user,
      error: state.error,
      isLoading: state.isLoading,
      forceLogoutReason: state.forceLogoutReason,
      pendingSocialSignup: null,
    );
  }

  /// 서버 응답({user, accessToken, refreshToken})을 받아 토큰 저장 + state 갱신.
  /// 소셜 로그인/가입 완료에서 공통으로 사용.
  Future<User> _applyAuthSuccess(Map<String, dynamic> data) async {
    await ApiClient.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final userData = data['user'] as Map<String, dynamic>;
    final user = User.fromJson(userData);
    await ApiClient.saveUserId(user.id);
    if (user.coupleId != null) {
      await ApiClient.saveCoupleId(user.coupleId!);
    }
    final pendingInviteCode = userData['pendingInviteCode'] as String?;
    if (pendingInviteCode != null) {
      ref.read(coupleProvider.notifier).restoreInviteCode(pendingInviteCode);
    }
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      isLoading: false,
    );
    return user;
  }

  /// 소셜 로그인 시도.
  /// - 기존 연동된 계정이면 즉시 로그인 (state authenticated)
  /// - 같은 이메일의 일반 계정 충돌 시 SocialLoginEmailExists
  /// - 신규 유저면 SocialLoginNeedsSignup (가입 화면으로 유도)
  Future<SocialLoginOutcome> socialLogin(SocialProvider provider) async {
    state = state.copyWith(isLoading: true, error: null);
    SocialAuthResult socialResult;
    try {
      socialResult = await SocialAuthService.signIn(provider);
    } on SocialAuthCancelledException {
      state = state.copyWith(isLoading: false);
      return const SocialLoginFailure('취소되었습니다.', cancelled: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return SocialLoginFailure('소셜 로그인 실패: $e');
    }

    try {
      final response = await _dio.post(
        '/auth/social/login',
        data: {
          'provider': provider.serverName,
          ...socialResult.tokenPayload,
        },
      );
      final data = response.data as Map<String, dynamic>;

      if (data['needsSignup'] == true) {
        final profile = (data['profile'] as Map?)?.cast<String, dynamic>();
        final pending = SocialLoginNeedsSignup(
          signupToken: data['signupToken'] as String,
          provider: provider,
          suggestedName: (profile?['name'] as String?) ?? socialResult.displayName,
          email: (profile?['email'] as String?) ?? socialResult.email,
          picture: profile?['picture'] as String?,
        );
        // /social-signup 라우트에서 읽을 수 있도록 state 에 보관.
        state = state.copyWith(
          isLoading: false,
          pendingSocialSignup: pending,
        );
        return pending;
      }

      final user = await _applyAuthSuccess(data);
      return SocialLoginSuccess(user);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map &&
          data['error'] == 'EMAIL_EXISTS') {
        return SocialLoginEmailExists(
          email: (data['email'] as String?) ?? socialResult.email ?? '',
          provider: provider,
        );
      }
      final message = (data is Map ? data['error'] ?? data['message'] : null)
              as String? ??
          '소셜 로그인에 실패했습니다.';
      return SocialLoginFailure(message);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return SocialLoginFailure('알 수 없는 오류: $e');
    }
  }

  /// 소셜 신규 가입 완료 (닉네임/생일 입력 후 호출).
  Future<bool> completeSocialSignup({
    required String signupToken,
    required String nickname,
    DateTime? birthDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.post(
        '/auth/social/complete-signup',
        data: {
          'signupToken': signupToken,
          'nickname': nickname,
          if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      await _applyAuthSuccess(data);
      clearPendingSocialSignup();
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message =
          (data is Map ? data['error'] ?? data['message'] : null) as String? ??
              '가입에 실패했습니다.';
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다.');
      return false;
    }
  }

  /// 로그인된 상태에서 새 소셜 provider 연동.
  /// 성공 시 null, 실패 시 에러 메시지 반환.
  Future<String?> linkSocial(SocialProvider provider) async {
    SocialAuthResult socialResult;
    try {
      socialResult = await SocialAuthService.signIn(provider);
    } on SocialAuthCancelledException {
      return '취소되었습니다.';
    } catch (e) {
      return '소셜 인증 실패: $e';
    }

    try {
      await _dio.post(
        '/auth/social/link',
        data: {
          'provider': provider.serverName,
          ...socialResult.tokenPayload,
        },
      );
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      return (data is Map ? data['message'] ?? data['error'] : null) as String? ??
          '연동에 실패했습니다.';
    } catch (e) {
      return '알 수 없는 오류: $e';
    }
  }

  /// 소셜 연동 해제.
  Future<String?> unlinkSocial(SocialProvider provider) async {
    try {
      await _dio.delete('/auth/social/${provider.serverName}');
      // 카카오/구글은 디바이스에서 토큰도 정리.
      await SocialAuthService.signOut(provider);
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      return (data is Map ? data['message'] ?? data['error'] : null) as String? ??
          '연동 해제에 실패했습니다.';
    } catch (e) {
      return '알 수 없는 오류: $e';
    }
  }

  /// 현재 사용자의 연동 현황 조회.
  /// 응답 형식: { hasPassword: bool, providers: [{provider, linked, email, linkedAt}] }
  Future<Map<String, dynamic>?> fetchLinkedProviders() async {
    try {
      final response = await _dio.get('/auth/social/linked');
      return (response.data as Map).cast<String, dynamic>();
    } catch (e) {
      return null;
    }
  }
}

// Providers
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final hasCoupleProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return (user?.isCoupleComplete ?? false) ||
      (user?.hasExistingCoupleData ?? false);
});
