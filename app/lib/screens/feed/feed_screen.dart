import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(feedProvider.notifier).fetchFeeds(refresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final feedState = ref.read(feedProvider);
      if (!feedState.isLoading && feedState.hasMore) {
        ref.read(feedProvider.notifier).fetchFeeds();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _showCreatePostSheet() {
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '새 글 작성',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final text = contentController.text.trim();
                    if (text.isEmpty) return;

                    final success = await ref
                        .read(feedProvider.notifier)
                        .createFeed(content: text);

                    if (context.mounted) {
                      Navigator.pop(context);
                      if (!success) {
                        final error = ref.read(feedProvider).error;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(error ?? '피드 작성에 실패했습니다')),
                        );
                      }
                    }
                  },
                  child: const Text(
                    '게시',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '오늘의 이야기를 작성하세요...',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined,
                      color: AppTheme.primaryColor),
                  onPressed: () {
                    // TODO: Pick image
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.location_on_outlined,
                      color: AppTheme.primaryColor),
                  onPressed: () {
                    // TODO: Add location
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(Feed feed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('피드 삭제', style: TextStyle(fontSize: 16)),
        content: const Text('이 게시글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await ref.read(feedProvider.notifier).deleteFeed(feed.id);
              if (mounted && !success) {
                final error = ref.read(feedProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error ?? '피드 삭제에 실패했습니다')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showFeedOptions(Feed feed) {
    final currentUserId = ApiClient.getUserId() ?? '';
    final isMyFeed = feed.authorId == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMyFeed)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirm(feed);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('취소'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final feeds = feedState.feeds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('피드'),
      ),
      body: feeds.isEmpty && !feedState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feed_outlined,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '아직 게시글이 없어요',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '첫 번째 이야기를 공유해보세요!',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await ref.read(feedProvider.notifier).fetchFeeds(refresh: true);
              },
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: feeds.length + (feedState.isLoading ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == feeds.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    );
                  }

                  final feed = feeds[index];
                  final currentUserId = ApiClient.getUserId() ?? '';
                  final isMyFeed = feed.authorId == currentUserId;

                  return Dismissible(
                    key: Key(feed.id),
                    direction: isMyFeed
                        ? DismissDirection.endToStart
                        : DismissDirection.none,
                    confirmDismiss: (_) async {
                      _showDeleteConfirm(feed);
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red.shade50,
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                    child: _FeedPostCard(
                      feed: feed,
                      onOptionsTap: () => _showFeedOptions(feed),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostSheet,
        child: const Icon(Icons.edit),
      ),
    );
  }
}

// Feed Post Card Widget
class _FeedPostCard extends StatelessWidget {
  final Feed feed;
  final VoidCallback onOptionsTap;

  const _FeedPostCard({
    required this.feed,
    required this.onOptionsTap,
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

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.3),
                backgroundImage: authorImage != null
                    ? NetworkImage(authorImage)
                    : null,
                child: authorImage == null
                    ? Text(
                        authorName.isNotEmpty ? authorName[0] : '?',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTimeAgo(feed.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              if (feed.type != null && feed.type != 'DIARY')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    feed.type == 'PHOTO'
                        ? '사진'
                        : feed.type == 'MILESTONE'
                            ? '기록'
                            : feed.type ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 20),
                color: AppTheme.textHint,
                onPressed: onOptionsTap,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Text(
            feed.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),

          // Image (if any)
          if (feed.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                feed.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined,
                        color: AppTheme.textHint),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              _ActionButton(
                icon: Icons.favorite_border,
                label: '좋아요',
                onTap: () {
                  // TODO: Like post
                },
              ),
              const SizedBox(width: 16),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: '댓글',
                onTap: () {
                  // TODO: Comment on post
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
