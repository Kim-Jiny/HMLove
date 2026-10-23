import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/wish_item.dart';

/// 위시리스트 카테고리 등에 쓰는 작은 스티커 일러스트 (이모지 대체).
enum StickerKind { pin, food, target, sparkle, heart, gift }

class Sticker extends StatelessWidget {
  final StickerKind kind;
  final double size;
  const Sticker(this.kind, {super.key, this.size = 22});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _StickerPainter(kind)),
  );
}

class _StickerPainter extends CustomPainter {
  final StickerKind kind;
  _StickerPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final line = Paint()
      ..color = AppTheme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c;

    switch (kind) {
      case StickerKind.pin:
        final p = Path()
          ..moveTo(s * 0.5, s * 0.94)
          ..cubicTo(s * 0.1, s * 0.55, s * 0.14, s * 0.08, s * 0.5, s * 0.08)
          ..cubicTo(s * 0.86, s * 0.08, s * 0.9, s * 0.55, s * 0.5, s * 0.94);
        canvas.drawPath(p, fill(const Color(0xFFFF9DB8)));
        canvas.drawPath(p, line);
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.4),
          s * 0.14,
          fill(Colors.white),
        );
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.4),
          s * 0.14,
          line..strokeWidth = s * 0.05,
        );
      case StickerKind.food:
        // 주먹밥(삼각김밥)
        final p = Path()
          ..moveTo(s * 0.5, s * 0.1)
          ..quadraticBezierTo(s * 0.62, s * 0.1, s * 0.9, s * 0.78)
          ..quadraticBezierTo(s * 0.92, s * 0.9, s * 0.8, s * 0.9)
          ..lineTo(s * 0.2, s * 0.9)
          ..quadraticBezierTo(s * 0.08, s * 0.9, s * 0.1, s * 0.78)
          ..quadraticBezierTo(s * 0.38, s * 0.1, s * 0.5, s * 0.1);
        canvas.drawPath(p, fill(Colors.white));
        canvas.drawPath(p, line);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.28, s * 0.62, s * 0.44, s * 0.28),
            Radius.circular(s * 0.04),
          ),
          fill(const Color(0xFF6E7F6A)),
        );
        canvas.drawCircle(
          Offset(s * 0.42, s * 0.45),
          s * 0.03,
          fill(AppTheme.ink),
        );
        canvas.drawCircle(
          Offset(s * 0.58, s * 0.45),
          s * 0.03,
          fill(AppTheme.ink),
        );
      case StickerKind.target:
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.5),
          s * 0.42,
          fill(Colors.white),
        );
        canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.42, line);
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.5),
          s * 0.26,
          fill(const Color(0xFFFF9DB8)),
        );
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.5),
          s * 0.26,
          line..strokeWidth = s * 0.05,
        );
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.5),
          s * 0.09,
          fill(AppTheme.ink),
        );
      case StickerKind.sparkle:
        Path star(Offset c, double r) => Path()
          ..moveTo(c.dx, c.dy - r)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
        final big = star(Offset(s * 0.45, s * 0.55), s * 0.38);
        canvas.drawPath(big, fill(const Color(0xFFFFE08A)));
        canvas.drawPath(big, line..strokeWidth = s * 0.06);
        final small = star(Offset(s * 0.8, s * 0.2), s * 0.15);
        canvas.drawPath(small, fill(const Color(0xFFFFE08A)));
        canvas.drawPath(small, line..strokeWidth = s * 0.05);
      case StickerKind.heart:
        final c = Offset(s * 0.5, s * 0.52);
        final r = s * 0.34;
        final p = Path()
          ..moveTo(c.dx, c.dy + r * 1.1)
          ..cubicTo(
            c.dx - r * 1.9,
            c.dy - r * 0.2,
            c.dx - r * 0.9,
            c.dy - r * 1.5,
            c.dx,
            c.dy - r * 0.5,
          )
          ..cubicTo(
            c.dx + r * 0.9,
            c.dy - r * 1.5,
            c.dx + r * 1.9,
            c.dy - r * 0.2,
            c.dx,
            c.dy + r * 1.1,
          );
        canvas.drawPath(p, fill(const Color(0xFFFF7FA3)));
        canvas.drawPath(p, line);
        canvas.drawArc(
          Rect.fromLTWH(s * 0.22, s * 0.26, s * 0.2, s * 0.2),
          math.pi,
          math.pi * 0.6,
          false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.06
            ..strokeCap = StrokeCap.round,
        );
      case StickerKind.gift:
        final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.14, s * 0.4, s * 0.72, s * 0.5),
          Radius.circular(s * 0.06),
        );
        canvas.drawRRect(box, fill(const Color(0xFFD5CCF7)));
        canvas.drawRRect(box, line);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.1, s * 0.28, s * 0.8, s * 0.16),
            Radius.circular(s * 0.05),
          ),
          fill(const Color(0xFFFF9DB8)),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.1, s * 0.28, s * 0.8, s * 0.16),
            Radius.circular(s * 0.05),
          ),
          line,
        );
        canvas.drawLine(
          Offset(s * 0.5, s * 0.28),
          Offset(s * 0.5, s * 0.9),
          line,
        );
        final bow = Path()
          ..moveTo(s * 0.5, s * 0.28)
          ..quadraticBezierTo(s * 0.3, s * 0.04, s * 0.26, s * 0.2)
          ..quadraticBezierTo(s * 0.3, s * 0.3, s * 0.5, s * 0.28)
          ..quadraticBezierTo(s * 0.7, s * 0.04, s * 0.74, s * 0.2)
          ..quadraticBezierTo(s * 0.7, s * 0.3, s * 0.5, s * 0.28);
        canvas.drawPath(bow, line);
    }
  }

  @override
  bool shouldRepaint(_StickerPainter old) => old.kind != kind;
}

/// 위시리스트 카테고리 → 스티커.
StickerKind stickerFor(WishCategory c) => switch (c) {
  WishCategory.PLACE => StickerKind.pin,
  WishCategory.FOOD => StickerKind.food,
  WishCategory.ACTIVITY => StickerKind.target,
  WishCategory.OTHER => StickerKind.sparkle,
};
