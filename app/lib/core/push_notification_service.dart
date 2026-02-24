import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'api_client.dart';
import 'constants.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 권한 요청 + 토큰 비교 후 필요시 서버 업데이트
  static Future<void> initialize() async {
    // 로그인 안 된 상태면 스킵
    final accessToken = ApiClient.getAccessToken();
    if (accessToken == null) return;

    // 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('[Push] Permission denied');
      return;
    }

    debugPrint('[Push] Permission granted');
    await _syncToken();

    // 토큰 갱신 시 서버에 재등록
    _messaging.onTokenRefresh.listen((newToken) {
      _updateTokenIfChanged(newToken);
    });

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] Foreground message: ${message.notification?.title}');
    });

    // 백그라운드에서 탭하여 앱 열었을 때
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] Opened from background: ${message.data}');
    });
  }

  /// 현재 토큰을 가져와서 로컬 저장값과 비교, 다르면 서버 업데이트
  static Future<void> _syncToken() async {
    try {
      final currentToken = await _messaging.getToken();
      if (currentToken == null) return;

      final box = Hive.box(AppConstants.authBox);
      final savedToken = box.get(AppConstants.fcmTokenKey) as String?;

      if (savedToken == currentToken) {
        debugPrint('[Push] Token unchanged, skip update');
        return;
      }

      // 토큰이 없었거나 변경됨 → 서버 업데이트
      debugPrint('[Push] Token changed, updating server');
      await _sendTokenToServer(currentToken);
      await box.put(AppConstants.fcmTokenKey, currentToken);
    } catch (e) {
      debugPrint('[Push] Token sync error: $e');
    }
  }

  /// onTokenRefresh 콜백용
  static Future<void> _updateTokenIfChanged(String newToken) async {
    final box = Hive.box(AppConstants.authBox);
    final savedToken = box.get(AppConstants.fcmTokenKey) as String?;

    if (savedToken == newToken) return;

    debugPrint('[Push] Token refreshed, updating server');
    await _sendTokenToServer(newToken);
    await box.put(AppConstants.fcmTokenKey, newToken);
  }

  static Future<void> _sendTokenToServer(String token) async {
    try {
      final dio = ApiClient.createDio();
      await dio.post('/auth/fcm-token', data: {'fcmToken': token});
      debugPrint('[Push] Token sent to server');
    } catch (e) {
      debugPrint('[Push] Failed to send token: $e');
    }
  }
}
