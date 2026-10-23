import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/social_auth_service.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cute/motion.dart';
import 'widgets/auth_widgets.dart';

class SocialSignupScreen extends ConsumerStatefulWidget {
  const SocialSignupScreen({super.key});

  @override
  ConsumerState<SocialSignupScreen> createState() => _SocialSignupScreenState();
}

class _SocialSignupScreenState extends ConsumerState<SocialSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _birthDateController = TextEditingController();
  DateTime? _birthDate;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final pending = ref.read(authProvider).pendingSocialSignup;
      if (pending?.suggestedName != null &&
          pending!.suggestedName!.isNotEmpty) {
        _nicknameController.text = pending.suggestedName!;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: '생년월일을 선택하세요',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = DateFormat('yyyy년 M월 d일').format(picked);
      });
    }
  }

  Future<void> _handleSubmit(SocialLoginNeedsSignup pending) async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref
        .read(authProvider.notifier)
        .completeSocialSignup(
          signupToken: pending.signupToken,
          nickname: _nicknameController.text.trim(),
          birthDate: _birthDate,
        );

    if (!mounted) return;
    if (ok) {
      final user = ref.read(currentUserProvider);
      if (user?.coupleId != null) {
        context.go('/home');
      } else {
        context.go('/couple-connect');
      }
    }
  }

  void _cancelAndPop() {
    ref.read(authProvider.notifier).clearPendingSocialSignup();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final pending = authState.pendingSocialSignup;

    // 직접 진입 / 새로고침 / 취소 후 잘못된 진입 등 안전장치.
    if (pending == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go('/login'),
          ),
        ),
        body: const Center(
          child: Text(
            '가입 정보가 만료되었어요. 다시 시도해주세요.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _cancelAndPop,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: staggered([
                AuthHero(
                  compact: true,
                  leftMood: 'happy',
                  rightMood: 'love',
                  title: '${pending.provider.displayName} 계정으로 시작하기',
                  subtitle: '닉네임과 생년월일만 입력하면 끝나요',
                ),
                const SizedBox(height: 28),

                if (pending.email != null && pending.email!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.ink, width: 1.3),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pending.email!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                TextFormField(
                  controller: _nicknameController,
                  maxLength: 12,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '2~12자',
                    counterText: '',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요';
                    if (v.trim().length < 2) return '닉네임은 2자 이상이어야 합니다';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: _selectBirthDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _birthDateController,
                      decoration: const InputDecoration(
                        labelText: '생년월일 (선택)',
                        hintText: '별자리/운세에 사용돼요',
                        prefixIcon: Icon(Icons.cake_outlined),
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (authState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ErrorBanner(message: authState.error!),
                  ),

                AuthPrimaryButton(
                  label: '가입 완료',
                  loading: authState.isLoading,
                  onPressed: authState.isLoading
                      ? null
                      : () => _handleSubmit(pending),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
