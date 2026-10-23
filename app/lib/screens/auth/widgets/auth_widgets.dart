import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/cute/mood_face.dart';
import '../../../widgets/cute/motion.dart';

/// 로그인/회원가입 상단의 마스코트 헤더. 두 얼굴이 번갈아 통통 떠다닌다.
class AuthHero extends StatefulWidget {
  final String title;
  final String subtitle;
  final String leftMood;
  final String rightMood;
  final bool compact;

  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.leftMood = 'love',
    this.rightMood = 'happy',
    this.compact = false,
  });

  @override
  State<AuthHero> createState() => _AuthHeroState();
}

class _AuthHeroState extends State<AuthHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _bob(double phase) => math.sin((_c.value + phase) * 2 * math.pi) * 6;

  @override
  Widget build(BuildContext context) {
    final face = widget.compact ? 64.0 : 84.0;
    return Column(
      children: [
        SizedBox(
          height: face + 24,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, _bob(0)),
                  child: Transform.rotate(
                    angle: -0.08,
                    child: MoodFace(
                      moodKey: widget.leftMood,
                      size: face,
                      pop: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Heartbeat(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppTheme.primaryColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Transform.translate(
                  offset: Offset(0, _bob(0.5)),
                  child: Transform.rotate(
                    angle: 0.08,
                    child: MoodFace(
                      moodKey: widget.rightMood,
                      size: face,
                      pop: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: widget.compact ? 12 : 20),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: widget.compact ? 24 : 32,
            fontWeight: FontWeight.w700,
            color: widget.compact
                ? AppTheme.textPrimary
                : AppTheme.primaryColor,
            letterSpacing: widget.compact ? -0.5 : 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 에러 메시지: 슬픈 얼굴 + 좌우로 흔들리며 등장.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(message),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (_, v, child) => Transform.translate(
        offset: Offset(math.sin(v * math.pi * 5) * 8 * (1 - v), 0),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.ink, width: 1.3),
        ),
        child: Row(
          children: [
            const MoodFace(moodKey: 'sad', size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 비밀번호 강도 막대(약함/보통/좋아요). 6자 미만이면 0칸.
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  int get _level {
    if (password.length < 6) return 0;
    var score = 1;
    if (password.length >= 10) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score.clamp(1, 3);
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final level = _level;
    const labels = ['6자 이상 입력해주세요', '조금 약해요', '괜찮아요', '아주 좋아요'];
    final colors = [
      AppTheme.textHint,
      AppTheme.peach,
      AppTheme.butter,
      AppTheme.mint,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 6,
                decoration: BoxDecoration(
                  color: i < level ? colors[level] : AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 4),
          ],
          const SizedBox(width: 10),
          Text(
            labels[level],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors[level],
            ),
          ),
        ],
      ),
    );
  }
}

/// 눌림 반응이 있는 메인 버튼(로딩 스피너 포함).
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      pressedScale: 0.97,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: onPressed == null ? null : AppTheme.cartoonShadow,
        ),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: onPressed,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(label, key: const ValueKey('label')),
            ),
          ),
        ),
      ),
    );
  }
}
