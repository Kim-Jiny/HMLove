import 'dart:async';
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
        final currentYm =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        // 위젯이 실제 표시 중인 월(prev/next 네비게이션 반영)도 같이 갱신
        final displayedYm =
            await HomeWidget.getWidgetData<String>('calendarYearMonth');
        final months = <String>{
          currentYm,
          if (displayedYm != null && displayedYm.isNotEmpty) displayedYm,
        };
        final client = HttpClient();
        try {
          for (final ym in months) {
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
                      final eventType =
                          event['eventType'] as String? ?? 'schedule';
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
                final encoded = jsonEncode(widgetEvents);
                await HomeWidget.saveWidgetData(
                  'calendarEvents_$ym',
                  encoded,
                );
                if (ym == currentYm) {
                  await HomeWidget.saveWidgetData('calendarEvents', encoded);
                }
              }
            } catch (_) {
              // 단일 월 실패는 무시하고 다음 월 진행
            }
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

/// Run [task] with a hard timeout. On timeout or any error, log and return
/// normally so startup never hangs on a single misbehaving plugin.
Future<void> _guardedInit(
  String label,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    await task().timeout(timeout);
  } catch (e) {
    debugPrint('[init] $label skipped: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 필수: Hive + 로케일은 스플래시/라우터가 바로 의존하므로 runApp 이전에 완료.
  // Hive는 타임아웃 없이 반드시 완료해야 함 (auth 체크에 필수).
  try {
    await Hive.initFlutter();
    await Hive.openBox(AppConstants.authBox);
    await Hive.openBox(AppConstants.settingsBox);
    await Hive.openBox(AppConstants.cacheBox);
  } catch (e) {
    debugPrint('[init] Hive failed: $e');
  }
  await _guardedInit(
    'dateFormatting',
    () => initializeDateFormatting('ko_KR', null),
  );
  timeago.setLocaleMessages('ko', timeago.KoMessages());

  // Firebase 는 background handler 등록 때문에 runApp 전에 필요하지만,
  // 일부 디바이스에서 막히는 경우가 보고되어 타임아웃으로 보호.
  await _guardedInit('Firebase', () async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  });

  // _HMLoveAppState.initState 가 HomeWidget.initiallyLaunchedFromHomeWidget()
  // 을 호출하는데, 이건 setAppGroupId 가 먼저 끝나야 PlatformException(-7) 안 남.
  // setAppGroupId는 단순 문자열 저장이라 빠르고, 실패해도 _guardedInit가 흡수.
  await _guardedInit('home_widget', WidgetService.initialize);

  runApp(
    const ProviderScope(
      child: HMLoveApp(),
    ),
  );

  // 스플래시 빠져나온 뒤 백그라운드로 나머지 초기화. 실패해도 앱은 진행.
  // 순서: FCM 억제 → 사운드 → AdMob → NaverMap
  // (home_widget 은 위에서 runApp 전에 처리됨)
  // (AdMob, NaverMap 은 폴드/특정 디바이스에서 블록 보고 있어 반드시 비차단으로)
  // ignore: unawaited_futures
  _initDeferred();
}

Future<void> _initDeferred() async {
  await _guardedInit(
    'FCM suppressForeground',
    PushNotificationService.suppressForegroundNotifications,
  );
  await _guardedInit(
    'notificationSound',
    NotificationSoundService.initialize,
  );
  await _guardedInit(
    'AdMob',
    AdService.initialize,
    timeout: const Duration(seconds: 8),
  );
  await _guardedInit(
    'NaverMap',
    () => FlutterNaverMap().init(
      clientId: AppConstants.naverMapClientId,
      onAuthFailed: (ex) => debugPrint(
        '[NaverMap] Auth failed: ${ex.code} - ${ex.message}',
      ),
    ),
    timeout: const Duration(seconds: 8),
  );
}

class HMLoveApp extends ConsumerStatefulWidget {
  const HMLoveApp({super.key});

  @override
  ConsumerState<HMLoveApp> createState() => _HMLoveAppState();
}

class _HMLoveAppState extends ConsumerState<HMLoveApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSub;
  String? _pendingWidgetRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Wire the API client's force-logout callback to the auth provider so
    // persistent server failures can kick the user back to /login.
    ApiClient.onForceLogout = (reason) async {
      await ref.read(authProvider.notifier).forceLogout(reason);
    };

    // Route home-widget taps (e.g. calendar widget → /calendar).
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetClick);
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (!mounted) return;
      _handleWidgetClick(uri);
    });

    // Consume pending widget route once auth resolves (cold-launch case).
    ref.listenManual<AuthState>(authProvider, (prev, next) {
      if (_pendingWidgetRoute == null) return;
      if (next.status == AuthStatus.authenticated) {
        final target = _pendingWidgetRoute!;
        _pendingWidgetRoute = null;
        ref.read(routerProvider).go(target);
      } else if (next.status == AuthStatus.unauthenticated) {
        _pendingWidgetRoute = null;
      }
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    _widgetClickSub = null;
    ApiClient.onForceLogout = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;
    final route = _widgetUriToRoute(uri);
    if (route == null) return;
    final status = ref.read(authProvider).status;
    if (status == AuthStatus.authenticated) {
      ref.read(routerProvider).go(route);
    } else if (status == AuthStatus.initial) {
      _pendingWidgetRoute = route;
    }
  }

  String? _widgetUriToRoute(Uri uri) {
    // Widget URIs use the form hmlove://<section> (e.g. hmlove://calendar).
    final target = uri.host.isNotEmpty
        ? uri.host
        : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '');
    switch (target) {
      case 'calendar':
        return '/calendar';
      default:
        return null;
    }
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
