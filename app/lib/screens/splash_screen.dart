import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/store_mode.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/cute/loader.dart';
import '../widgets/cute/mood_face.dart';
import '../widgets/cute/motion.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // 애니메이션이 한 번 보일 만큼만 기다린 뒤 인증을 확인한다.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // 스토어 촬영 모드: 토큰이 없으면 데모 계정으로 자동 로그인 (일반 빌드에선 비활성)
    if (storeModeEnabled && ApiClient.getAccessToken() == null) {
      final c = storeCredentials;
      await ref
          .read(authProvider.notifier)
          .login(email: c.email, password: c.password);
      if (!mounted) return;
    }

    try {
      // This will update authProvider state, which triggers
      // GoRouter's refreshListenable → redirect handles navigation
      await ref
          .read(authProvider.notifier)
          .checkAuthStatus()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Safety net: if checkAuthStatus throws or times out,
      // force unauthenticated so the splash never gets stuck.
      if (!mounted) return;
      ref.read(authProvider.notifier).forceUnauthenticated();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  double _bob(double phase) =>
      math.sin((_float.value + phase) * 2 * math.pi) * 8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 네이티브 스플래시(iOS LaunchScreen / Android launch_background)와 같은 단색.
        // 두 화면이 이어져 보이도록 색을 맞춰 둔다.
        color: const Color(0xFFFBE4F0),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 150,
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (_, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, _bob(0)),
                          child: Transform.rotate(
                            angle: -0.1,
                            child: const MoodFace(
                              moodKey: 'love',
                              size: 96,
                              pop: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.translate(
                          offset: Offset(0, _bob(0.5) - 24),
                          child: const Heartbeat(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: AppTheme.primaryColor,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.translate(
                          offset: Offset(0, _bob(0.5)),
                          child: Transform.rotate(
                            angle: 0.1,
                            child: const MoodFace(
                              moodKey: 'happy',
                              size: 96,
                              pop: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: const Text(
                    '우리연애',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 2,
                  child: const Text(
                    '우리만의 사랑 이야기',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                const FadeSlideIn(
                  index: 4,
                  child: CuteLoader(message: '불러오는 중이에요', size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
