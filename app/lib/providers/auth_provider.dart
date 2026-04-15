import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/push_notification_service.dart';
import '../core/widget_service.dart';
import '../models/user.dart';
import 'couple_provider.dart';

// Auth state enum
enum AuthStatus { initial, authenticated, unauthenticated }

// Auth state class
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final bool isLoading;

  /// One-shot message shown on the login screen after a forced logout
  /// (e.g. "서버에 연결할 수 없습니다"). Cleared by [AuthNotifier.consumeForceLogoutReason].
  final String? forceLogoutReason;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
    this.forceLogoutReason,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
    String? forceLogoutReason,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      forceLogoutReason: forceLogoutReason ?? this.forceLogoutReason,
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

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
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
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

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
      final message = (data is Map ? data['error'] ?? data['message'] : null) as String? ?? '로그인에 실패했습니다';
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
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
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'nickname': nickname,
        if (birthDate != null) 'birthDate': birthDate.toIso8601String(),
      });

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
      final message = (data is Map ? data['error'] ?? data['message'] : null) as String? ?? '회원가입에 실패했습니다';
      state = state.copyWith(
        isLoading: false,
        error: message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  /// Logout.
  Future<void> logout() async {
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
