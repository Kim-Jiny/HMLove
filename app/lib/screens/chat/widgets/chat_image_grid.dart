import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../providers/chat_provider.dart';
import '../full_screen_image_viewer.dart';

class ChatImageGrid extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool interactive;

  const ChatImageGrid({
    super.key,
    required this.message,
    required this.isMe,
    required this.interactive,
  });

  @override
  Widget build(BuildContext context) {
    final urls = message.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();

    Widget imageWidget(String url, {double? width, double? height, int? overlayCount}) {
      return GestureDetector(
        onTap: interactive
            ? () {
                FullScreenImageViewer.openGallery(
                  context,
                  imageUrls: urls,
                  initialIndex: urls.indexOf(url),
                );
              }
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: isMe
                    ? Colors.pink.shade200.withValues(alpha: 0.3)
                    : const Color(0xFFF0F0F0),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: const Color(0xFFF0F0F0),
                child: const Center(
                  child: Icon(Icons.broken_image, color: AppTheme.textHint),
                ),
              ),
            ),
            if (overlayCount != null && overlayCount > 0)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Text(
                    '+$overlayCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: () {
        if (urls.length == 1) {
          return SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 1.2,
              child: imageWidget(urls[0]),
            ),
          );
        }
        if (urls.length == 2) {
          return Row(
            children: [
              Expanded(child: AspectRatio(aspectRatio: 0.8, child: imageWidget(urls[0]))),
              const SizedBox(width: 2),
              Expanded(child: AspectRatio(aspectRatio: 0.8, child: imageWidget(urls[1]))),
            ],
          );
        }
        if (urls.length == 3) {
          return Column(
            children: [
              AspectRatio(aspectRatio: 1.8, child: imageWidget(urls[0])),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[1]))),
                  const SizedBox(width: 2),
                  Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[2]))),
                ],
              ),
            ],
          );
        }
        // 4장 이상: 2x2 그리드 + 오버레이
        final showOverlay = urls.length > 4;
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[0]))),
                const SizedBox(width: 2),
                Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[1]))),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[2]))),
                const SizedBox(width: 2),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: imageWidget(
                      urls[3],
                      overlayCount: showOverlay ? urls.length - 4 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }(),
    );
  }
}
