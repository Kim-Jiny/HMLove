import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../providers/feed_provider.dart';
import 'image_carousel.dart';

// ─── Instagram-style Feed Card ───

class FeedCard extends StatelessWidget {
  final Feed feed;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const FeedCard({
    super.key,
    required this.feed,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return DateFormat('M월 d일').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final authorName = feed.authorNickname ?? '알 수 없음';
    final authorImage = feed.authorProfileImage;
    final currentUserId = ApiClient.getUserId() ?? '';
    final isMyFeed = feed.authorId == currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: avatar + name + more button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    AppTheme.primaryLight.withValues(alpha: 0.3),
                backgroundImage: authorImage != null
                    ? CachedNetworkImageProvider(authorImage)
                    : null,
                child: authorImage == null
                    ? Text(
                        authorName.isNotEmpty ? authorName[0] : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  authorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isMyFeed)
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  color: AppTheme.textHint,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),

        // Image carousel or text card
        if (feed.hasImages)
          ImageCarousel(imageUrls: feed.imageUrls, onDoubleTap: onLike)
        else
          // Text-only card with styled background
          GestureDetector(
            onDoubleTap: onLike,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 200),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.08),
                    AppTheme.primaryLight.withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 40),
                  child: Text(
                    feed.content,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  feed.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: feed.isLiked ? Colors.red : AppTheme.textPrimary,
                ),
                onPressed: onLike,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: onComment,
                  ),
                  if (feed.commentCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          feed.commentCount > 99
                              ? '99+'
                              : '${feed.commentCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Like count
        if (feed.likeCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '좋아요 ${feed.likeCount}개',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

        // Content (shown below image, or skip if text-only since it's already shown)
        if (feed.hasImages && feed.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '$authorName ',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  TextSpan(
                    text: feed.content,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

        // Recent comments preview
        if (feed.recentComments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final comment in feed.recentComments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: '${comment.authorNickname ?? '알 수 없음'} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: comment.content,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Comment count - view all
        if (feed.commentCount > 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: GestureDetector(
              onTap: onComment,
              child: Text(
                '댓글 ${feed.commentCount}개 모두 보기',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),

        // Time
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            _formatTimeAgo(feed.createdAt),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textHint,
            ),
          ),
        ),

        const Divider(height: 1),
      ],
    );
  }
}
