import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'full_screen_image_viewer.dart';

class ChatMediaGalleryScreen extends StatefulWidget {
  const ChatMediaGalleryScreen({super.key});

  @override
  State<ChatMediaGalleryScreen> createState() => _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends State<ChatMediaGalleryScreen> {
  final _dio = ApiClient.createDio();
  final _scrollController = ScrollController();

  List<_MediaItem> _items = [];
  bool _isLoading = false;
  String? _nextCursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoading &&
        _hasMore) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final params = <String, dynamic>{
        'limit': 30,
        if (_nextCursor != null) 'cursor': _nextCursor,
      };

      final response = await _dio.get('/chat/media', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return _MediaItem(
          id: m['id'] as String,
          imageUrl: m['imageUrl'] as String,
          createdAt: DateTime.parse(m['createdAt'] as String),
        );
      }).toList();
      final cursor = data['nextCursor'] as String?;

      setState(() {
        _items = [..._items, ...messages];
        _nextCursor = cursor;
        _hasMore = cursor != null;
        _isLoading = false;
      });
    } on DioException {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('사진/영상 (${_items.length})'),
      ),
      body: _items.isEmpty && !_isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: AppTheme.textHint),
                  SizedBox(height: 16),
                  Text('주고받은 사진이 없어요',
                      style:
                          TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                ],
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _items.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                final item = _items[index];
                return GestureDetector(
                  onTap: () => _openViewer(context, index),
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image,
                          color: AppTheme.textHint),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    FullScreenImageViewer.openGallery(
      context,
      imageUrls: _items.map((e) => e.imageUrl).toList(),
      timestamps: _items.map((e) => e.createdAt).toList(),
      initialIndex: initialIndex,
    );
  }
}

class _MediaItem {
  final String id;
  final String imageUrl;
  final DateTime createdAt;

  _MediaItem({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
  });
}
