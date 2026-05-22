import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _quietSend = false;

  // 배경 사진 + 변환 상태. 사진은 RepaintBoundary 안의 Stack 맨 아래 레이어에
  // 그리고 ClipRRect 로 캔버스 크기 밖은 자동으로 잘림.
  Uint8List? _bgImageBytes;
  Offset _imgOffset = Offset.zero;
  double _imgRotation = 0;
  double _imgScale = 1.0;
  bool _transformMode = false;

  // ScaleGesture 시작 시점 스냅샷(여기서 누적 회전/스케일/이동을 계산).
  double _scaleStart = 1.0;
  double _rotationStart = 0;
  Offset _focalStart = Offset.zero;
  Offset _offsetStart = Offset.zero;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(
        _Stroke(
          points: [details.localPosition],
          color: _currentColor,
          width: _currentWidth,
          isEraser: _isEraser,
        ),
      );
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _bgImageBytes = bytes;
      // 새 사진을 올리면 transform 상태 초기화 + 조정 모드로 진입.
      _imgOffset = Offset.zero;
      _imgRotation = 0;
      _imgScale = 1.0;
      _transformMode = true;
    });
  }

  void _removeImage() {
    setState(() {
      _bgImageBytes = null;
      _transformMode = false;
    });
  }

  void _onScaleStart(ScaleStartDetails d) {
    _scaleStart = _imgScale;
    _rotationStart = _imgRotation;
    _focalStart = d.focalPoint;
    _offsetStart = _imgOffset;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      // 캔버스를 벗어날 만큼 키울 수 있게 상한 넉넉히. 하한도 살짝만.
      _imgScale = (_scaleStart * d.scale).clamp(0.1, 10.0);
      _imgRotation = _rotationStart + d.rotation;
      _imgOffset = _offsetStart + (d.focalPoint - _focalStart);
    });
  }

  Future<Uint8List?> _exportPng() async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // 서버가 512px로 다운사이즈하므로 클라이언트도 그 근처(~560-600px)만 보내면 충분.
    // pixelRatio 2.0 정도면 선이 깨지지 않으면서 업로드 페이로드도 가벼움.
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _send() async {
    if (_strokes.isEmpty && _bgImageBytes == null) {
      showTopSnackBar(context, '먼저 그림이나 사진을 추가해주세요.', isError: true);
      return;
    }

    final pngBytes = await _exportPng();
    if (pngBytes == null) {
      if (mounted) showTopSnackBar(context, '그림을 변환하지 못했어요.', isError: true);
      return;
    }

    final doodle = await ref
        .read(doodleProvider.notifier)
        .sendDoodle(pngBytes, quiet: _quietSend);
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
    final hasImage = _bgImageBytes != null;

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
                        child: Stack(
                          children: [
                            // RepaintBoundary 안이 PNG로 export 되는 영역.
                            // 모드 토글/안내 배너는 boundary 밖에 두어 export 결과엔 안 찍힘.
                            RepaintBoundary(
                              key: _canvasKey,
                              child: Container(
                                color: Colors.white,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 1) 배경 사진 (있을 때만). 캔버스 밖으로 키워도 ClipRRect 가 잘라줌.
                                    if (hasImage)
                                      Center(
                                        child: Transform.translate(
                                          offset: _imgOffset,
                                          child: Transform.rotate(
                                            angle: _imgRotation,
                                            child: Transform.scale(
                                              scale: _imgScale,
                                              child: Image.memory(
                                                _bgImageBytes!,
                                                fit: BoxFit.contain,
                                                gaplessPlayback: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // 2) 펜 스트로크 (항상 보임, IgnorePointer 로 위 gesture 에 양보)
                                    IgnorePointer(
                                      child: CustomPaint(
                                        painter: _DoodlePainter(_strokes),
                                        size: Size.infinite,
                                      ),
                                    ),
                                    // 3) Gesture catcher — 모드에 따라 한 손가락 드래그(그리기) /
                                    //    두 손가락 핀치·회전(사진 조정) 으로 동작
                                    if (_transformMode)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onScaleStart: _onScaleStart,
                                        onScaleUpdate: _onScaleUpdate,
                                        child: const SizedBox.expand(),
                                      )
                                    else
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onPanStart: _onPanStart,
                                        onPanUpdate: _onPanUpdate,
                                        child: const SizedBox.expand(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            // 4) 사진 조정 모드 배너 (PNG 에는 안 들어감 — boundary 밖)
                            if (_transformMode && hasImage)
                              Positioned(
                                top: 8,
                                left: 8,
                                right: 8,
                                child: _TransformBanner(
                                  onDone: () =>
                                      setState(() => _transformMode = false),
                                  onRemove: _removeImage,
                                ),
                              ),
                          ],
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
              hasImage: hasImage,
              transformMode: _transformMode,
              onColor: (c) => setState(() {
                _currentColor = c;
                _isEraser = false;
              }),
              onWidth: (w) => setState(() => _currentWidth = w),
              onEraserToggle: () => setState(() => _isEraser = !_isEraser),
              onUndo: _undo,
              onClear: _clear,
              onPickImage: _pickImage,
              onToggleTransform: () =>
                  setState(() => _transformMode = !_transformMode),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuietSendOption(
                value: _quietSend,
                onChanged: isSending
                    ? null
                    : (value) => setState(() => _quietSend = value),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _QuietSendOption extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _QuietSendOption({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF1E6DF)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged == null
                    ? null
                    : (checked) => onChanged!(checked ?? false),
                activeColor: AppTheme.primaryColor,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  '조용히 보내기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A3A35),
                  ),
                ),
              ),
              const Icon(
                Icons.notifications_off_outlined,
                size: 20,
                color: Color(0xFF8E6B75),
              ),
            ],
          ),
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
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) {
    // setState 에서 같은 _strokes 리스트의 끝점에 point 를 push 하는 식이라
    // 리스트 참조도 같고 length 도 그대로일 수 있다(=stroke 진행 중).
    // 그래서 무조건 repaint. stroke 개수가 수백 단위라 비용 무시 가능.
    return true;
  }
}

class _TransformBanner extends StatelessWidget {
  final VoidCallback onDone;
  final VoidCallback onRemove;

  const _TransformBanner({required this.onDone, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '✋ 사진 조정 중\n두 손가락으로 회전·확대',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '사진 제거',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onRemove,
            ),
            TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
              ),
              child: const Text(
                '완료',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final List<Color> palette;
  final List<double> widths;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;
  final bool hasImage;
  final bool transformMode;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onWidth;
  final VoidCallback onEraserToggle;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onPickImage;
  final VoidCallback onToggleTransform;

  const _Toolbar({
    required this.palette,
    required this.widths,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
    required this.hasImage,
    required this.transformMode,
    required this.onColor,
    required this.onWidth,
    required this.onEraserToggle,
    required this.onUndo,
    required this.onClear,
    required this.onPickImage,
    required this.onToggleTransform,
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
                    icon: Icons.add_photo_alternate_outlined,
                    onTap: onPickImage,
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: 6),
                    _IconButton(
                      icon: Icons.open_with_rounded,
                      selected: transformMode,
                      onTap: onToggleTransform,
                    ),
                  ],
                  const SizedBox(width: 6),
                  _IconButton(icon: Icons.undo_rounded, onTap: onUndo),
                  const SizedBox(width: 6),
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
