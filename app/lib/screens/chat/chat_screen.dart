import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/chat_provider.dart';
import '../../providers/couple_provider.dart';
import 'camera_preview_screen.dart';
import 'chat_links_screen.dart';
import 'chat_media_gallery_screen.dart';
import 'full_screen_image_viewer.dart';
import 'location_picker_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isInitialized = false;
  bool _captureMode = false;
  bool _showAttachPanel = false;
  bool _deleteMode = false;
  final Set<String> _selectedForDelete = {};
  int? _captureStartIndex;
  int? _captureEndIndex;
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(_onFocusChanged);
    Future.microtask(() => _initialize());
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showAttachPanel) {
      setState(() => _showAttachPanel = false);
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final notifier = ref.read(chatProvider.notifier);
    final token = ApiClient.getAccessToken();
    if (token != null) {
      notifier.connect(token);
    }
    await notifier.fetchHistory();
    notifier.markAsRead();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 포그라운드 복귀 → 소켓 재연결 + 최신 메시지 가져오기
      final notifier = ref.read(chatProvider.notifier);
      final token = ApiClient.getAccessToken();
      if (token != null) {
        notifier.connect(token);
      }
      notifier.fetchHistory();
      // 채팅 탭이 활성 상태일 때만 읽음 처리
      if (notifier.isChatScreenActive) {
        notifier.markAsRead();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _focusNode.removeListener(_onFocusChanged);
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

  Future<void> _pickAndSendImage(ImageSource source) async {
    setState(() => _showAttachPanel = false);

    final picker = ImagePicker();

    if (source == ImageSource.gallery) {
      // 다중 이미지 선택 (최대 5장)
      final pickedList = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
        limit: 5,
      );
      if (pickedList.isEmpty || !mounted) return;
      final files = pickedList.take(5).toList();
      await _uploadAndSendImages(files);
      return;
    }

    // 카메라 촬영 (단일)
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (source == ImageSource.camera && mounted) {
      final resultPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => CameraPreviewScreen(imagePath: picked.path),
        ),
      );
      if (resultPath == null || !mounted) return;
      await _uploadAndSendImages([XFile(resultPath)]);
      return;
    }

    if (!mounted) return;
    await _uploadAndSendImages([picked]);
  }

  Future<void> _uploadAndSendImages(List<XFile> files) async {
    showTopSnackBar(
      context,
      files.length == 1 ? '이미지 전송 중...' : '이미지 ${files.length}장 전송 중...',
      duration: const Duration(seconds: 2),
    );

    try {
      final dio = ApiClient.createDio();
      final formData = FormData();
      for (final file in files) {
        formData.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }
      final response = await dio.post('/chat/upload', data: formData);
      final imageUrls = (response.data['imageUrls'] as List).cast<String>();

      ref.read(chatProvider.notifier).sendMessage(
        content: '',
        imageUrls: imageUrls,
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

  void _toggleAttachPanel() {
    setState(() {
      _showAttachPanel = !_showAttachPanel;
      if (_showAttachPanel) {
        _focusNode.unfocus();
      }
    });
  }

  Future<void> _sendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showTopSnackBar(context, '위치 서비스가 꺼져있습니다. 설정에서 켜주세요.', isError: true);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {
          permission = LocationPermission.deniedForever;
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        final goSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 권한 필요'),
            content: const Text('위치 공유를 위해 설정에서 위치 권한을 허용해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );
        if (goSettings == true) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      if (mounted) {
        showTopSnackBar(context, '위치 정보를 가져오는 중...', duration: const Duration(seconds: 1));
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final locationContent = '__LOC__:${position.latitude},${position.longitude}:내 위치';
      ref.read(chatProvider.notifier).sendMessage(content: locationContent);

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
        showTopSnackBar(context, '위치를 가져올 수 없습니다: $e', isError: true);
      }
    }
  }

  Future<void> _openLocationPicker() async {
    setState(() => _showAttachPanel = false);

    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );

    if (result == null) return;

    final locationContent = '__LOC__:${result.latitude},${result.longitude}:${result.label}';
    ref.read(chatProvider.notifier).sendMessage(content: locationContent);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
              leading: const Icon(Icons.link),
              title: const Text('링크 모아보기'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatLinksScreen(),
                  ),
                );
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
          setState(() {
            _deleteMode = true;
            _selectedForDelete.clear();
            _selectedForDelete.add(message.id);
          });
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

  void _exitDeleteMode() {
    setState(() {
      _deleteMode = false;
      _selectedForDelete.clear();
    });
  }

  void _toggleDeleteSelection(ChatMessage message, bool isMe) {
    if (!isMe) return; // 내 메시지만 선택 가능
    setState(() {
      if (_selectedForDelete.contains(message.id)) {
        _selectedForDelete.remove(message.id);
        if (_selectedForDelete.isEmpty) _deleteMode = false;
      } else {
        _selectedForDelete.add(message.id);
      }
    });
  }

  void _confirmDeleteSelected() {
    if (_selectedForDelete.isEmpty) return;
    final count = _selectedForDelete.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: Text('$count개의 메시지를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              for (final id in _selectedForDelete) {
                ref.read(chatProvider.notifier).deleteMessage(messageId: id);
              }
              Navigator.pop(context);
              _exitDeleteMode();
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
    final coupleState = ref.watch(coupleProvider);
    final partnerName = coupleState.couple?.getPartner(currentUserId)?.nickname ?? '채팅';

    return Scaffold(
      appBar: _deleteMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitDeleteMode,
              ),
              title: Text(
                '${_selectedForDelete.length}개 선택됨',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: _selectedForDelete.isNotEmpty
                      ? _confirmDeleteSelected
                      : null,
                  child: Text(
                    '삭제 (${_selectedForDelete.length})',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            )
          : _captureMode
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
                  Text(partnerName),
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
                      final isDeleteSelected =
                          _deleteMode && _selectedForDelete.contains(message.id);

                      return GestureDetector(
                        onTap: _captureMode
                            ? () => _onCaptureTap(index)
                            : _deleteMode
                                ? () => _toggleDeleteSelection(message, isMe)
                                : null,
                        child: Container(
                          color: isCaptureSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : isDeleteSelected
                                  ? Colors.red.withValues(alpha: 0.08)
                                  : isHighlighted
                                      ? Colors.amber.withValues(alpha: 0.25)
                                      : null,
                          child: Row(
                            children: [
                              if (_deleteMode)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: isMe
                                      ? Icon(
                                          isDeleteSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isDeleteSelected
                                              ? Colors.red
                                              : Colors.grey.shade400,
                                          size: 22,
                                        )
                                      : const SizedBox(width: 22),
                                ),
                              Expanded(
                                child: Column(
                                  children: [
                                    if (showDateHeader)
                                      _DateHeader(date: message.createdAt),
                                    _MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      interactive: !_captureMode && !_deleteMode,
                                      onLongPress: (_captureMode || _deleteMode)
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

          // Input area (hidden in search/delete mode)
          if (!chatState.isSearchMode && !_deleteMode)
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 8,
                  top: 8,
                  bottom: _showAttachPanel ? 8 : MediaQuery.of(context).padding.bottom + 8,
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
                      icon: AnimatedRotation(
                        turns: _showAttachPanel ? 0.125 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.add,
                          color: _showAttachPanel
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          size: 28,
                        ),
                      ),
                      onPressed: _toggleAttachPanel,
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
              // Attach panel
              if (_showAttachPanel)
                Container(
                  padding: EdgeInsets.only(
                    left: 0,
                    right: 0,
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AttachButton(
                        icon: Icons.photo_library,
                        label: '사진',
                        color: const Color(0xFF4CAF50),
                        onTap: () => _pickAndSendImage(ImageSource.gallery),
                      ),
                      _AttachButton(
                        icon: Icons.camera_alt,
                        label: '카메라',
                        color: const Color(0xFF2196F3),
                        onTap: () => _pickAndSendImage(ImageSource.camera),
                      ),
                      _AttachButton(
                        icon: Icons.my_location,
                        label: '내 위치',
                        color: const Color(0xFFFF9800),
                        onTap: () {
                          setState(() => _showAttachPanel = false);
                          _sendLocation();
                        },
                      ),
                      _AttachButton(
                        icon: Icons.map_outlined,
                        label: '지도',
                        color: const Color(0xFFE91E63),
                        onTap: _openLocationPicker,
                      ),
                      _AttachButton(
                        icon: Icons.screenshot_outlined,
                        label: '캡처',
                        color: const Color(0xFF9C27B0),
                        onTap: () {
                          setState(() {
                            _showAttachPanel = false;
                            _captureMode = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
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
  final bool interactive;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.onLongPress,
    this.onRetry,
    this.interactive = true,
  });

  static _LocationData? _parseLocation(String content) {
    if (!content.startsWith('__LOC__:')) return null;
    final parts = content.substring(8).split(':');
    if (parts.length < 2) return null;
    final coords = parts[0].split(',');
    if (coords.length != 2) return null;
    final lat = double.tryParse(coords[0]);
    final lng = double.tryParse(coords[1]);
    if (lat == null || lng == null) return null;
    return _LocationData(lat, lng, parts.length > 1 ? parts[1] : '위치');
  }

  @override
  Widget build(BuildContext context) {
    final locData = _parseLocation(message.content);

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
            if (locData != null)
              _LocationBubble(data: locData, isMe: isMe, interactive: interactive)
            else
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
                  if (message.imageUrls.isNotEmpty) ...[
                    _buildImageGrid(context, message, isMe, interactive),
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

  static Widget _buildImageGrid(
    BuildContext context,
    ChatMessage message,
    bool isMe,
    bool interactive,
  ) {
    final urls = message.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();

    Widget imageWidget(String url, {double? width, double? height, int? overlayCount}) {
      return GestureDetector(
        onTap: interactive
            ? () {
                FullScreenImageViewer.openGallery(
                  context,
                  imageUrls: urls,
                  initialIndex: urls.indexOf(url),
                );
              }
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isMe
                    ? Colors.pink.shade200.withValues(alpha: 0.3)
                    : const Color(0xFFF0F0F0),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFF0F0F0),
                child: const Center(
                  child: Icon(Icons.broken_image, color: AppTheme.textHint),
                ),
              ),
            ),
            if (overlayCount != null && overlayCount > 0)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Text(
                    '+$overlayCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: () {
        if (urls.length == 1) {
          return SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 1.2,
              child: imageWidget(urls[0]),
            ),
          );
        }
        if (urls.length == 2) {
          return Row(
            children: [
              Expanded(child: AspectRatio(aspectRatio: 0.8, child: imageWidget(urls[0]))),
              const SizedBox(width: 2),
              Expanded(child: AspectRatio(aspectRatio: 0.8, child: imageWidget(urls[1]))),
            ],
          );
        }
        if (urls.length == 3) {
          return Column(
            children: [
              AspectRatio(aspectRatio: 1.8, child: imageWidget(urls[0])),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[1]))),
                  const SizedBox(width: 2),
                  Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[2]))),
                ],
              ),
            ],
          );
        }
        // 4장 이상: 2x2 그리드 + 오버레이
        final showOverlay = urls.length > 4;
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[0]))),
                const SizedBox(width: 2),
                Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[1]))),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(child: AspectRatio(aspectRatio: 1.0, child: imageWidget(urls[2]))),
                const SizedBox(width: 2),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: imageWidget(
                      urls[3],
                      overlayCount: showOverlay ? urls.length - 4 : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }(),
    );
  }
}

class _LocationData {
  final double lat;
  final double lng;
  final String label;
  const _LocationData(this.lat, this.lng, this.label);
}

class _LocationBubble extends StatelessWidget {
  final _LocationData data;
  final bool isMe;
  final bool interactive;

  const _LocationBubble({required this.data, required this.isMe, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    // 서버 프록시를 통한 Naver Static Map (깔끔한 네이버 지도 이미지)
    final staticMapUrl =
        '${AppConstants.apiBaseUrl}/map/static'
        '?lat=${data.lat}&lng=${data.lng}&w=600&h=300&zoom=15';

    return GestureDetector(
      onTap: interactive ? () => _openInMaps(data.lat, data.lng, data.label) : null,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 네이버 Static Map 미리보기
            SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    staticMapUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF0F4F8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 36),
                          const SizedBox(height: 4),
                          Text(
                            '${data.lat.toStringAsFixed(4)}, ${data.lng.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                          ),
                        ],
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFFF0F4F8),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                  // 네이버 지도로 보기 뱃지
                  Positioned(
                    top: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1EC800),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'N',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 3),
                          Text(
                            '지도 보기',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng, String label) async {
    final encodedLabel = Uri.encodeComponent(label);
    // 네이버 지도: 마커 표시 + 장소명
    final naverUrl = Uri.parse(
      'nmap://place?lat=$lat&lng=$lng&name=$encodedLabel&appname=com.jiny.hmlove',
    );
    // 애플 지도 fallback
    final appleUrl = Uri.parse(
      'https://maps.apple.com/?ll=$lat,$lng&q=$encodedLabel',
    );

    if (await canLaunchUrl(naverUrl)) {
      await launchUrl(naverUrl);
    } else {
      await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
    }
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9D9B0)
      ..strokeWidth = 0.5;

    // 가로선
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // 세로선
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 중심 십자선
    final centerPaint = Paint()
      ..color = const Color(0xFF81C784)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      centerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
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

