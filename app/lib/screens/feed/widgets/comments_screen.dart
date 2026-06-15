import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/top_snackbar.dart';
import '../../../providers/feed_provider.dart';

// ─── Comments Screen ───

class CommentsScreen extends ConsumerStatefulWidget {
  final Feed feed;

  const CommentsScreen({
    super.key,
    required this.feed,
  });

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<FeedComment> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }



  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final dio = ApiClient.createDio();
      final res = await dio.get('/feed/${widget.feed.id}/comments');
      final data = res.data as Map<String, dynamic>;
      final list = (data['comments'] as List<dynamic>)
          .map((e) => FeedComment.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _comments = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    try {
      final dio = ApiClient.createDio();
      final res = await dio.post('/feed/${widget.feed.id}/comments', data: {
        'content': text,
      });
      final comment =
          FeedComment.fromJson(res.data['comment'] as Map<String, dynamic>);
      setState(() => _comments.add(comment));
      ref.read(feedProvider.notifier).addComment(widget.feed.id, comment);
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '댓글 작성에 실패했습니다', isError: true);
      }
    }
  }

  Future<void> _deleteComment(FeedComment comment) async {
    try {
      final dio = ApiClient.createDio();
      await dio.delete('/feed/${widget.feed.id}/comments/${comment.id}');
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
      ref.read(feedProvider.notifier).removeComment(widget.feed.id, comment.id);
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '댓글 삭제에 실패했습니다', isError: true);
      }
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분';
    if (diff.inHours < 24) return '${diff.inHours}시간';
    if (diff.inDays < 7) return '${diff.inDays}일';
    return DateFormat('M/d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    // 소켓으로 들어온 댓글 변경을 실시간 반영
    ref.listen<FeedState>(feedProvider, (prev, next) {
      final prevFeed = prev?.feeds.where((f) => f.id == widget.feed.id).firstOrNull;
      final nextFeed = next.feeds.where((f) => f.id == widget.feed.id).firstOrNull;
      if (nextFeed == null || prevFeed == null) return;
      if (prevFeed.commentCount != nextFeed.commentCount && !_isLoading) {
        _fetchComments();
      }
    });

    final currentUserId = ApiClient.getUserId() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('댓글')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 댓글이 없어요\n첫 댓글을 남겨보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final name = c.authorNickname ?? '알 수 없음';
                          final avatar = c.authorProfileImage;
                          final isMe = c.authorId == currentUserId;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.primaryLight
                                      .withValues(alpha: 0.3),
                                  backgroundImage: avatar != null
                                      ? CachedNetworkImageProvider(avatar)
                                      : null,
                                  child: avatar == null
                                      ? Text(
                                          name.isNotEmpty ? name[0] : '?',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(context)
                                              .style,
                                          children: [
                                            TextSpan(
                                              text: '$name ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            TextSpan(
                                              text: c.content,
                                              style: const TextStyle(
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _formatTime(c.createdAt),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textHint,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                              onTap: () =>
                                                  _deleteComment(c),
                                              child: const Text(
                                                '삭제',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppTheme.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          // Comment input
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: EdgeInsets.fromLTRB(
                16, 8, 8, MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: '댓글 달기...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textHint, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: AppTheme.primaryColor),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
