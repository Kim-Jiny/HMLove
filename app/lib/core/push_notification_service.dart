import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'api_client.dart';
import 'constants.dart';
import 'in_app_notification.dart';
import 'notification_sound_service.dart';
import 'router.dart';

/// 알림 타입 → Hive 설정 키 프리픽스 매핑
const _typeToKeyPrefix = <String, String>{
  'chat': 'noti_chat',
  'feed': 'noti_feed',
  'feed_like': 'noti_feed',
  'feed_comment': 'noti_feed',
  'calendar': 'noti_calendar',
  'anniversary': 'noti_anniversary',
  'letter': 'noti_letter',
  'mood': 'noti_mood',
  'fight': 'noti_fight',
};

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 커플 해제 알림 수신 시 콜백 (MainShell에서 등록)
  static void Function()? onCoupleLeft;

  /// 앱 시작 시 즉시 호출 — 포그라운드 시스템 푸시 억제 (iOS)
  static Future<void> suppressForegroundNotifications() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
    debugPrint('[Push] Foreground notification suppressed (iOS)');
  }

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

    // 포그라운드 시스템 푸시 억제 (혹시 main에서 호출 안 됐을 경우 대비)
    await suppressForegroundNotifications();

    await _syncToken();

    // 토큰 갱신 시 서버에 재등록
    _messaging.onTokenRefresh.listen((newToken) {
      _updateTokenIfChanged(newToken);
    });

    // 포그라운드 메시지 처리 → 인앱 배너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[Push] Foreground message received');
      debugPrint('[Push]   notification: ${message.notification?.title} / ${message.notification?.body}');
      debugPrint('[Push]   data: ${message.data}');

      if (message.data['type'] == 'couple_left') {
        onCoupleLeft?.call();
        return;
      }
      _showInAppBanner(message);
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
      case 'inquiry':
        GoRouter.of(context).go('/more');
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

  /// 현재 토큰을 서버에 항상 동기화 (로그인마다 유저가 달라질 수 있으므로)
  static Future<void> _syncToken() async {
    try {
      final currentToken = await _messaging.getToken();
      if (currentToken == null) return;

      debugPrint('[Push] Syncing token to server');
      await _sendTokenToServer(currentToken);

      final box = Hive.box(AppConstants.authBox);
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

  /// 포그라운드 알림 → 인앱 배너 + 소리/진동
  static void _showInAppBanner(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] as String? ?? '';

      // title/body: notification 필드 → data 필드 폴백
      final title = message.notification?.title ??
          data['title'] as String? ?? '';
      final body = message.notification?.body ??
          data['body'] as String? ?? '';

      debugPrint('[Push] Banner — title: "$title", body: "$body", type: "$type"');

      if (title.isEmpty && body.isEmpty) {
        debugPrint('[Push] Empty title and body, skipping banner');
        return;
      }

      final box = Hive.box(AppConstants.settingsBox);
      final allOn = box.get('noti_all', defaultValue: true) as bool;
      if (!allOn) return;

      final prefix = _typeToKeyPrefix[type];
      if (prefix != null) {
        final categoryOn = box.get(prefix, defaultValue: true) as bool;
        if (!categoryOn) return;
      }

      // 인앱 배너 표시
      showInAppNotification(
        title: title,
        body: body,
        type: type,
        onTap: () => _handleNotificationTap(data),
      );

      // 소리/진동
      _applyNotificationPrefs(data);
    } catch (e) {
      debugPrint('[Push] _showInAppBanner error: $e');
    }
  }

  /// 포그라운드 알림 수신 시 사용자 설정에 따라 소리/진동 제어
  static void _applyNotificationPrefs(Map<String, dynamic> data) {
    try {
      final box = Hive.box(AppConstants.settingsBox);

      // 전체 알림 꺼져 있으면 무시
      final allOn = box.get('noti_all', defaultValue: true) as bool;
      if (!allOn) return;

      final type = data['type'] as String?;
      final prefix = _typeToKeyPrefix[type];
      if (prefix == null) return;

      // 카테고리 알림 꺼져 있으면 무시
      final categoryOn = box.get(prefix, defaultValue: true) as bool;
      if (!categoryOn) return;

      // 카테고리별 소리/진동 설정
      final shouldSound = box.get('${prefix}_sound', defaultValue: true) as bool;
      final shouldVibrate = box.get('${prefix}_vibrate', defaultValue: true) as bool;

      // 사운드 재생
      if (shouldSound) {
        NotificationSoundService.playForCategory(prefix);
      }

      if (shouldVibrate) {
        HapticFeedback.mediumImpact();
      }

      debugPrint('[Push] Prefs applied — type: $type, sound: $shouldSound, vibrate: $shouldVibrate');
    } catch (e) {
      debugPrint('[Push] Prefs error: $e');
    }
  }
}
