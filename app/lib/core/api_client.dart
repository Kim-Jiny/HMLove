import 'dart:async';

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
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('[API] $obj'),
        ),
      );
    }

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
    // Share tokens with widget extension for background fetching + self-refresh
    await WidgetService.saveAuthInfo(
      accessToken,
      AppConstants.apiBaseUrl,
      refreshToken,
    );
  }

  /// Clear all stored tokens.
  static Future<void> clearTokens() async {
    final box = Hive.box(AppConstants.authBox);
    await box.delete(AppConstants.accessTokenKey);
    await box.delete(AppConstants.refreshTokenKey);
    await box.delete(AppConstants.userIdKey);
    await box.delete(AppConstants.coupleIdKey);
    // 위젯 확장의 토큰도 정리
    await WidgetService.clearData();
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

  /// When a refresh is in flight, all subsequent 401 handlers await this
  /// Completer instead of firing their own refresh request.
  Completer<String?>? _refreshCompleter;

  // Timestamp of the last force-logout trigger, used to debounce re-triggers
  // when several in-flight 401 responses arrive back-to-back.
  static DateTime? _lastForceLogoutAt;
  static const Duration _forceLogoutDebounce = Duration(seconds: 30);

  _AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final token = ApiClient.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Hive may not be ready — proceed without auth header.
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Another 401 handler is already refreshing — wait for it.
    if (_refreshCompleter != null) {
      final newToken = await _refreshCompleter!.future;
      if (newToken != null) {
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retryResponse = await _dio.fetch(options);
          return handler.resolve(retryResponse);
        } catch (_) {
          return handler.next(err);
        }
      }
      return handler.next(err);
    }

    // This is the first 401 — take ownership of the refresh.
    _refreshCompleter = Completer<String?>();

    bool userIsLoggedIn;
    String? refreshToken;
    try {
      userIsLoggedIn = ApiClient.getAccessToken() != null;
      refreshToken = ApiClient.getRefreshToken();
    } catch (_) {
      // Hive not available — can't refresh, just propagate the error.
      _refreshCompleter!.complete(null);
      _refreshCompleter = null;
      return handler.next(err);
    }
    if (refreshToken == null) {
      _refreshCompleter!.complete(null);
      _refreshCompleter = null;
      if (userIsLoggedIn) {
        await ApiClient.clearTokens();
        await _maybeTriggerForceLogout('세션이 만료되었어요. 다시 로그인해주세요.');
      }
      return handler.next(err);
    }

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    Response? refreshResponse;
    try {
      refreshResponse = await refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
    } on DioException catch (refreshErr) {
      _refreshCompleter!.complete(null);
      _refreshCompleter = null;
      final refreshCode = refreshErr.response?.statusCode;
      if (refreshCode != null) {
        await ApiClient.clearTokens();
        await _maybeTriggerForceLogout('세션이 만료되었어요. 다시 로그인해주세요.');
      }
      return handler.next(err);
    } catch (_) {
      _refreshCompleter!.complete(null);
      _refreshCompleter = null;
      return handler.next(err);
    }

    if (refreshResponse.statusCode == 200) {
      try {
        final newAccessToken = refreshResponse.data['accessToken'] as String;
        final box = Hive.box(AppConstants.authBox);
        await box.put(AppConstants.accessTokenKey, newAccessToken);
        await WidgetService.saveAuthInfo(
          newAccessToken,
          AppConstants.apiBaseUrl,
        );

        // Unblock all waiting 401 handlers with the new token.
        _refreshCompleter!.complete(newAccessToken);
        _refreshCompleter = null;

        // Retry the original request.
        final options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $newAccessToken';
        final retryResponse = await _dio.fetch(options);
        return handler.resolve(retryResponse);
      } catch (_) {
        _refreshCompleter!.complete(null);
        _refreshCompleter = null;
        return handler.next(err);
      }
    }

    // Non-200 refresh response → server rejected the refresh token.
    _refreshCompleter!.complete(null);
    _refreshCompleter = null;
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
