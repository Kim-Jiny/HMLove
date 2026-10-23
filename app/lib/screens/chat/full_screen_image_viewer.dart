import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../widgets/cute/loader.dart';
import '../../widgets/cute/mood_face.dart';
import '../../widgets/cute/motion.dart';

/// 풀스크린 이미지 뷰어 (탭 바까지 가리는 전체 화면)
///
/// - 핀치/더블탭 확대, 확대 상태에서는 좌우 이동이 사진 넘김과 충돌하지 않는다.
/// - 확대하지 않았을 때 위/아래로 밀면 닫힌다.
/// - 탭하면 상단/하단 컨트롤이 숨겨지고 나타난다.
///
/// 사용법:
/// ```dart
/// FullScreenImageViewer.open(context, imageUrl: url);
/// FullScreenImageViewer.openGallery(context, imageUrls: urls, initialIndex: 0);
/// ```
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final List<DateTime?> timestamps;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.timestamps = const [],
    this.initialIndex = 0,
  });

  /// 단일 이미지 열기
  static void open(
    BuildContext context, {
    required String imageUrl,
    DateTime? timestamp,
  }) {
    openGallery(context, imageUrls: [imageUrl], timestamps: [timestamp]);
  }

  /// 갤러리 (여러 이미지 스와이프) 열기
  static void openGallery(
    BuildContext context, {
    required List<String> imageUrls,
    List<DateTime?> timestamps = const [],
    int initialIndex = 0,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => FullScreenImageViewer(
          imageUrls: imageUrls,
          timestamps: timestamps,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  /// 순검정 대신 앱 톤에 맞는 따뜻한 어두운 보라.
  static const _bg = Color(0xFF1F1824);
  static const _doubleTapScale = 2.5;
  static const _dismissDistance = 120.0;

  late final PageController _pageController;
  final TransformationController _zoom = TransformationController();
  late final AnimationController _zoomAnim;
  Animation<Matrix4>? _zoomTween;

  late int _currentIndex;
  bool _showUI = true;
  bool _saving = false;
  bool _sharing = false;

  /// 확대 중이면 true — 이때는 PageView 스와이프/밀어서 닫기를 막는다.
  bool _zoomed = false;

  /// 밀어서 닫기 진행량(px). 0 이면 제자리.
  double _dragDy = 0;
  bool _dragging = false;
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.imageUrls.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _zoomAnim =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final t = _zoomTween;
          if (t != null) _zoom.value = t.value;
        });
    _zoom.addListener(_onZoomChanged);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    _zoomAnim.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(
      begin: _zoom.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOutCubic));
    _zoomAnim.forward(from: 0);
  }

  void _onDoubleTap() {
    if (_zoomed) {
      _animateZoomTo(Matrix4.identity());
    } else {
      final p = _doubleTapAt;
      _animateZoomTo(
        Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
          ..setTranslationRaw(
            -p.dx * (_doubleTapScale - 1),
            -p.dy * (_doubleTapScale - 1),
            0,
          ),
      );
    }
  }

  // --- 밀어서 닫기 (확대하지 않았을 때, 한 손가락만) ---

  void _onInteractionStart(ScaleStartDetails d) {
    if (_zoomed || d.pointerCount != 1) return;
    _dragging = true;
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    if (!_dragging) return;
    if (d.pointerCount != 1 || _zoomed) {
      // 두 손가락(핀치)으로 바뀌면 닫기 제스처를 취소한다.
      setState(() {
        _dragging = false;
        _dragDy = 0;
      });
      return;
    }
    setState(() => _dragDy += d.focalPointDelta.dy);
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (!_dragging) return;
    final fast = d.velocity.pixelsPerSecond.dy.abs() > 800;
    if (_dragDy.abs() > _dismissDistance || fast && _dragDy.abs() > 30) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _dragging = false;
      _dragDy = 0;
    });
  }

  String get _currentUrl => widget.imageUrls[_currentIndex];

  DateTime? get _currentTimestamp => _currentIndex < widget.timestamps.length
      ? widget.timestamps[_currentIndex]
      : null;

  Future<Uint8List> _downloadCurrent() async {
    final response = await Dio().get<List<int>>(
      _currentUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _downloadCurrent();
      await ImageGallerySaverPlus.saveImage(bytes, quality: 100);
      if (mounted) showTopSnackBar(context, '사진이 저장되었습니다');
    } catch (_) {
      if (mounted) showTopSnackBar(context, '저장에 실패했습니다', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // 네트워크 이미지 다운로드 → 임시 파일로 저장 → 공유
      final bytes = await _downloadCurrent();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      if (mounted) showTopSnackBar(context, '공유에 실패했습니다', isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _toggleUI() => setState(() => _showUI = !_showUI);

  void _onPageChanged(int i) {
    // 다른 사진으로 넘기면 확대 상태를 초기화한다.
    _zoom.value = Matrix4.identity();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    // 밀수록 배경이 투명해져 아래 화면이 비친다.
    final fade = 1 - (_dragDy.abs() / 400).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 어두운 화면이라 상태바 아이콘은 밝게 (앱 기본은 어두운 아이콘)
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg.withValues(alpha: fade),
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _toggleUI,
              onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
              onDoubleTap: _onDoubleTap,
              child: AnimatedContainer(
                // 놓았을 때만 제자리로 부드럽게 복귀, 드래그 중엔 손가락을 즉시 따라간다.
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(0, _dragDy, 0),
                child: PageView.builder(
                  controller: _pageController,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: widget.imageUrls.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final isCurrent = index == _currentIndex;
                    return InteractiveViewer(
                      // 현재 페이지만 공용 컨트롤러에 연결한다.
                      transformationController: isCurrent ? _zoom : null,
                      minScale: 1.0,
                      maxScale: 5.0,
                      onInteractionStart: isCurrent
                          ? _onInteractionStart
                          : null,
                      onInteractionUpdate: isCurrent
                          ? _onInteractionUpdate
                          : null,
                      onInteractionEnd: isCurrent ? _onInteractionEnd : null,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrls[index],
                          fit: BoxFit.contain,
                          placeholder: (_, _) => const Center(
                            child: CuteLoader(size: 18, color: Colors.white70),
                          ),
                          errorWidget: (_, _, _) => const _ImageError(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 상단: 닫기 · 날짜 · 공유 · 저장
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_showUI,
                child: AnimatedOpacity(
                  opacity: _showUI && _dragDy == 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 0),
                    child: Row(
                      children: [
                        _ViewerButton(
                          icon: Icons.close_rounded,
                          tooltip: '닫기',
                          onTap: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Center(
                            child: _currentTimestamp == null
                                ? const SizedBox.shrink()
                                : _Pill(
                                    DateFormat(
                                      'yyyy.M.d (E) a h:mm',
                                      'ko_KR',
                                    ).format(_currentTimestamp!),
                                  ),
                          ),
                        ),
                        _ViewerButton(
                          icon: Icons.ios_share_rounded,
                          tooltip: '공유',
                          busy: _sharing,
                          onTap: _shareImage,
                        ),
                        const SizedBox(width: 8),
                        _ViewerButton(
                          icon: Icons.download_rounded,
                          tooltip: '저장',
                          busy: _saving,
                          onTap: _saveImage,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 하단: 페이지 표시 (여러 장일 때)
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: bottomPadding + 20,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _showUI && _dragDy == 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Center(
                      child: _Pill(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 어두운 배경 위에서도 또렷한 동그란 컨트롤 버튼 (흰 바탕 + 윤곽선).
class _ViewerButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool busy;

  const _ViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Bouncy(
        onTap: busy ? null : onTap,
        pressedScale: 0.88,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.ink, width: 1.4),
          ),
          child: busy
              ? const Center(child: CuteLoader(size: 8))
              : Icon(icon, size: 22, color: AppTheme.ink),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.ink, width: 1.3),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 사진을 불러오지 못했을 때.
class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoodFace(moodKey: 'sad', size: 72, pop: true),
        SizedBox(height: 14),
        Text(
          '사진을 불러오지 못했어요',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
