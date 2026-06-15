import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../../core/theme.dart';
import '../../../core/top_snackbar.dart';
import '../../../providers/chat_provider.dart';
import 'date_header.dart';
import 'message_bubble.dart';

// 캡처 프리뷰 & 저장 화면
class CapturePreviewScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  final String currentUserId;

  const CapturePreviewScreen({
    super.key,
    required this.messages,
    required this.currentUserId,
  });

  @override
  State<CapturePreviewScreen> createState() => _CapturePreviewScreenState();
}

class _CapturePreviewScreenState extends State<CapturePreviewScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveCapture() async {
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await ImageGallerySaverPlus.saveImage(bytes,
          name: 'chat_capture_${DateTime.now().millisecondsSinceEpoch}');

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '캡처 저장 실패: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캡처 미리보기'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveCapture,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _repaintKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < widget.messages.length; i++) ...[
                  if (i == 0 ||
                      !_isSameDay(widget.messages[i - 1].createdAt,
                          widget.messages[i].createdAt))
                    DateHeader(date: widget.messages[i].createdAt),
                  MessageBubble(
                    message: widget.messages[i],
                    isMe: widget.messages[i].senderId == widget.currentUserId,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
