import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 누르면 쏙 눌렸다가 통통 튀며 돌아오는 탭 반응.
/// 카드·버튼·타일을 감싸서 쓴다. [onTap] 이 null 이면 반응하지 않는다.
class Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const Bouncy({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.94,
    this.haptic = true,
  });

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: widget.pressedScale).animate(
        CurvedAnimation(
          parent: _c,
          curve: Curves.easeOut,
          reverseCurve: Curves.elasticOut,
        ),
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) {
    if (widget.onTap == null) return;
    _c.forward();
  }

  void _up([_]) => _c.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// 아래에서 살짝 떠오르며 나타난다. 리스트에서 [index] 로 순차 등장시킨다.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 55),
  });

  @override
  Widget build(BuildContext context) {
    // 앞쪽 몇 개만 순차 지연을 주고 뒤쪽은 거의 즉시 — 스크롤 아래가 늦게 뜨지 않게.
    final delayMs = baseDelay.inMilliseconds * index.clamp(0, 8);
    final total = 420 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutBack),
      builder: (_, v, w) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: w),
      ),
      child: child,
    );
  }
}

/// 리스트 children 을 순서대로 FadeSlideIn 으로 감싼다.
List<Widget> staggered(List<Widget> children) => [
  for (var i = 0; i < children.length; i++)
    FadeSlideIn(index: i, child: children[i]),
];

/// 값이 바뀔 때마다 한 번 통통 튀는 반응 (좋아요 수, 뱃지 등).
class PopOnChange extends StatelessWidget {
  final Object? value;
  final Widget child;
  const PopOnChange({super.key, required this.value, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

/// 자식의 탭 처리와 경쟁하지 않고(Listener) 누르는 동안만 살짝 작아지는 반응.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  const PressScale({super.key, required this.child, this.pressedScale = 0.96});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _s =
      Tween<double>(begin: 1, end: widget.pressedScale).animate(
        CurvedAnimation(
          parent: _c,
          curve: Curves.easeOut,
          reverseCurve: Curves.elasticOut,
        ),
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _c.forward(),
      onPointerUp: (_) => _c.reverse(),
      onPointerCancel: (_) => _c.reverse(),
      child: ScaleTransition(scale: _s, child: widget.child),
    );
  }
}

/// 두근두근 — 하트 등을 일정 주기로 부풀렸다 줄인다.
class Heartbeat extends StatefulWidget {
  final Widget child;
  const Heartbeat({super.key, required this.child});

  @override
  State<Heartbeat> createState() => _HeartbeatState();
}

class _HeartbeatState extends State<Heartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        // 두 번 콩콩 뛰고 쉬는 박동 곡선
        final t = _c.value;
        double s = 1;
        if (t < 0.15) {
          s = 1 + 0.22 * Curves.easeOut.transform(t / 0.15);
        } else if (t < 0.3) {
          s = 1.22 - 0.22 * Curves.easeIn.transform((t - 0.15) / 0.15);
        } else if (t < 0.45) {
          s = 1 + 0.16 * Curves.easeOut.transform((t - 0.3) / 0.15);
        } else if (t < 0.6) {
          s = 1.16 - 0.16 * Curves.easeIn.transform((t - 0.45) / 0.15);
        }
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}
