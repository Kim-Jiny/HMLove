import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'constants.dart';
import 'widget_service.dart';

final dioProvider = Provider<Dio>((ref) {
  return ApiClient.createDio();
});

/// Called when the API layer detects that the user's session can no longer
/// reach the server (refresh token rejected, or repeated network/5xx failures).
/// The handler is expected to clear auth state and redirect to the login screen.
typedef ForceLogoutHandler = Future<void> Function(String reason);

class ApiClient {
  ApiClient._();

  /// Installed by the app shell once the Riverpod container is ready so the
  /// interceptor can ask the auth layer to kick the user back to login.
  static ForceLogoutHandler? onForceLogout;

  static Future<void> _triggerForceLogout(String reason) async {
    final handler = onForceLogout;
    if (handler == null) return;
    try {
      await handler(reason);
    } catch (e) {
      debugPrint('[ApiClient] forceLogout handler error: $e');
    }
  }

  static Dio createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio));
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[API] $obj'),
    ));

    return dio;
  }

  /// Get the stored access token from Hive.
  static String? getAccessToken() {
    final box = Hive.box(AppConstants.authBox);
    return box.get(AppConstants.accessTokenKey) as String?;
  }

  /// Get the stored refresh token from Hive.
  static String? getRefreshToken() {
    final box = Hive.box(AppConstants.authBox);
    return box.get(AppConstants.refreshTokenKey) as String?;
  }

  /// Save tokens to Hive.
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put(AppConstants.accessTokenKey, accessToken);
    await box.put(AppConstants.refreshTokenKey, refreshToken);
    // Share token with widget extension for background fetching
    WidgetService.saveAuthInfo(accessToken, AppConstants.apiBaseUrl);
  }

  /// Clear all stored tokens.
  static Future<void> clearTokens() async {
    final box = Hive.box(AppConstants.authBox);
    await box.delete(AppConstants.accessTokenKey);
    await box.delete(AppConstants.refreshTokenKey);
    await box.delete(AppConstants.userIdKey);
    await box.delete(AppConstants.coupleIdKey);
  }

  /// Save user ID to Hive.
  static Future<void> saveUserId(String userId) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put(AppConstants.userIdKey, userId);
  }

  /// Get stored user ID.
  static String? getUserId() {
    final box = Hive.box(AppConstants.authBox);
    return box.get(AppConstants.userIdKey) as String?;
  }

  /// Save couple ID to Hive.
  static Future<void> saveCoupleId(String coupleId) async {
    final box = Hive.box(AppConstants.authBox);
    await box.put(AppConstants.coupleIdKey, coupleId);
  }

  /// Get stored couple ID.
  static String? getCoupleId() {
    final box = Hive.box(AppConstants.authBox);
    return box.get(AppConstants.coupleIdKey) as String?;
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  // Timestamp of the last force-logout trigger, used to debounce re-triggers
  // when several in-flight 401 responses arrive back-to-back.
  static DateTime? _lastForceLogoutAt;
  static const Duration _forceLogoutDebounce = Duration(seconds: 30);

  _AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ApiClient.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final bool userIsLoggedIn = ApiClient.getAccessToken() != null;

    // We only care about 401 — a real "the server rejected your credentials"
    // response. Network failures, timeouts, and 5xx errors are passed through
    // untouched so the caller can surface a retry UI without logging the user
    // out (the server being temporarily unreachable is NOT an auth problem).
    if (err.response?.statusCode != 401 || _isRefreshing) {
      return handler.next(err);
    }

    _isRefreshing = true;

    // No refresh token means the session is unrecoverable — force logout if
    // the user was actually logged in.
    final refreshToken = ApiClient.getRefreshToken();
    if (refreshToken == null) {
      _isRefreshing = false;
      if (userIsLoggedIn) {
        await ApiClient.clearTokens();
        await _maybeTriggerForceLogout('세션이 만료되었어요. 다시 로그인해주세요.');
      }
      return handler.next(err);
    }

    // Attempt to refresh the access token on a fresh Dio so we don't re-enter
    // this interceptor. Two outcomes:
    //   • Server responded with an HTTP status (2xx → success, non-2xx →
    //     refresh was actively rejected → force logout).
    //   • No response at all (network/connection error) → leave the session
    //     alone; the user is probably just offline.
    final refreshDio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      headers: {'Content-Type': 'application/json'},
    ));

    Response? refreshResponse;
    try {
      refreshResponse = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (refreshErr) {
      _isRefreshing = false;
      final refreshCode = refreshErr.response?.statusCode;
      if (refreshCode != null) {
        // Server answered with an error code → refresh genuinely rejected.
        await ApiClient.clearTokens();
        await _maybeTriggerForceLogout('세션이 만료되었어요. 다시 로그인해주세요.');
      }
      // Otherwise: network/timeout while trying to refresh. Do NOT touch
      // auth state — the server is just temporarily unreachable.
      return handler.next(err);
    } catch (_) {
      // Unexpected non-Dio error — conservatively leave auth alone.
      _isRefreshing = false;
      return handler.next(err);
    }

    if (refreshResponse.statusCode == 200) {
      try {
        final newAccessToken = refreshResponse.data['accessToken'] as String;
        final box = Hive.box(AppConstants.authBox);
        await box.put(AppConstants.accessTokenKey, newAccessToken);

        // Retry the original request with the new token.
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $newAccessToken';

        final retryResponse = await _dio.fetch(options);
        _isRefreshing = false;
        return handler.resolve(retryResponse);
      } catch (_) {
        // Retry of the original request failed — let it surface as an error,
        // but don't force logout (the refresh itself succeeded).
        _isRefreshing = false;
        return handler.next(err);
      }
    }

    // Non-200 refresh response → server rejected the refresh token.
    _isRefreshing = false;
    await ApiClient.clearTokens();
    await _maybeTriggerForceLogout('세션이 만료되었어요. 다시 로그인해주세요.');
    return handler.next(err);
  }

  /// Fire the force-logout handler at most once per [_forceLogoutDebounce]
  /// window so multiple concurrent 401 responses don't stampede.
  Future<void> _maybeTriggerForceLogout(String reason) async {
    final last = _lastForceLogoutAt;
    if (last != null &&
        DateTime.now().difference(last) < _forceLogoutDebounce) {
      return;
    }
    _lastForceLogoutAt = DateTime.now();
    await ApiClient._triggerForceLogout(reason);
  }
}
