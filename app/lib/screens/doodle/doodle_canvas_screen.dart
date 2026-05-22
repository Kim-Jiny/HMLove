import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/doodle_provider.dart';

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  _Stroke({
    required this.points,
    required this.color,
    required this.width,
    required this.isEraser,
  });
}

class DoodleCanvasScreen extends ConsumerStatefulWidget {
  const DoodleCanvasScreen({super.key});

  @override
  ConsumerState<DoodleCanvasScreen> createState() => _DoodleCanvasScreenState();
}

class _DoodleCanvasScreenState extends ConsumerState<DoodleCanvasScreen> {
  static const _palette = <Color>[
    Color(0xFF333333),
    Color(0xFFE91E63),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFFFFB300),
  ];

  static const _widths = <double>[3.0, 6.0, 12.0];

  final GlobalKey _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = <_Stroke>[];
  Color _currentColor = _palette.first;
  double _currentWidth = _widths[1];
  bool _isEraser = false;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(_Stroke(
        points: [details.localPosition],
        color: _currentColor,
        width: _currentWidth,
        isEraser: _isEraser,
      ));
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.last.points.add(details.localPosition);
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.removeLast();
    });
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.clear();
    });
  }

  Future<Uint8List?> _exportPng() async {
    final boundary = _canvasKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // 서버가 512px로 다운사이즈하므로 클라이언트도 그 근처(~560-600px)만 보내면 충분.
    // pixelRatio 2.0 정도면 선이 깨지지 않으면서 업로드 페이로드도 가벼움.
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _send() async {
    if (_strokes.isEmpty) {
      showTopSnackBar(context, '먼저 그림을 그려주세요.', isError: true);
      return;
    }

    final pngBytes = await _exportPng();
    if (pngBytes == null) {
      if (mounted) showTopSnackBar(context, '그림을 변환하지 못했어요.', isError: true);
      return;
    }

    final doodle =
        await ref.read(doodleProvider.notifier).sendDoodle(pngBytes);
    if (!mounted) return;
    if (doodle == null) {
      final err = ref.read(doodleProvider).error;
      showTopSnackBar(context, err ?? '그림 전송에 실패했습니다.', isError: true);
      return;
    }
    showTopSnackBar(context, '🎨 그림을 보냈어요!');
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(doodleProvider.select((s) => s.isSending));

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F2),
      appBar: AppBar(
        title: const Text('그림 보내기'),
        actions: [
          TextButton(
            onPressed: isSending ? null : _send,
            child: isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '보내기',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.biggest.shortestSide - 16;
                    return Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RepaintBoundary(
                          key: _canvasKey,
                          child: Container(
                            color: Colors.white,
                            child: GestureDetector(
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              child: CustomPaint(
                                painter: _DoodlePainter(_strokes),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Toolbar(
              palette: _palette,
              widths: _widths,
              currentColor: _currentColor,
              currentWidth: _currentWidth,
              isEraser: _isEraser,
              onColor: (c) => setState(() {
                _currentColor = c;
                _isEraser = false;
              }),
              onWidth: (w) => setState(() => _currentWidth = w),
              onEraserToggle: () => setState(() => _isEraser = !_isEraser),
              onUndo: _undo,
              onClear: _clear,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final List<_Stroke> strokes;

  _DoodlePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.isEraser ? Colors.white : stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length < 2) {
        canvas.drawCircle(stroke.points.first, stroke.width / 2,
            paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.strokes != strokes || old.strokes.length != strokes.length;
}

class _Toolbar extends StatelessWidget {
  final List<Color> palette;
  final List<double> widths;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onWidth;
  final VoidCallback onEraserToggle;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const _Toolbar({
    required this.palette,
    required this.widths,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
    required this.onColor,
    required this.onWidth,
    required this.onEraserToggle,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1E6DF)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final c in palette)
                _ColorDot(
                  color: c,
                  selected: !isEraser && currentColor == c,
                  onTap: () => onColor(c),
                ),
              _IconButton(
                icon: Icons.cleaning_services_outlined,
                selected: isEraser,
                onTap: onEraserToggle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (final w in widths)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _WidthDot(
                        width: w,
                        selected: currentWidth == w,
                        onTap: () => onWidth(w),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  _IconButton(
                    icon: Icons.undo_rounded,
                    onTap: onUndo,
                  ),
                  const SizedBox(width: 8),
                  _IconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: onClear,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _WidthDot extends StatelessWidget {
  final double width;
  final bool selected;
  final VoidCallback onTap;

  const _WidthDot({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Container(
            width: width + 4,
            height: width + 4,
            decoration: const BoxDecoration(
              color: Color(0xFF333333),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : const Color(0xFFF7F2EE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? AppTheme.primaryColor : Colors.black87,
        ),
      ),
    );
  }
}
