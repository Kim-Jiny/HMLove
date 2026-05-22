import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/social_signup_screen.dart';
import '../screens/couple/couple_connect_screen.dart';
import '../screens/main_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/photo/photo_map_screen.dart';
import '../providers/fight_provider.dart';
import '../screens/fight/fight_list_screen.dart';
import '../screens/fight/fight_write_screen.dart';
import '../providers/letter_provider.dart';
import '../screens/letter/letter_list_screen.dart';
import '../screens/letter/letter_write_screen.dart';
import '../screens/letter/letter_read_screen.dart';
import '../screens/fortune/fortune_screen.dart';
import '../screens/home/anniversary_screen.dart';
import '../screens/notification/notification_screen.dart';
import '../screens/wishlist/wishlist_screen.dart';
import '../screens/question/question_screen.dart';
import '../screens/doodle/doodle_canvas_screen.dart';
import '../screens/doodle/doodle_history_screen.dart';

/// 푸시 알림 등에서 네비게이션 접근용 글로벌 키
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 각 탭 브랜치 네비게이터 키 (탭 전환 시 Navigator.push 화면 pop 용)
final shellBranchKeys = <int, GlobalKey<NavigatorState>>{
  0: GlobalKey<NavigatorState>(debugLabel: 'home'),
  1: GlobalKey<NavigatorState>(debugLabel: 'chat'),
  2: GlobalKey<NavigatorState>(debugLabel: 'calendar'),
  3: GlobalKey<NavigatorState>(debugLabel: 'feed'),
  4: GlobalKey<NavigatorState>(debugLabel: 'more'),
};

final routerProvider = Provider<GoRouter>((ref) {
  // Use a listenable to trigger redirects when auth changes
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;
      final isLoggedIn = status == AuthStatus.authenticated;
      final hasCouple = (authState.user?.isCoupleComplete ?? false) ||
          (authState.user?.hasExistingCoupleData ?? false);
      // 소셜 신규 가입 진행 중인지. socialLogin 이 needsSignup 응답을 받으면
      // 이 값이 set 되고 _AuthChangeNotifier 가 redirect 를 재평가시킨다.
      final pendingSocialSignup = authState.pendingSocialSignup != null;
      final currentPath = state.matchedLocation;

      // 위젯/소셜 로그인 등에서 들어오는 외부 스킴(hmlove://..., kakao{key}://oauth) 은
      // 경로로 변환. Android의 HomeWidgetLaunchIntent나 iOS SceneDelegate가
      // deep link를 Flutter 로 넘기면 GoRouter 초기 location 으로 들어오는데,
      // 매칭 라우트가 없어 GoException 을 던지므로 여기서 미리 변환.
      final scheme = state.uri.scheme;
      if (scheme.isNotEmpty && scheme != 'http' && scheme != 'https') {
        final target = state.uri.host.isNotEmpty
            ? state.uri.host
            : (state.uri.pathSegments.isNotEmpty
                ? state.uri.pathSegments.first
                : '');
        switch (target) {
          case 'calendar':
            return '/calendar';
          case 'doodle':
            return '/doodle';
          default:
            // 카카오 OAuth 콜백 등 알 수 없는 스킴. 진행 중인 소셜 가입이 있으면
            // 가입 화면으로, 아니면 splash 가 auth 상태 보고 분기.
            return pendingSocialSignup ? '/social-signup' : '/splash';
        }
      }

      // While still checking auth (initial), stay on splash
      if (status == AuthStatus.initial) {
        if (currentPath == '/splash') return null;
        return '/splash';
      }

      // Auth resolved — if still on splash, navigate to the right place
      if (currentPath == '/splash') {
        if (!isLoggedIn) {
          return pendingSocialSignup ? '/social-signup' : '/login';
        }
        if (!hasCouple) return '/couple-connect';
        return '/home';
      }

      // 소셜 신규 가입 진행 중이면 무조건 가입 화면으로. iOS scene/deep-link 가
      // LoginScreen 을 unmount 시켜 context.push 가 안 먹는 경우에도 라우터가 복구.
      if (!isLoggedIn && pendingSocialSignup) {
        if (currentPath == '/social-signup') return null;
        return '/social-signup';
      }

      // If not authenticated, redirect to login (except register/social-signup)
      if (!isLoggedIn) {
        if (currentPath == '/login' ||
            currentPath == '/register' ||
            currentPath == '/social-signup') {
          return null;
        }
        return '/login';
      }

      // If authenticated but no couple, redirect to couple-connect
      if (isLoggedIn && !hasCouple) {
        if (currentPath == '/couple-connect') return null;
        return '/couple-connect';
      }

      // If authenticated with couple and on auth pages, redirect to home
      if (isLoggedIn &&
          hasCouple &&
          (currentPath == '/login' ||
              currentPath == '/register' ||
              currentPath == '/couple-connect')) {
        return '/home';
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/social-signup',
        builder: (context, state) => const SocialSignupScreen(),
      ),

      // Couple connect
      GoRoute(
        path: '/couple-connect',
        builder: (context, state) => const CoupleConnectScreen(),
      ),

      // Photo Map
      GoRoute(
        path: '/photo-map',
        builder: (context, state) => const PhotoMapScreen(),
      ),

      // Fight routes
      GoRoute(
        path: '/fight',
        builder: (context, state) => const FightListScreen(),
      ),
      GoRoute(
        path: '/fight/write',
        builder: (context, state) => FightWriteScreen(
          fight: state.extra is Fight ? state.extra as Fight : null,
        ),
      ),

      // Letter routes
      GoRoute(
        path: '/letter',
        builder: (context, state) => const LetterListScreen(),
      ),
      GoRoute(
        path: '/letter/write',
        builder: (context, state) => LetterWriteScreen(
          letter: state.extra is Letter ? state.extra as Letter : null,
        ),
      ),
      GoRoute(
        path: '/letter/:id',
        builder: (context, state) => LetterReadScreen(
          letterId: state.pathParameters['id']!,
        ),
      ),

      // Fortune
      GoRoute(
        path: '/fortune',
        builder: (context, state) => const FortuneScreen(),
      ),

      // Anniversary
      GoRoute(
        path: '/anniversary',
        builder: (context, state) => const AnniversaryScreen(),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      // Wishlist
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),

      // Question
      GoRoute(
        path: '/question',
        builder: (context, state) => const QuestionScreen(),
      ),

      // Doodle (그림 보내기)
      GoRoute(
        path: '/doodle',
        builder: (context, state) => const DoodleHistoryScreen(),
      ),
      GoRoute(
        path: '/doodle/canvas',
        builder: (context, state) => const DoodleCanvasScreen(),
      ),

      // Main Shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: shellBranchKeys[0]!,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellBranchKeys[1]!,
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellBranchKeys[2]!,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellBranchKeys[3]!,
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: shellBranchKeys[4]!,
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Listens to auth state changes and notifies GoRouter to re-evaluate redirects.
class _AuthChangeNotifier extends ChangeNotifier {
  late final ProviderSubscription<AuthState> _sub;

  _AuthChangeNotifier(Ref ref) {
    _sub = ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
