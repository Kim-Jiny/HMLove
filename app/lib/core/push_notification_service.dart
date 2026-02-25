import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'api_client.dart';
import 'constants.dart';
import 'router.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 커플 해제 알림 수신 시 콜백 (MainShell에서 등록)
  static void Function()? onCoupleLeft;

  /// 권한 요청 + 토큰 비교 후 필요시 서버 업데이트 + 알림 탭 핸들링
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
      if (message.data['type'] == 'couple_left') {
        onCoupleLeft?.call();
      }
    });

    // 백그라운드에서 알림 탭하여 앱 열었을 때
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[Push] Opened from background: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // 앱이 완전히 종료된 상태에서 알림 탭으로 열었을 때
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Push] Opened from terminated: ${initialMessage.data}');
      // 약간 딜레이 후 네비게이션 (라우터 초기화 대기)
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleNotificationTap(initialMessage.data);
      });
    }
  }

  /// 알림 data에 따라 해당 화면으로 이동
  static void _handleNotificationTap(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('[Push] No navigator context available');
      return;
    }

    final type = data['type'] as String?;
    debugPrint('[Push] Navigating for type: $type');

    switch (type) {
      case 'chat':
        GoRouter.of(context).go('/chat');
        break;
      case 'feed':
      case 'feed_like':
      case 'feed_comment':
        GoRouter.of(context).go('/feed');
        break;
      case 'letter':
        final letterId = data['letterId'] as String?;
        if (letterId != null) {
          GoRouter.of(context).push('/letter/$letterId');
        } else {
          GoRouter.of(context).push('/letter');
        }
        break;
      case 'calendar':
        GoRouter.of(context).go('/calendar');
        break;
      case 'fight':
        GoRouter.of(context).push('/fight');
        break;
      case 'mood':
        GoRouter.of(context).go('/home');
        break;
      case 'fortune':
        GoRouter.of(context).push('/fortune');
        break;
      case 'couple_left':
        onCoupleLeft?.call();
        GoRouter.of(context).go('/more');
        return;
      default:
        GoRouter.of(context).go('/home');
        break;
    }
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
