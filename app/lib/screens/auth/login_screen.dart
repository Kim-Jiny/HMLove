import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/social_auth_service.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cute/motion.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // If the user landed here because of a forced logout (session expired or
    // server unreachable), show the reason once as a SnackBar so they know
    // why they're being asked to log in again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reason = ref.read(authProvider.notifier).consumeForceLogoutReason();
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason),
            duration: const Duration(seconds: 4),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      final user = ref.read(currentUserProvider);
      if (user?.coupleId != null) {
        context.go('/home');
      } else {
        context.go('/couple-connect');
      }
    }
  }

  Future<void> _handleSocialLogin(SocialProvider provider) async {
    final outcome = await ref.read(authProvider.notifier).socialLogin(provider);
    if (!mounted) return;

    switch (outcome) {
      case SocialLoginSuccess():
        // router redirect 가 인증 상태 변화로 자동 처리하지만,
        // 명시적으로 push 해서 화면이 깜빡이지 않게 한다.
        final user = ref.read(currentUserProvider);
        if (user?.coupleId != null) {
          context.go('/home');
        } else {
          context.go('/couple-connect');
        }
        break;

      case SocialLoginNeedsSignup():
        // pendingSocialSignup 이 state 에 저장되면 router redirect 가
        // /social-signup 으로 보낸다. iOS scene/deep-link 로 이 화면이
        // unmount 돼도 라우터가 복구하므로 여기서 직접 push 하지 않는다.
        break;

      case SocialLoginEmailExists(:final email, :final provider):
        await _showEmailExistsDialog(email: email, provider: provider);
        break;

      case SocialLoginFailure(:final message, :final cancelled):
        if (!cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
    }
  }

  Future<void> _showEmailExistsDialog({
    required String email,
    required SocialProvider provider,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('이미 가입된 이메일'),
          content: Text(
            '$email 은 이미 가입돼 있어요.\n'
            '먼저 이메일/비밀번호로 로그인한 다음, 더보기 > 계정 연동에서 '
            '${provider.displayName} 계정을 연결해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    // 이메일 칸에 미리 채워주면 사용자 흐름이 매끄러움.
    _emailController.text = email;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: staggered([
                const SizedBox(height: 48),
                const AuthHero(title: '우리연애', subtitle: '로그인하고 둘만의 이야기를 시작하세요'),
                const SizedBox(height: 40),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value.trim())) {
                      return '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) {
                    if (!authState.isLoading) _handleLogin();
                  },
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    hintText: '비밀번호를 입력하세요',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Error message
                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ErrorBanner(message: authState.error!),
                  ),

                const SizedBox(height: 20),

                // Login button
                AuthPrimaryButton(
                  label: '로그인',
                  loading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _handleLogin,
                ),
                const SizedBox(height: 12),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '아직 계정이 없으신가요?',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSocialDivider(),
                const SizedBox(height: 20),
                _buildSocialButtons(disabled: authState.isLoading),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(thickness: 0.6, color: AppTheme.borderColor),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '또는 간편 로그인',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const Expanded(
          child: Divider(thickness: 0.6, color: AppTheme.borderColor),
        ),
      ],
    );
  }

  Widget _buildSocialButtons({required bool disabled}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialCircleButton(
          backgroundColor: Colors.white,
          borderColor: AppTheme.borderColor,
          semanticLabel: '구글 로그인',
          disabled: disabled,
          onPressed: () => _handleSocialLogin(SocialProvider.google),
          child: const _GoogleLogo(size: 26),
        ),
        const SizedBox(width: 20),
        _SocialCircleButton(
          backgroundColor: const Color(0xFFFEE500),
          semanticLabel: '카카오 로그인',
          disabled: disabled,
          onPressed: () => _handleSocialLogin(SocialProvider.kakao),
          child: const _KakaoLogo(size: 28),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(width: 20),
          _SocialCircleButton(
            backgroundColor: Colors.black,
            semanticLabel: '애플 로그인',
            disabled: disabled,
            onPressed: () => _handleSocialLogin(SocialProvider.apple),
            child: const Icon(Icons.apple, size: 28, color: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color? borderColor;
  final String semanticLabel;
  final bool disabled;
  final VoidCallback onPressed;

  const _SocialCircleButton({
    required this.child,
    required this.backgroundColor,
    required this.semanticLabel,
    required this.disabled,
    required this.onPressed,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Bouncy(
          onTap: disabled ? null : onPressed,
          pressedScale: 0.88,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.ink,
                width: AppTheme.outlineWidth,
              ),
              boxShadow: AppTheme.cartoonShadow,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// 구글 'G' 로고. 외부 아이콘 패키지 없이 4색 호로 직접 그린다.
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _GoogleLogoPainter()),
  );
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: s / 2 - stroke / 2,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    const pi = 3.141592653589793;
    // 시계 방향: 파랑(오른쪽 위) → 초록(아래) → 노랑(왼쪽) → 빨강(위)
    canvas.drawArc(
      rect,
      -0.1 * pi,
      0.5 * pi,
      false,
      arc(const Color(0xFF4285F4)),
    );
    canvas.drawArc(
      rect,
      0.4 * pi,
      0.45 * pi,
      false,
      arc(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      0.85 * pi,
      0.4 * pi,
      false,
      arc(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      1.25 * pi,
      0.65 * pi,
      false,
      arc(const Color(0xFFEA4335)),
    );
    // 가로 막대
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.42, s * 0.45, stroke * 0.9),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 카카오톡 말풍선 로고.
class _KakaoLogo extends StatelessWidget {
  final double size;
  const _KakaoLogo({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _KakaoLogoPainter()),
  );
}

class _KakaoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = Paint()..color = const Color(0xFF191919);
    canvas.drawOval(Rect.fromLTWH(s * 0.06, s * 0.12, s * 0.88, s * 0.7), ink);
    final tail = Path()
      ..moveTo(s * 0.3, s * 0.72)
      ..lineTo(s * 0.26, s * 0.94)
      ..lineTo(s * 0.5, s * 0.8)
      ..close();
    canvas.drawPath(tail, ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
