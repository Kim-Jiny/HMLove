import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../providers/chat_provider.dart';
import '../minigame/game_result_bubble.dart';
import 'chat_image_grid.dart';
import 'location_bubble.dart';

// Message Bubble Widget
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final bool interactive;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onRetry,
    this.interactive = true,
  });

  static LocationData? _parseLocation(String content) {
    if (!content.startsWith('__LOC__:')) return null;
    final parts = content.substring(8).split(':');
    if (parts.length < 2) return null;
    final coords = parts[0].split(',');
    if (coords.length != 2) return null;
    final lat = double.tryParse(coords[0]);
    final lng = double.tryParse(coords[1]);
    if (lat == null || lng == null) return null;
    return LocationData(lat, lng, parts.length > 1 ? parts[1] : '위치');
  }

  @override
  Widget build(BuildContext context) {
    final locData = _parseLocation(message.content);

    return Opacity(
      opacity: message.status == MessageStatus.sending ? 0.6 : 1.0,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isMe) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.status == MessageStatus.sending)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.grey.shade400,
                      ),
                    )
                  else if (message.status == MessageStatus.failed)
                    GestureDetector(
                      onTap: onRetry,
                      child: const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                    )
                  else ...[
                    if (message.isRead)
                      const Text(
                        '읽음',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    if (message.isEdited)
                      Text(
                        '수정됨',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                  Text(
                    DateFormat('a h:mm', 'ko').format(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
            // Bubble
            if (locData != null)
              LocationBubble(data: locData, isMe: isMe, interactive: interactive)
            else if (GameResultBubble.isGameMessage(message.content))
              GameResultBubble(content: message.content, isMe: isMe)
            else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrls.isNotEmpty) ...[
                    ChatImageGrid(
                      message: message,
                      isMe: isMe,
                      interactive: interactive,
                    ),
                    if (message.content.isNotEmpty)
                      const SizedBox(height: 6),
                  ],
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            if (!isMe) ...[
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isEdited)
                    Text(
                      '수정됨',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  Text(
                    DateFormat('a h:mm', 'ko').format(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
