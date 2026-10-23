import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/poke.dart';
import '../cute/mood_face.dart';

OverlayEntry? _entry;
Timer? _timer;

/// 받은 콕을 화면 가운데에 크게 보여준다: 얼굴이 통통 튀며 나타나고 하트가 떠오른다.
/// 탭하면 바로 닫히고, 아니면 3초 뒤 사라진다.
void showPokeOverlay({required PokeKind kind, required String senderName}) {
  final overlay = rootNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  dismissPokeOverlay();

  // 두근두근: 짧은-짧은-긴 진동 느낌
  HapticFeedback.heavyImpact();
  Future.delayed(const Duration(milliseconds: 140), HapticFeedback.mediumImpact);
  Future.delayed(const Duration(milliseconds: 300), HapticFeedback.heavyImpact);

  _entry = OverlayEntry(
    builder: (_) => _PokeOverlay(
      kind: kind,
      senderName: senderName,
      onClose: dismissPokeOverlay,
    ),
  );
  overlay.insert(_entry!);
  _timer = Timer(const Duration(seconds: 3), dismissPokeOverlay);
}

void dismissPokeOverlay() {
  _timer?.cancel();
  _timer = null;
  _entry?.remove();
  _entry = null;
}

class _PokeOverlay extends StatefulWidget {
  final PokeKind kind;
  final String senderName;
  final VoidCallback onClose;
  const _PokeOverlay({
    required this.kind,
    required this.senderName,
    required this.onClose,
  });

  @override
  State<_PokeOverlay> createState() => _PokeOverlayState();
}

class _PokeOverlayState extends State<_PokeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = _c.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // 떠오르는 하트들
                for (var i = 0; i < 9; i++) _FloatingHeart(index: i, t: t),
                // 가운데 카드
                Transform.scale(
                  scale: Curves.elasticOut.transform(math.min(1, t * 2.2)),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: AppTheme.cardDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 얼굴이 살짝 흔들린다
                        Transform.rotate(
                          angle: math.sin(t * math.pi * 6) * 0.08 * (1 - t),
                          child: MoodFace(moodKey: widget.kind.moodKey, size: 120),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.senderName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.kind.label}!',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FloatingHeart extends StatelessWidget {
  final int index;
  final double t;
  const _FloatingHeart({required this.index, required this.t});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rnd = math.Random(index * 97);
    final startX = (rnd.nextDouble() - 0.5) * size.width * 0.8;
    final delay = index * 0.07;
    final p = ((t - delay) / 0.8).clamp(0.0, 1.0);
    final y = -p * size.height * 0.45 + 60;
    final opacity = (1 - p).clamp(0.0, 1.0);
    final s = 22.0 + rnd.nextDouble() * 22;
    return Transform.translate(
      offset: Offset(startX + math.sin(p * 6 + index) * 14, y),
      child: Opacity(
        opacity: p == 0 ? 0 : opacity,
        child: Icon(
          Icons.favorite_rounded,
          size: s,
          color: Color.lerp(AppTheme.primaryLight, AppTheme.primaryColor, rnd.nextDouble()),
        ),
      ),
    );
  }
}
