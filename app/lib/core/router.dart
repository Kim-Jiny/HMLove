import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/couple/couple_connect_screen.dart';
import '../screens/main_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/photo/photo_map_screen.dart';
import '../screens/fight/fight_list_screen.dart';
import '../screens/fight/fight_write_screen.dart';
import '../screens/letter/letter_list_screen.dart';
import '../screens/letter/letter_write_screen.dart';
import '../screens/letter/letter_read_screen.dart';
import '../screens/fortune/fortune_screen.dart';
import '../screens/home/anniversary_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Use a listenable to trigger redirects when auth changes
  final authNotifier = _AuthChangeNotifier(ref);
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;
      final isLoggedIn = status == AuthStatus.authenticated;
      final hasCouple = authState.user?.isCoupleComplete ?? false;
      final currentPath = state.matchedLocation;

      // While still checking auth (initial), stay on splash
      if (status == AuthStatus.initial) {
        if (currentPath == '/splash') return null;
        return '/splash';
      }

      // Auth resolved — if still on splash, navigate to the right place
      if (currentPath == '/splash') {
        if (!isLoggedIn) return '/login';
        if (!hasCouple) return '/couple-connect';
        return '/home';
      }

      // If not authenticated, redirect to login (except register)
      if (!isLoggedIn) {
        if (currentPath == '/login' || currentPath == '/register') {
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
          fight: state.extra,
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
          letter: state.extra,
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

      // Main Shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
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
