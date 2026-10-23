import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/cute/motion.dart';
import '../../core/top_snackbar.dart';
import '../../widgets/cute/loader.dart';
import '../../widgets/cute/mood_face.dart';
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
      final single = await picker.pickImage(source: ImageSource.camera);
      if (single != null) picked = [single];
    }
    if (picked.isEmpty) return;

    setModalState(() => _isUploadingImages = true);
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData();
      for (final file in picked) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(file.path, filename: file.name),
          ),
        );
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
        showTopSnackBar(context, message ?? '이미지 업로드에 실패했습니다', isError: true);
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
                      color: AppTheme.ink.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '오늘의 이야기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                      ),
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
                                  showTopSnackBar(
                                    context,
                                    error ?? '피드 작성에 실패했습니다',
                                    isError: true,
                                  );
                                }
                              }
                            },
                      child: const Text('게시', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppTheme.ink,
                                    width: 1.3,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
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
                                    () => imageUrls.removeAt(index),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.ink,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: AppTheme.ink,
                                      size: 14,
                                    ),
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
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CuteLoader(size: 12),
                        SizedBox(width: 10),
                        Text(
                          '사진을 올리는 중이에요',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.ink, width: 1.3),
                  ),
                  child: TextField(
                    controller: contentController,
                    maxLines: 5,
                    minLines: 4,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '오늘 있었던 일, 하고 싶은 말을 적어보세요',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _AttachChip(
                      icon: Icons.photo_library_rounded,
                      label: '사진',
                      onTap: _isUploadingImages || imageUrls.length >= 5
                          ? null
                          : () => _pickAndUploadImages(
                              ImageSource.gallery,
                              imageUrls,
                              setModalState,
                            ),
                    ),
                    const SizedBox(width: 8),
                    _AttachChip(
                      icon: Icons.camera_alt_rounded,
                      label: '카메라',
                      onTap: _isUploadingImages || imageUrls.length >= 5
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
                        fontWeight: FontWeight.w700,
                        color: imageUrls.length >= 5
                            ? AppTheme.errorColor
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
                  const MoodFace(moodKey: 'peaceful', size: 80, pop: true),
                  const SizedBox(height: 16),
                  const Text(
                    '아직 게시물이 없어요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '첫 번째 이야기를 공유해보세요!',
                    style: TextStyle(fontSize: 13, color: AppTheme.textHint),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await ref.read(feedProvider.notifier).fetchFeeds(refresh: true);
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
          delegate: SliverChildBuilderDelegate((context, index) {
            final feed = feeds[index];
            return GestureDetector(
              onTap: () => _openFeedDetail(index),
              child: FeedGridTile(feed: feed),
            );
          }, childCount: feeds.length),
        ),
        if (isLoading)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(padding: EdgeInsets.all(16), child: CuteLoader()),
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
            child: Padding(padding: EdgeInsets.all(16), child: CuteLoader()),
          );
        }

        final feed = feeds[index];
        return FeedCard(
          feed: feed,
          onLike: () => ref.read(feedProvider.notifier).toggleLike(feed.id),
          onComment: () => _openComments(feed),
          onDelete: () => _showDeleteConfirm(feed),
        );
      },
    );
  }

  void _openComments(Feed feed) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommentsScreen(feed: feed)),
    );
  }
}

/// 게시글 작성 시트의 사진/카메라 버튼.
class _AttachChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _AttachChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Bouncy(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.ink, width: 1.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
