import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

class ChatLinksScreen extends StatefulWidget {
  const ChatLinksScreen({super.key});

  @override
  State<ChatLinksScreen> createState() => _ChatLinksScreenState();
}

class _ChatLinksScreenState extends State<ChatLinksScreen> {
  static final _urlRegex = RegExp(
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  final _dio = ApiClient.createDio();
  final _scrollController = ScrollController();

  List<_LinkItem> _items = [];
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

      final response =
          await _dio.get('/chat/links', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final messages = data['messages'] as List;
      final cursor = data['nextCursor'] as String?;

      final newItems = <_LinkItem>[];
      for (final m in messages) {
        final msg = m as Map<String, dynamic>;
        final content = msg['content'] as String? ?? '';
        final urls = _urlRegex.allMatches(content).map((m) => m.group(0)!).toList();
        if (urls.isEmpty) continue;

        final sender = msg['sender'] as Map<String, dynamic>?;
        final senderName = sender?['nickname'] as String? ?? '';
        final createdAt = DateTime.parse(msg['createdAt'] as String);

        for (final url in urls) {
          newItems.add(_LinkItem(
            url: url,
            senderName: senderName,
            content: content,
            createdAt: createdAt,
          ));
        }
      }

      setState(() {
        _items = [..._items, ...newItems];
        _nextCursor = cursor;
        _hasMore = cursor != null;
        _isLoading = false;
      });
    } on DioException {
      setState(() => _isLoading = false);
    }
  }

  String _displayUrl(String url) {
    var display = url.replaceFirst(RegExp(r'^https?://'), '');
    if (display.length > 60) {
      display = '${display.substring(0, 57)}...';
    }
    return display;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('링크 모아보기 (${_items.length})'),
      ),
      body: _items.isEmpty && !_isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, size: 64, color: AppTheme.textHint),
                  SizedBox(height: 16),
                  Text(
                    '주고받은 링크가 없어요',
                    style:
                        TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length + (_isLoading ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final item = _items[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.link,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  title: Text(
                    _displayUrl(item.url),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.senderName} · ${DateFormat('M/d a h:mm', 'ko').format(item.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textHint),
                  ),
                  onTap: () => _openUrl(item.url),
                );
              },
            ),
    );
  }
}

class _LinkItem {
  final String url;
  final String senderName;
  final String content;
  final DateTime createdAt;

  _LinkItem({
    required this.url,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });
}
