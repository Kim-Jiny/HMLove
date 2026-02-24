import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
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

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
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

  /// Check if user is already authenticated (on app start).
  Future<void> checkAuthStatus() async {
    final token = ApiClient.getAccessToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

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
    } catch (e) {
      await ApiClient.clearTokens();
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
    state = const AuthState(status: AuthStatus.unauthenticated);
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
  return ref.watch(authProvider).user?.isCoupleComplete ?? false;
});
