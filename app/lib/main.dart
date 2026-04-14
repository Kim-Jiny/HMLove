import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'core/ad_service.dart';
import 'core/api_client.dart';
import 'core/constants.dart';
import 'core/notification_sound_service.dart';
import 'core/push_notification_service.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/widget_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';

String _defaultWidgetEventColor(String eventType, bool isAnniversary) {
  if (isAnniversary) return '#E91E63';
  switch (eventType) {
    case 'schedule':
      return '#1976D2';
    case 'device':
      return '#4CAF50';
    case 'feed':
      return '#FF9800';
    default:
      return '#E91E63';
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (message.data['type'] == 'calendar_sync') {
    // iOS: timeline reload → 위젯이 서버에서 직접 최신 데이터 조회
    await HomeWidget.updateWidget(iOSName: 'HMLoveWidget');

    // Android: SharedPreferences 데이터를 서버에서 갱신 후 위젯 업데이트
    try {
      await HomeWidget.setAppGroupId('group.com.jiny.hmlove');
      final token = await HomeWidget.getWidgetData<String>('authToken');
      final baseUrl = await HomeWidget.getWidgetData<String>('apiBaseUrl');
      if (token != null && baseUrl != null) {
        final now = DateTime.now();
        final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('$baseUrl/calendar/$ym'),
          );
          request.headers.set('Authorization', 'Bearer $token');
          final response = await request.close();
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final data = jsonDecode(body) as Map<String, dynamic>;
            final events = data['events'] as List<dynamic>;
            final widgetEvents = events
                .where((e) => e['_auto'] != true)
                .map((e) {
                  final event = e as Map<String, dynamic>;
                  final isAnniversary = event['isAnniversary'] == true;
                  final eventType = event['eventType'] as String? ?? 'schedule';
                  return {
                    'date': (event['date'] as String).substring(0, 10),
                    'title': event['title'],
                    'color': event['color'] ??
                        _defaultWidgetEventColor(eventType, isAnniversary),
                    'isAnniversary': isAnniversary,
                    'eventType': eventType,
                  };
                })
                .toList();
            await HomeWidget.saveWidgetData(
              'calendarEvents',
              jsonEncode(widgetEvents),
            );
            await HomeWidget.saveWidgetData(
              'calendarEvents_$ym',
              jsonEncode(widgetEvents),
            );
          }
        } finally {
          client.close();
        }
      }
    } catch (_) {
      // 백그라운드 fetch 실패 시 무시 — 포그라운드 복귀 시 갱신됨
    }
    await HomeWidget.updateWidget(androidName: 'HMLoveCalendarWidgetProvider');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 포그라운드에서 시스템 푸시 즉시 억제 (iOS) — 최대한 빨리 호출
  await PushNotificationService.suppressForegroundNotifications();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox(AppConstants.authBox);
  await Hive.openBox(AppConstants.settingsBox);
  await Hive.openBox(AppConstants.cacheBox);

  // Initialize Korean locale data
  await initializeDateFormatting('ko_KR', null);

  // Initialize timeago Korean locale
  timeago.setLocaleMessages('ko', timeago.KoMessages());

  // Initialize Home Widget
  await WidgetService.initialize();

  // Initialize notification sounds
  await NotificationSoundService.initialize();

  // Initialize AdMob
  await AdService.initialize();

  // Initialize Naver Map SDK
  await FlutterNaverMap().init(
    clientId: AppConstants.naverMapClientId,
    onAuthFailed: (ex) => debugPrint('[NaverMap] Auth failed: ${ex.code} - ${ex.message}'),
  );

  runApp(
    const ProviderScope(
      child: HMLoveApp(),
    ),
  );
}

class HMLoveApp extends ConsumerStatefulWidget {
  const HMLoveApp({super.key});

  @override
  ConsumerState<HMLoveApp> createState() => _HMLoveAppState();
}

class _HMLoveAppState extends ConsumerState<HMLoveApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Wire the API client's force-logout callback to the auth provider so
    // persistent server failures can kick the user back to /login.
    ApiClient.onForceLogout = (reason) async {
      await ref.read(authProvider.notifier).forceLogout(reason);
    };
  }

  @override
  void dispose() {
    ApiClient.onForceLogout = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When the user returns to the app after a backend redeploy, re-verify
      // the session. checkAuthStatus() internally clears tokens on failure
      // which flips AuthStatus to unauthenticated → GoRouter sends them to
      // /login. Only re-verify if the user is currently logged in.
      final authState = ref.read(authProvider);
      if (authState.status == AuthStatus.authenticated) {
        ref.read(authProvider.notifier).checkAuthStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          if (Platform.isAndroid) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(
                  minScaleFactor: 0.8,
                  maxScaleFactor: 1.2,
                ),
              ),
              child: child!,
            );
          }
          return child!;
        },
      ),
    );
  }
}
