import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/chat_provider.dart';

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _dio = ApiClient.createDio();

  List<ChatMessage> _results = [];
  bool _isLoading = false;
  String? _nextCursor;
  bool _hasMore = true;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _search(loadMore: true);
    }
  }

  Future<void> _search({bool loadMore = false}) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    if (_isLoading) return;

    if (!loadMore) {
      _lastQuery = query;
      _results = [];
      _nextCursor = null;
      _hasMore = true;
    }

    setState(() => _isLoading = true);

    try {
      final params = <String, dynamic>{
        'q': _lastQuery,
        'limit': 20,
        if (_nextCursor != null) 'cursor': _nextCursor,
      };

      final response =
          await _dio.get('/chat/search', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final cursor = data['nextCursor'] as String?;

      setState(() {
        _results = loadMore ? [..._results, ...messages] : messages;
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
    final currentUserId = ApiClient.getUserId() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '메시지 검색...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(),
          ),
        ],
      ),
      body: _results.isEmpty && !_isLoading
          ? Center(
              child: Text(
                _lastQuery.isEmpty ? '검색어를 입력하세요' : '검색 결과가 없습니다',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 15),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _results.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _results.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final msg = _results[index];
                final isMe = msg.senderId == currentUserId;
                final name = isMe ? '나' : (msg.senderNickname ?? '상대방');

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isMe
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                    radius: 18,
                    child: Text(
                      name[0],
                      style: TextStyle(
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    msg.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '$name · ${DateFormat('M/d a h:mm', 'ko').format(msg.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textHint),
                  ),
                );
              },
            ),
    );
  }
}
