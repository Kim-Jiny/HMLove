import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/social_auth_service.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'social_signup_screen.dart';

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
      final reason =
          ref.read(authProvider.notifier).consumeForceLogoutReason();
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

    final success = await ref.read(authProvider.notifier).login(
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

      case SocialLoginNeedsSignup(
          :final signupToken,
          :final provider,
          :final suggestedName,
          :final email,
        ):
        context.push(
          '/social-signup',
          extra: SocialSignupArgs(
            signupToken: signupToken,
            provider: provider,
            suggestedName: suggestedName,
            email: email,
          ),
        );
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
              children: [
                const SizedBox(height: 60),
                // Logo area
                const Icon(
                  Icons.favorite,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                const Text(
                  '우리연애',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '로그인하고 사랑을 시작하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value.trim())) {
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
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      authState.error!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Login button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _handleLogin,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 16),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '아직 계정이 없으신가요?',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                _buildSocialDivider(),
                const SizedBox(height: 16),
                _buildSocialButtons(disabled: authState.isLoading),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(thickness: 0.6)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(child: Divider(thickness: 0.6)),
      ],
    );
  }

  Widget _buildSocialButtons({required bool disabled}) {
    return Column(
      children: [
        _SocialButton(
          label: '카카오로 시작하기',
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF191600),
          icon: Icons.chat_bubble,
          disabled: disabled,
          onPressed: () => _handleSocialLogin(SocialProvider.kakao),
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: '구글로 시작하기',
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          icon: Icons.g_mobiledata,
          border: const BorderSide(color: Color(0xFFE0E0E0)),
          disabled: disabled,
          onPressed: () => _handleSocialLogin(SocialProvider.google),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 10),
          _SocialButton(
            label: 'Apple로 시작하기',
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            icon: Icons.apple,
            disabled: disabled,
            onPressed: () => _handleSocialLogin(SocialProvider.apple),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final BorderSide? border;
  final bool disabled;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.disabled,
    required this.onPressed,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: border ?? BorderSide.none,
          ),
        ),
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
