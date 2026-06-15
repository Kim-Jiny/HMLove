import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/feed_provider.dart';
import 'comments_screen.dart';
import 'feed_card.dart';

// ─── Feed Detail Screen (scroll through posts from grid) ───

class FeedDetailScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final void Function(Feed feed) onComment;
  final void Function(Feed feed) onDelete;

  const FeedDetailScreen({
    super.key,
    required this.initialIndex,
    required this.onComment,
    required this.onDelete,
  });

  @override
  ConsumerState<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends ConsumerState<FeedDetailScreen> {
  late final PageController controller;

  @override
  void initState() {
    super.initState();
    controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feeds = ref.watch(feedProvider).feeds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시물'),
      ),
      body: PageView.builder(
        controller: controller,
        scrollDirection: Axis.vertical,
        itemCount: feeds.length,
        itemBuilder: (context, index) {
          final feed = feeds[index];
          return SingleChildScrollView(
            child: FeedCard(
                feed: feed,
                onLike: () =>
                    ref.read(feedProvider.notifier).toggleLike(feed.id),
                onComment: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentsScreen(feed: feed),
                    ),
                  );
                },
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('게시물 삭제',
                          style: TextStyle(fontSize: 16)),
                      content: const Text('이 게시물을 삭제하시겠습니까?'),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await ref
                                .read(feedProvider.notifier)
                                .deleteFeed(feed.id);
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );
                },
              ),
          );
        },
      ),
    );
  }
}
