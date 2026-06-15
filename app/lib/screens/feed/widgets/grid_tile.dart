import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../providers/feed_provider.dart';

// ─── Grid Tile ───

class FeedGridTile extends StatelessWidget {
  final Feed feed;

  const FeedGridTile({super.key, required this.feed});

  Widget _buildOverlay() {
    if (feed.likeCount == 0 && feed.commentCount == 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (feed.likeCount > 0) ...[
              const Icon(Icons.favorite, color: Colors.white, size: 12),
              const SizedBox(width: 3),
              Text(
                '${feed.likeCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
            if (feed.likeCount > 0 && feed.commentCount > 0)
              const SizedBox(width: 10),
            if (feed.commentCount > 0) ...[
              const Icon(Icons.chat_bubble, color: Colors.white, size: 11),
              const SizedBox(width: 3),
              Text(
                '${feed.commentCount}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (feed.hasImages) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: feed.imageUrls.first,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.image_not_supported_outlined,
                  color: AppTheme.textHint),
            ),
          ),
          if (feed.imageUrls.length > 1)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.collections, color: Colors.white, size: 16),
            ),
          _buildOverlay(),
        ],
      );
    }

    // Text-only post
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.08),
                AppTheme.primaryLight.withValues(alpha: 0.18),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Center(
            child: Text(
              feed.content,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ),
        _buildOverlay(),
      ],
    );
  }
}
