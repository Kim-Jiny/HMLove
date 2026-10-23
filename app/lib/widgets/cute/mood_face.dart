import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 기분 키(`happy`, `love` …) → 직접 그린 귀여운 얼굴.
/// 이모지 대신 쓰며 어떤 기기에서도 같은 모양으로 나온다.
class MoodFace extends StatelessWidget {
  final String? moodKey;
  final double size;

  /// true 면 처음 나타날 때 통통 튀며 등장한다.
  final bool pop;

  const MoodFace({
    super.key,
    required this.moodKey,
    this.size = 48,
    this.pop = false,
  });

  @override
  Widget build(BuildContext context) {
    final face = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MoodFacePainter(moodKey)),
    );
    if (!pop) return face;
    return TweenAnimationBuilder<double>(
      key: ValueKey(moodKey),
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: face,
    );
  }
}

class _MoodStyle {
  final Color body;
  const _MoodStyle(this.body);
}

const _styles = <String, _MoodStyle>{
  'happy': _MoodStyle(Color(0xFFFFE08A)),
  'love': _MoodStyle(Color(0xFFFFB8CF)),
  'excited': _MoodStyle(Color(0xFFFFC9A0)),
  'grateful': _MoodStyle(Color(0xFFBFEBD9)),
  'peaceful': _MoodStyle(Color(0xFFBFDDF8)),
  'proud': _MoodStyle(Color(0xFFD5CCF7)),
  'missing': _MoodStyle(Color(0xFFCDE6FA)),
  'bored': _MoodStyle(Color(0xFFE4DFEA)),
  'sad': _MoodStyle(Color(0xFFB9D6F2)),
  'angry': _MoodStyle(Color(0xFFFFA9A0)),
  'tired': _MoodStyle(Color(0xFFD9D2F0)),
  'stressed': _MoodStyle(Color(0xFFC9E3DA)),
};

class _MoodFacePainter extends CustomPainter {
  final String? key;
  _MoodFacePainter(this.key);

  static const ink = AppTheme.ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final style = _styles[key];
    final body = style?.body ?? const Color(0xFFEDE8F0);

    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillInk = Paint()..color = ink;

    // 몸통 (살짝 눌린 동그라미) + 윤곽선
    final head = Rect.fromLTWH(s * 0.06, s * 0.08, s * 0.88, s * 0.84);
    canvas.drawOval(head, Paint()..color = body);
    // 하이라이트
    canvas.drawArc(
      Rect.fromLTWH(s * 0.16, s * 0.16, s * 0.34, s * 0.3),
      math.pi * 1.05,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(head, line);

    // 볼터치
    final blush = Paint()
      ..color = const Color(0xFFFF8FA8).withValues(alpha: 0.45);
    if (key != 'angry' && key != 'bored') {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.24, s * 0.62),
          width: s * 0.16,
          height: s * 0.1,
        ),
        blush,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.76, s * 0.62),
          width: s * 0.16,
          height: s * 0.1,
        ),
        blush,
      );
    }

    final lx = s * 0.35, rx = s * 0.65, ey = s * 0.48;

    void arcEye(double cx, {bool up = true}) {
      final r = Rect.fromCenter(
        center: Offset(cx, ey),
        width: s * 0.15,
        height: s * 0.15,
      );
      canvas.drawArc(r, up ? math.pi : 0, math.pi, false, line);
    }

    void dotEye(double cx, {double r = 0.035}) {
      canvas.drawCircle(Offset(cx, ey), s * r, fillInk);
    }

    void bigEye(double cx) {
      canvas.drawCircle(Offset(cx, ey), s * 0.075, fillInk);
      canvas.drawCircle(
        Offset(cx - s * 0.02, ey - s * 0.025),
        s * 0.025,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(cx + s * 0.02, ey + s * 0.02),
        s * 0.012,
        Paint()..color = Colors.white,
      );
    }

    void smile({
      double w = 0.2,
      double h = 0.12,
      double y = 0.64,
      bool open = false,
    }) {
      final r = Rect.fromCenter(
        center: Offset(s * 0.5, s * y),
        width: s * w,
        height: s * h * 2,
      );
      if (open) {
        final path = Path()
          ..addArc(r, 0, math.pi)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFE5677F));
        canvas.drawPath(path, line);
      } else {
        canvas.drawArc(r, 0.15, math.pi - 0.3, false, line);
      }
    }

    void frown({double w = 0.18, double y = 0.72}) {
      final r = Rect.fromCenter(
        center: Offset(s * 0.5, s * y),
        width: s * w,
        height: s * 0.12,
      );
      canvas.drawArc(r, math.pi + 0.2, math.pi - 0.4, false, line);
    }

    void heart(Offset c, double r, Color color) {
      final p = Path()
        ..moveTo(c.dx, c.dy + r * 0.9)
        ..cubicTo(
          c.dx - r * 1.6,
          c.dy - r * 0.2,
          c.dx - r * 0.7,
          c.dy - r * 1.3,
          c.dx,
          c.dy - r * 0.4,
        )
        ..cubicTo(
          c.dx + r * 0.7,
          c.dy - r * 1.3,
          c.dx + r * 1.6,
          c.dy - r * 0.2,
          c.dx,
          c.dy + r * 0.9,
        );
      canvas.drawPath(p, Paint()..color = color);
    }

    void sparkle(Offset c, double r, Color color) {
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(p, Paint()..color = color);
    }

    void drop(Offset c, double r) {
      final p = Path()
        ..moveTo(c.dx, c.dy - r * 1.3)
        ..cubicTo(
          c.dx + r * 1.1,
          c.dy - r * 0.1,
          c.dx + r,
          c.dy + r,
          c.dx,
          c.dy + r,
        )
        ..cubicTo(
          c.dx - r,
          c.dy + r,
          c.dx - r * 1.1,
          c.dy - r * 0.1,
          c.dx,
          c.dy - r * 1.3,
        );
      canvas.drawPath(p, Paint()..color = const Color(0xFF8CC8F5));
      canvas.drawPath(p, line..strokeWidth = s * 0.03);
      line.strokeWidth = s * 0.045;
    }

    switch (key) {
      case 'happy':
        arcEye(lx);
        arcEye(rx);
        smile(open: true, w: 0.24, h: 0.1);
      case 'love':
        heart(Offset(lx, ey), s * 0.065, const Color(0xFFE5486F));
        heart(Offset(rx, ey), s * 0.065, const Color(0xFFE5486F));
        smile(w: 0.2);
      case 'excited':
        sparkle(Offset(lx, ey), s * 0.09, const Color(0xFFFFFFFF));
        sparkle(Offset(rx, ey), s * 0.09, const Color(0xFFFFFFFF));
        canvas.drawPath(
          Path()..addArc(
            Rect.fromCenter(
              center: Offset(lx, ey),
              width: s * 0.17,
              height: s * 0.17,
            ),
            0,
            math.pi * 2,
          ),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.03,
        );
        canvas.drawPath(
          Path()..addArc(
            Rect.fromCenter(
              center: Offset(rx, ey),
              width: s * 0.17,
              height: s * 0.17,
            ),
            0,
            math.pi * 2,
          ),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.03,
        );
        smile(open: true, w: 0.28, h: 0.13, y: 0.62);
      case 'grateful':
        arcEye(lx, up: false);
        arcEye(rx, up: false);
        smile(w: 0.18);
        // 모은 손 대신 반짝이
        sparkle(Offset(s * 0.84, s * 0.2), s * 0.07, const Color(0xFFFFFFFF));
      case 'peaceful':
        arcEye(lx, up: false);
        arcEye(rx, up: false);
        smile(w: 0.12, y: 0.66);
      case 'proud':
        final glass = Paint()..color = ink;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(lx, ey),
              width: s * 0.22,
              height: s * 0.15,
            ),
            Radius.circular(s * 0.05),
          ),
          glass,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(rx, ey),
              width: s * 0.22,
              height: s * 0.15,
            ),
            Radius.circular(s * 0.05),
          ),
          glass,
        );
        canvas.drawLine(
          Offset(lx + s * 0.11, ey),
          Offset(rx - s * 0.11, ey),
          line,
        );
        canvas.drawLine(
          Offset(lx - s * 0.06, ey - s * 0.03),
          Offset(lx - s * 0.02, ey - s * 0.05),
          Paint()
            ..color = Colors.white
            ..strokeWidth = s * 0.025
            ..strokeCap = StrokeCap.round,
        );
        // 한쪽 입꼬리 올린 미소
        final m = Path()
          ..moveTo(s * 0.41, s * 0.68)
          ..quadraticBezierTo(s * 0.52, s * 0.74, s * 0.62, s * 0.64);
        canvas.drawPath(m, line);
      case 'missing':
        bigEye(lx);
        bigEye(rx);
        final m = Path()
          ..moveTo(s * 0.43, s * 0.72)
          ..quadraticBezierTo(s * 0.47, s * 0.67, s * 0.5, s * 0.72)
          ..quadraticBezierTo(s * 0.53, s * 0.77, s * 0.57, s * 0.72);
        canvas.drawPath(m, line);
      case 'bored':
        // 반쯤 감은 눈
        canvas.drawLine(
          Offset(lx - s * 0.07, ey),
          Offset(lx + s * 0.07, ey),
          line,
        );
        canvas.drawLine(
          Offset(rx - s * 0.07, ey),
          Offset(rx + s * 0.07, ey),
          line,
        );
        dotEye(lx, r: 0.02);
        dotEye(rx, r: 0.02);
        canvas.drawLine(
          Offset(s * 0.43, s * 0.7),
          Offset(s * 0.57, s * 0.7),
          line,
        );
      case 'sad':
        dotEye(lx);
        dotEye(rx);
        frown();
        drop(Offset(lx - s * 0.02, ey + s * 0.16), s * 0.04);
      case 'angry':
        canvas.drawLine(
          Offset(lx - s * 0.08, ey - s * 0.1),
          Offset(lx + s * 0.07, ey - s * 0.04),
          line,
        );
        canvas.drawLine(
          Offset(rx + s * 0.08, ey - s * 0.1),
          Offset(rx - s * 0.07, ey - s * 0.04),
          line,
        );
        dotEye(lx);
        dotEye(rx);
        frown(w: 0.16, y: 0.74);
        // 화남 표시
        final a = Paint()
          ..color = const Color(0xFFE5484D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035
          ..strokeCap = StrokeCap.round;
        final c = Offset(s * 0.82, s * 0.2);
        canvas.drawLine(c.translate(-s * 0.04, 0), c.translate(s * 0.04, 0), a);
        canvas.drawLine(c.translate(0, -s * 0.04), c.translate(0, s * 0.04), a);
      case 'tired':
        canvas.drawLine(
          Offset(lx - s * 0.06, ey),
          Offset(lx + s * 0.06, ey + s * 0.01),
          line,
        );
        canvas.drawLine(
          Offset(rx - s * 0.06, ey + s * 0.01),
          Offset(rx + s * 0.06, ey),
          line,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.7),
            width: s * 0.09,
            height: s * 0.1,
          ),
          Paint()..color = const Color(0xFFE5677F),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.7),
            width: s * 0.09,
            height: s * 0.1,
          ),
          line..strokeWidth = s * 0.03,
        );
        line.strokeWidth = s * 0.045;
        final tp = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(
              fontSize: s * 0.2,
              fontWeight: FontWeight.w700,
              color: ink.withValues(alpha: 0.7),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(s * 0.76, s * 0.02));
      case 'stressed':
        // > < 눈
        final l = Path()
          ..moveTo(lx - s * 0.06, ey - s * 0.05)
          ..lineTo(lx + s * 0.05, ey)
          ..lineTo(lx - s * 0.06, ey + s * 0.05);
        final r = Path()
          ..moveTo(rx + s * 0.06, ey - s * 0.05)
          ..lineTo(rx - s * 0.05, ey)
          ..lineTo(rx + s * 0.06, ey + s * 0.05);
        canvas.drawPath(l, line);
        canvas.drawPath(r, line);
        final w = Path()
          ..moveTo(s * 0.4, s * 0.7)
          ..quadraticBezierTo(s * 0.45, s * 0.64, s * 0.5, s * 0.7)
          ..quadraticBezierTo(s * 0.55, s * 0.76, s * 0.6, s * 0.7);
        canvas.drawPath(w, line);
        drop(Offset(s * 0.82, s * 0.24), s * 0.045);
      default:
        dotEye(lx);
        dotEye(rx);
        smile(w: 0.14);
    }
  }

  @override
  bool shouldRepaint(_MoodFacePainter old) => old.key != key;
}
