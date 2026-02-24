import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 권한 요청 + 토큰 등록
  static Future<void> initialize() async {
    // 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('[Push] Permission granted');
      await _registerToken();
    } else {
      debugPrint('[Push] Permission denied');
    }

    // 토큰 갱신 시 서버에 재등록
    _messaging.onTokenRefresh.listen((token) {
      _sendTokenToServer(token);
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

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[Push] FCM Token: $token');
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('[Push] Token registration error: $e');
    }
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
