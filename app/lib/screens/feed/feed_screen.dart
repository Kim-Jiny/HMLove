import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/feed_provider.dart';
import 'widgets/comments_screen.dart';
import 'widgets/feed_card.dart';
import 'widgets/feed_detail_screen.dart';
import 'widgets/grid_tile.dart';

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
      picked = await picker.pickMultiImage(limit: remaining);
    } else {
      final single = await picker.pickImage(
        source: ImageSource.camera,
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
      final res = await dio.post(
        '/feed/upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = res.data;
      final urls = <String>[
        if (data is Map<String, dynamic>) ...Feed.parseImageUrls(data),
        if (data is Map<String, dynamic> && data['urls'] is List)
          ...(data['urls'] as List).whereType<String>(),
        if (data is Map<String, dynamic> && data['images'] is List)
          ...(data['images'] as List).whereType<String>(),
      ].where((e) => e.isNotEmpty).toSet().toList();

      if (urls.isEmpty) {
        throw const FormatException('No uploaded image URLs in response');
      }

      setModalState(() {
        imageUrls.addAll(urls);
        _isUploadingImages = false;
      });
    } on DioException catch (e) {
      setModalState(() => _isUploadingImages = false);
      if (mounted) {
        final data = e.response?.data;
        final message = data is Map<String, dynamic>
            ? (data['message'] ?? data['error']) as String?
            : null;
        showTopSnackBar(
          context,
          message ?? '이미지 업로드에 실패했습니다',
          isError: true,
        );
      }
    } catch (e) {
      setModalState(() => _isUploadingImages = false);
      if (mounted) {
        showTopSnackBar(context, '이미지 업로드에 실패했습니다: $e', isError: true);
      }
    }
  }

  bool _isUploadingImages = false;

  Future<void> _showCreatePostSheet() async {
    final contentController = TextEditingController();
    final imageUrls = <String>[];
    _isUploadingImages = false;

    try {
      await showModalBottomSheet(
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
                              child: CachedNetworkImage(
                                imageUrl: imageUrls[index],
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
    } finally {
      contentController.dispose();
    }
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
        builder: (_) => FeedDetailScreen(
          initialIndex: initialIndex,
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
                child: FeedGridTile(feed: feed),
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
        return FeedCard(
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
        builder: (_) => CommentsScreen(feed: feed),
      ),
    );
  }
}
