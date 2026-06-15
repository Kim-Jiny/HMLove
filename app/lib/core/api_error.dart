import 'package:dio/dio.dart';

/// Extracts a user-facing error message from a [DioException].
///
/// Behavior-equivalent to the most robust inline variant previously duplicated
/// across providers: when [error] is a [DioException] whose `response.data` is a
/// [Map], it returns `(data['error'] ?? data['message'])` cast to `String?` when
/// non-null. In every other case (non-Dio error, non-Map data, or both keys
/// absent/null) it returns [fallback]. Guards `is Map`, so it never throws.
String extractDioErrorMessage(
  Object error, {
  String fallback = '알 수 없는 오류가 발생했습니다',
}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = (data['error'] ?? data['message']) as String?;
      if (message != null) return message;
    }
  }
  return fallback;
}
