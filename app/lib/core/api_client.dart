import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'constants.dart';

final dioProvider = Provider<Dio>((ref) {
  return ApiClient.createDio();
});

class ApiClient {
  ApiClient._();

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
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        final refreshToken = ApiClient.getRefreshToken();
        if (refreshToken == null) {
          _isRefreshing = false;
          return handler.next(err);
        }

        // Attempt to refresh the token
        final refreshDio = Dio(BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
          },
        ));

        final response = await refreshDio.post(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );

        if (response.statusCode == 200) {
          final newAccessToken = response.data['accessToken'] as String;

          // Save the new access token (refresh token stays the same)
          final box = Hive.box(AppConstants.authBox);
          await box.put(AppConstants.accessTokenKey, newAccessToken);

          // Retry the original request with the new token
          final options = err.requestOptions;
          options.headers['Authorization'] = 'Bearer $newAccessToken';

          final retryResponse = await _dio.fetch(options);
          _isRefreshing = false;
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        // Refresh failed - clear tokens
        await ApiClient.clearTokens();
      }

      _isRefreshing = false;
    }

    handler.next(err);
  }
}
