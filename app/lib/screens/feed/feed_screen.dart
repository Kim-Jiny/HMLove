import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/feed_provider.dart';
import '../chat/full_screen_image_viewer.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(feedProvider.notifier).fetchFeeds(refresh: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(feedProvider.notifier).fetchFeeds(refresh: true);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages(
    ImageSource source,
    List<String> imageUrls,
    void Function(void Function()) setModalState,
  ) async {
    final picker = ImagePicker();
    List<XFile> picked = [];

    if (source == ImageSource.gallery) {
      final remaining = 5 - imageUrls.length;
      if (remaining <= 0) return;
      picked = await picker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 70,
        limit: remaining,
      );
    } else {
      final single = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 70,
      );
      if (single != null) picked = [single];
    }
    if (picked.isEmpty) return;

    setModalState(() => _isUploadingImages = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData();
      for (final file in picked) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }
      final res = await dio.post('/feed/upload', data: formData);
      final urls = (res.data['imageUrls'] as List<dynamic>)
          .map((e) => e as String)
          .toList();
      setModalState(() {
        imageUrls.addAll(urls);
        _isUploadingImages = false;
      });
    } catch (e) {
      setModalState(() => _isUploadingImages = false);
      if (mounted) {
        showTopSnackBar(context, '이미지 업로드에 실패했습니다', isError: true);
      }
    }
  }

  bool _isUploadingImages = false;

  void _showCreatePostSheet() {
    final contentController = TextEditingController();
    final imageUrls = <String>[];
    _isUploadingImages = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '새 게시물',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: _isUploadingImages
                        ? null
                        : () async {
                            final text = contentController.text.trim();
                            if (text.isEmpty && imageUrls.isEmpty) return;

                            final success = await ref
                                .read(feedProvider.notifier)
                                .createFeed(
                                  content: text,
                                  imageUrls: imageUrls,
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              if (!success) {
                                final error = ref.read(feedProvider).error;
                                showTopSnackBar(context, error ?? '피드 작성에 실패했습니다', isError: true);
                              }
                            }
                          },
                    child: const Text(
                      '게시',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Image previews
              if (imageUrls.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrls[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setModalState(
                                    () => imageUrls.removeAt(index)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (imageUrls.isNotEmpty) const SizedBox(height: 12),
              if (_isUploadingImages)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              TextField(
                controller: contentController,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '오늘의 이야기를 작성하세요...',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined,
                        color: AppTheme.primaryColor),
                    onPressed: _isUploadingImages || imageUrls.length >= 5
                        ? null
                        : () => _pickAndUploadImages(
                              ImageSource.gallery,
                              imageUrls,
                              setModalState,
                            ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: AppTheme.primaryColor),
                    onPressed: _isUploadingImages || imageUrls.length >= 5
                        ? null
                        : () => _pickAndUploadImages(
                              ImageSource.camera,
                              imageUrls,
                              setModalState,
                            ),
                  ),
                  const Spacer(),
                  Text(
                    '${imageUrls.length}/5',
                    style: TextStyle(
                      fontSize: 12,
                      color: imageUrls.length >= 5
                          ? Colors.red
                          : AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(Feed feed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시물 삭제', style: TextStyle(fontSize: 16)),
        content: const Text('이 게시물을 삭제하시겠습니까?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(feedProvider.notifier).deleteFeed(feed.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _openFeedDetail(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FeedDetailScreen(
          initialIndex: initialIndex,
          ref: ref,
          onComment: _openComments,
          onDelete: _showDeleteConfirm,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () =>
                ref.read(feedProvider.notifier).fetchFeeds(refresh: true),
          ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view_rounded,
              size: 22,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: feeds.isEmpty && !feedState.isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    '아직 게시물이 없어요',
                    style: TextStyle(
                        fontSize: 16, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '첫 번째 이야기를 공유해보세요!',
                    style:
                        TextStyle(fontSize: 13, color: AppTheme.textHint),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await ref
                    .read(feedProvider.notifier)
                    .fetchFeeds(refresh: true);
              },
              child: _isGridView
                  ? _buildGridView(feeds, feedState.isLoading)
                  : _buildListView(feeds, feedState.isLoading),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostSheet,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGridView(List<Feed> feeds, bool isLoading) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final feed = feeds[index];
              return GestureDetector(
                onTap: () => _openFeedDetail(index),
                child: _GridTile(feed: feed),
              );
            },
            childCount: feeds.length,
          ),
        ),
        if (isLoading)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView(List<Feed> feeds, bool isLoading) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: feeds.length + (isLoading ? 1 : 0),
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
        return _FeedCard(
          feed: feed,
          onLike: () =>
              ref.read(feedProvider.notifier).toggleLike(feed.id),
          onComment: () => _openComments(feed),
          onDelete: () => _showDeleteConfirm(feed),
        );
      },
    );
  }

  void _openComments(Feed feed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CommentsScreen(feed: feed),
      ),
    );
  }
}

// ─── Instagram-style Feed Card ───

class _FeedCard extends StatelessWidget {
  final Feed feed;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _FeedCard({
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
                    ? NetworkImage(authorImage)
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
          _ImageCarousel(imageUrls: feed.imageUrls, onDoubleTap: onLike)
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

// ─── Image Carousel ───

class _ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final VoidCallback onDoubleTap;

  const _ImageCarousel({
    required this.imageUrls,
    required this.onDoubleTap,
  });

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.length == 1) {
      return GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onTap: () => FullScreenImageViewer.open(
          context,
          imageUrl: widget.imageUrls.first,
        ),
        child: Image.network(
          widget.imageUrls.first,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 300,
            color: Colors.grey.shade100,
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined,
                  color: AppTheme.textHint, size: 48),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => FullScreenImageViewer.openGallery(
                    context,
                    imageUrls: widget.imageUrls,
                    initialIndex: index,
                  ),
                  child: Image.network(
                    widget.imageUrls[index],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppTheme.textHint, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Page indicator
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                widget.imageUrls.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          // Counter
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Comments Screen ───

class _CommentsScreen extends ConsumerStatefulWidget {
  final Feed feed;

  const _CommentsScreen({
    required this.feed,
  });

  @override
  ConsumerState<_CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<_CommentsScreen> {
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
                                      ? NetworkImage(avatar)
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

// ─── Grid Tile ───

class _GridTile extends StatelessWidget {
  final Feed feed;

  const _GridTile({required this.feed});

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
          Image.network(
            feed.imageUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
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

// ─── Feed Detail Screen (scroll through posts from grid) ───

class _FeedDetailScreen extends ConsumerWidget {
  final int initialIndex;
  final WidgetRef ref;
  final void Function(Feed feed) onComment;
  final void Function(Feed feed) onDelete;

  const _FeedDetailScreen({
    required this.initialIndex,
    required this.ref,
    required this.onComment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeds = ref.watch(feedProvider).feeds;
    final controller = PageController(initialPage: initialIndex);

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
            child: _FeedCard(
                feed: feed,
                onLike: () =>
                    ref.read(feedProvider.notifier).toggleLike(feed.id),
                onComment: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _CommentsScreen(feed: feed),
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
