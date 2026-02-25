import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/chat_provider.dart';
import 'chat_media_gallery_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isInitialized = false;
  bool _captureMode = false;
  int? _captureStartIndex;
  int? _captureEndIndex;
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => _initialize());
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final token = ApiClient.getAccessToken();
    if (token != null) {
      ref.read(chatProvider.notifier).connect(token);
    }
    await ref.read(chatProvider.notifier).fetchHistory();
    ref.read(chatProvider.notifier).markAsRead();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      final chatState = ref.read(chatProvider);
      if (!chatState.isLoading && chatState.hasMore) {
        ref
            .read(chatProvider.notifier)
            .fetchHistory(cursor: chatState.nextCursor);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    ref.read(chatProvider.notifier).disconnect();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(content: text);
    _messageController.clear();
    ref.read(chatProvider.notifier).stopTyping();
    _focusNode.requestFocus();

    // Scroll to top (newest messages are first)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (!mounted) return;
    showTopSnackBar(context, '이미지 전송 중...', duration: const Duration(seconds: 1));

    try {
      final dio = ApiClient.createDio();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final response = await dio.post('/chat/upload', data: formData);
      final imageUrl = response.data['imageUrl'] as String;

      ref.read(chatProvider.notifier).sendMessage(
        content: '',
        imageUrl: imageUrl,
      );

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '이미지 전송 실패: $e', isError: true);
      }
    }
  }

  void _showChatMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('검색하기'),
              onTap: () {
                Navigator.pop(context);
                _openSearch();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진/영상 모아보기'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatMediaGalleryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.screenshot_outlined),
              title: const Text('캡처하기'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _captureMode = true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onCaptureTap(int index) {
    setState(() {
      if (_captureStartIndex == null) {
        _captureStartIndex = index;
        _captureEndIndex = index;
      } else {
        _captureEndIndex = index;
        // start <= end 보장
        if (_captureStartIndex! > _captureEndIndex!) {
          final tmp = _captureStartIndex;
          _captureStartIndex = _captureEndIndex;
          _captureEndIndex = tmp;
        }
      }
    });
  }

  bool _isInCaptureRange(int index) {
    if (_captureStartIndex == null) return false;
    final end = _captureEndIndex ?? _captureStartIndex!;
    final lo = _captureStartIndex! < end ? _captureStartIndex! : end;
    final hi = _captureStartIndex! > end ? _captureStartIndex! : end;
    return index >= lo && index <= hi;
  }

  Future<void> _doCaptureAndSave() async {
    if (_captureStartIndex == null) return;

    final messages = ref.read(chatProvider).messages;
    final currentUserId = ApiClient.getUserId() ?? '';
    final start = _captureStartIndex!;
    final end = _captureEndIndex ?? start;
    final lo = start < end ? start : end;
    final hi = start > end ? start : end;

    // reverse list이므로 lo=최신, hi=오래된 → reversed로 시간순 정렬
    final selected = messages.sublist(lo, hi + 1).reversed.toList();

    final captured = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CapturePreviewScreen(
          messages: selected,
          currentUserId: currentUserId,
        ),
      ),
    );

    setState(() {
      _captureMode = false;
      _captureStartIndex = null;
      _captureEndIndex = null;
    });

    if (captured == true && mounted) {
      showTopSnackBar(context, '캡처가 저장되었습니다');
    }
  }

  void _openSearch() {
    ref.read(chatProvider.notifier).enterSearchMode();
  }

  PreferredSizeWidget _buildSearchAppBar(ChatState chatState) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _exitSearch,
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _executeSearch(),
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 15),
        decoration: const InputDecoration(
          hintText: '메시지 검색...',
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (chatState.isSearching)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (chatState.searchResults.isNotEmpty) ...[
          Center(
            child: Text(
              '${chatState.currentSearchIndex + 1}/${chatState.searchResults.length}',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () async {
              final idx = await ref
                  .read(chatProvider.notifier)
                  .nextSearchResult();
              _scrollToTarget(idx);
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () async {
              final idx = await ref
                  .read(chatProvider.notifier)
                  .prevSearchResult();
              _scrollToTarget(idx);
            },
          ),
        ] else if (_searchController.text.isNotEmpty &&
            !chatState.isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '0건',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      ref.read(chatProvider.notifier).searchMessages('');
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSearch();
    });
  }

  Future<void> _executeSearch() async {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    await ref.read(chatProvider.notifier).searchMessages(text);
    final results = ref.read(chatProvider).searchResults;
    if (results.isNotEmpty) {
      final idx = await ref
          .read(chatProvider.notifier)
          .jumpToMessage(results.first.id);
      _scrollToTarget(idx);
    }
  }

  void _exitSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    ref.read(chatProvider.notifier).exitSearchMode();
  }

  void _scrollToTarget(int targetIndex) {
    // 리스트 교체 전 스크롤 리셋 (위로 튀는 현상 방지)
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final estimatedOffset = (targetIndex * 72.0).clamp(0.0, maxOffset);
      _scrollController.jumpTo(estimatedOffset);
    });
  }

  void _onLongPressMessage(ChatMessage message, bool isMe) {
    final actions = <Widget>[];

    // 복사 (모든 메시지)
    if (message.content.isNotEmpty) {
      actions.add(ListTile(
        leading: const Icon(Icons.copy),
        title: const Text('복사'),
        onTap: () {
          Clipboard.setData(ClipboardData(text: message.content));
          Navigator.pop(context);
          showTopSnackBar(context, '메시지가 복사되었습니다', duration: const Duration(seconds: 1));
        },
      ));
    }

    // 수정/삭제 (내 메시지만)
    if (isMe) {
      if (message.content.isNotEmpty) {
        actions.add(ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('수정'),
          onTap: () {
            Navigator.pop(context);
            _showEditDialog(message);
          },
        ));
      }
      actions.add(ListTile(
        leading: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('삭제', style: TextStyle(color: Colors.red)),
        onTap: () {
          Navigator.pop(context);
          _showDeleteDialog(message);
        },
      ));
    }

    if (actions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ...actions,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ChatMessage message) {
    final editController = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 수정'),
        content: TextField(
          controller: editController,
          maxLines: 5,
          minLines: 1,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '수정할 내용을 입력하세요',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                ref.read(chatProvider.notifier).editMessage(
                  messageId: message.id,
                  content: newContent,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).deleteMessage(messageId: message.id);
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      ref.read(chatProvider.notifier).startTyping();
    } else {
      ref.read(chatProvider.notifier).stopTyping();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final currentUserId = ApiClient.getUserId() ?? '';
    final isPartnerTyping = ref.watch(isPartnerTypingProvider);
    final isPartnerOnline = ref.watch(isPartnerOnlineProvider);

    return Scaffold(
      appBar: _captureMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _captureMode = false;
                  _captureStartIndex = null;
                  _captureEndIndex = null;
                }),
              ),
              title: Text(
                _captureStartIndex == null
                    ? '시작 메시지를 선택하세요'
                    : _captureEndIndex == _captureStartIndex
                        ? '끝 메시지를 선택하세요'
                        : '캡처 범위 선택됨',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                if (_captureStartIndex != null &&
                    _captureEndIndex != null &&
                    _captureEndIndex != _captureStartIndex)
                  TextButton(
                    onPressed: _doCaptureAndSave,
                    child: const Text('캡처',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
              ],
            )
          : chatState.isSearchMode
              ? _buildSearchAppBar(chatState)
              : AppBar(
              title: Column(
                children: [
                  const Text('채팅'),
                  if (isPartnerOnline)
                    const Text(
                      '온라인',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
              actions: [
                if (chatState.isConnected)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.circle, size: 8, color: Colors.green),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showChatMenu,
                ),
              ],
            ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: messages.isEmpty && !chatState.isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppTheme.textHint,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '아직 메시지가 없어요',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '첫 메시지를 보내보세요!',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: messages.length + (chatState.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Loading indicator at the end (oldest messages)
                      if (index == messages.length) {
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

                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;

                      // Show date separator
                      final showDateHeader = index == messages.length - 1 ||
                          !_isSameDay(
                            messages[index + 1].createdAt,
                            message.createdAt,
                          );

                      final isCaptureSelected =
                          _captureMode && _isInCaptureRange(index);
                      final isHighlighted = chatState.isSearchMode &&
                          message.id == chatState.highlightedMessageId;

                      return GestureDetector(
                        onTap: _captureMode
                            ? () => _onCaptureTap(index)
                            : null,
                        child: Container(
                          color: isCaptureSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : isHighlighted
                                  ? Colors.amber.withValues(alpha: 0.25)
                                  : null,
                          child: Column(
                            children: [
                              if (showDateHeader)
                                _DateHeader(date: message.createdAt),
                              _MessageBubble(
                                message: message,
                                isMe: isMe,
                                onLongPress: _captureMode
                                    ? null
                                    : () =>
                                        _onLongPressMessage(message, isMe),
                                onRetry: message.status == MessageStatus.failed
                                    ? () => ref.read(chatProvider.notifier).retryMessage(message.id)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Typing indicator
          if (isPartnerTyping && !chatState.isSearchMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              alignment: Alignment.centerLeft,
              child: const Text(
                '상대방이 입력 중...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Error banner
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.shade50,
              child: Text(
                chatState.error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ),

          // Input area (hidden in search mode)
          if (!chatState.isSearchMode)
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.image_outlined,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      onChanged: _onTextChanged,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// Date Header Widget
class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(date),
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// Message Bubble Widget
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: message.status == MessageStatus.sending ? 0.6 : 1.0,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isMe) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.status == MessageStatus.sending)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.grey.shade400,
                      ),
                    )
                  else if (message.status == MessageStatus.failed)
                    GestureDetector(
                      onTap: onRetry,
                      child: const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                    )
                  else ...[
                    if (message.isRead)
                      const Text(
                        '읽음',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    if (message.isEdited)
                      Text(
                        '수정됨',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                  Text(
                    DateFormat('a h:mm', 'ko').format(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
            // Bubble
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (message.content.isNotEmpty)
                      const SizedBox(height: 6),
                  ],
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            if (!isMe) ...[
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isEdited)
                    Text(
                      '수정됨',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  Text(
                    DateFormat('a h:mm', 'ko').format(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

// 캡처 프리뷰 & 저장 화면
class _CapturePreviewScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  final String currentUserId;

  const _CapturePreviewScreen({
    required this.messages,
    required this.currentUserId,
  });

  @override
  State<_CapturePreviewScreen> createState() => _CapturePreviewScreenState();
}

class _CapturePreviewScreenState extends State<_CapturePreviewScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveCapture() async {
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await ImageGallerySaverPlus.saveImage(bytes,
          name: 'chat_capture_${DateTime.now().millisecondsSinceEpoch}');

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '캡처 저장 실패: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캡처 미리보기'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveCapture,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _repaintKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < widget.messages.length; i++) ...[
                  if (i == 0 ||
                      !_isSameDay(widget.messages[i - 1].createdAt,
                          widget.messages[i].createdAt))
                    _DateHeader(date: widget.messages[i].createdAt),
                  _MessageBubble(
                    message: widget.messages[i],
                    isMe: widget.messages[i].senderId == widget.currentUserId,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
