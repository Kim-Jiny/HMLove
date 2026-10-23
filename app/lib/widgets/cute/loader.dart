import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 하트 세 개가 차례로 통통 튀는 귀여운 로딩 표시.
/// 화면 전체 로딩에는 [message] 와 함께, 버튼 안 등 작은 곳엔 [size] 만 줄여 쓴다.
class CuteLoader extends StatefulWidget {
  final String? message;
  final double size;
  final Color color;

  const CuteLoader({
    super.key,
    this.message,
    this.size = 20,
    this.color = AppTheme.primaryColor,
  });

  @override
  State<CuteLoader> createState() => _CuteLoaderState();
}

class _CuteLoaderState extends State<CuteLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final hearts = AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s * 0.12),
              child: Transform.translate(
                offset: Offset(0, -_hop(i) * s * 0.7),
                child: Transform.scale(
                  scale: 0.85 + _hop(i) * 0.3,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: s,
                    color: widget.color.withValues(
                      alpha: 0.55 + _hop(i) * 0.45,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (widget.message == null) return hearts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hearts,
        SizedBox(height: s * 0.9),
        Text(
          widget.message!,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  /// i 번째 하트의 점프 정도(0~1). 시간차를 두고 한 번씩 튄다.
  double _hop(int i) {
    final t = (_c.value - i * 0.18) % 1.0;
    if (t > 0.5) return 0;
    return math.sin(t / 0.5 * math.pi);
  }
}
