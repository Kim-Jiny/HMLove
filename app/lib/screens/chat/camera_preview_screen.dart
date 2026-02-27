import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';

/// 카메라 촬영 후 인증마크 ON/OFF + 미리보기 화면.
/// 결과: 확정된 파일 경로를 pop으로 반환. null이면 취소.
class CameraPreviewScreen extends StatefulWidget {
  final String imagePath;

  const CameraPreviewScreen({super.key, required this.imagePath});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  bool _certMark = false;
  bool _processing = false;
  String? _locationStr;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final placemarks = await geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.locality?.isNotEmpty == true) p.locality!,
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.thoroughfare?.isNotEmpty == true) p.thoroughfare!,
        ];
        if (parts.isNotEmpty) {
          _locationStr = parts.join(' ');
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _locationLoaded = true);
  }

  Future<void> _confirm() async {
    if (_processing) return;

    if (!_certMark) {
      Navigator.pop(context, widget.imagePath);
      return;
    }

    setState(() => _processing = true);

    try {
      final result = await _applyCertMark(widget.imagePath);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증마크 적용 실패: $e')),
        );
      }
    }
  }

  Future<String> _applyCertMark(String originalPath) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko').format(now);
    final stampText = (_locationStr != null && _locationStr!.isNotEmpty)
        ? '$dateStr\n📍 $_locationStr'
        : dateStr;

    final file = File(originalPath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    final fontSize = (w * 0.032).clamp(16.0, 36.0);
    final lines = stampText.split('\n');
    final lineHeight = fontSize * 1.5;
    final totalTextHeight = lines.length * lineHeight;
    final pad = fontSize * 0.7;

    // 각 줄의 paragraph 생성 & 최대 너비 측정
    double maxTextWidth = 0;
    final paragraphs = <ui.Paragraph>[];
    for (final line in lines) {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: fontSize),
      )..pushStyle(ui.TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(1, 1)),
            Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 0)),
          ],
        ))
        ..addText(line);
      final paragraph = builder.build();
      paragraph.layout(ui.ParagraphConstraints(width: w * 0.8));
      if (paragraph.longestLine > maxTextWidth) {
        maxTextWidth = paragraph.longestLine;
      }
      paragraphs.add(paragraph);
    }

    // 우측 하단 반투명 배경
    final bgW = maxTextWidth + pad * 2;
    final bgH = totalTextHeight + pad * 1.6;
    final bgX = w - bgW - pad;
    final bgY = h - bgH - pad;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bgX, bgY, bgW, bgH),
        Radius.circular(pad * 0.5),
      ),
      Paint()..color = const Color(0x66000000),
    );

    // 텍스트 그리기
    for (int i = 0; i < paragraphs.length; i++) {
      final dx = bgX + pad;
      final dy = bgY + pad * 0.8 + (i * lineHeight);
      canvas.drawParagraph(paragraphs[i], Offset(dx, dy));
    }

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(w.toInt(), h.toInt());
    final pngBytes = await resultImage.toByteData(format: ui.ImageByteFormat.png);

    final tempFile = File('${Directory.systemTemp.path}/cert_${now.millisecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    return tempFile.path;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko').format(now);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  const Text(
                    '사진 미리보기',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // 이미지 미리보기
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                  // 인증마크 오버레이 미리보기
                  if (_certMark)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                              ),
                            ),
                            if (_locationStr != null && _locationStr!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '📍 $_locationStr',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                            ] else if (!_locationLoaded) ...[
                              const SizedBox(height: 2),
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 10, height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white70,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text('위치 확인 중...', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 하단 컨트롤
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              color: const Color(0xFF1A1A1A),
              child: Row(
                children: [
                  // 인증마크 토글
                  GestureDetector(
                    onTap: () => setState(() => _certMark = !_certMark),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _certMark
                            ? AppTheme.primaryColor.withValues(alpha: 0.2)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _certMark ? AppTheme.primaryColor : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _certMark ? Icons.verified : Icons.verified_outlined,
                            size: 20,
                            color: _certMark ? AppTheme.primaryColor : Colors.white54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '인증마크',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _certMark ? AppTheme.primaryColor : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 전송 버튼
                  GestureDetector(
                    onTap: _processing ? null : _confirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _processing
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '전송',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
