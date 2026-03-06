import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/api_client.dart';
import '../core/constants.dart';
import 'badge_provider.dart';
import 'feed_provider.dart';
import 'mission_provider.dart';

// Message send status
enum MessageStatus { sending, sent, failed }

// Chat Message model
class ChatMessage {
  final String id;
  final String content;
  final List<String> imageUrls;
  final String senderId;
  final String? senderNickname;
  final String coupleId;
  final bool isRead;
  final bool isEdited;
  final DateTime createdAt;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.content,
    this.imageUrls = const [],
    required this.senderId,
    this.senderNickname,
    required this.coupleId,
    this.isRead = false,
    this.isEdited = false,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // 하위 호환: imageUrl (단일) → imageUrls (배열)
    List<String> urls = [];
    if (json['imageUrls'] != null) {
      urls = (json['imageUrls'] as List).cast<String>();
    } else if (json['imageUrl'] != null) {
      urls = [json['imageUrl'] as String];
    }

    return ChatMessage(
      id: json['id'] as String,
      content: (json['content'] as String?) ?? '',
      imageUrls: urls,
      senderId: json['senderId'] as String,
      senderNickname: json['senderNickname'] as String?,
      coupleId: json['coupleId'] as String,
      isRead: json['isRead'] as bool? ?? false,
      isEdited: json['isEdited'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      status: MessageStatus.sent,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    List<String>? imageUrls,
    String? senderId,
    String? senderNickname,
    String? coupleId,
    bool? isRead,
    bool? isEdited,
    DateTime? createdAt,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      coupleId: coupleId ?? this.coupleId,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

// Chat state class
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isConnected;
  final bool partnerTyping;
  final bool partnerOnline;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  // Search
  final bool isSearchMode;
  final List<ChatMessage> searchResults;
  final int currentSearchIndex;
  final String? highlightedMessageId;
  final bool isSearching;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.partnerTyping = false,
    this.partnerOnline = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.isSearchMode = false,
    this.searchResults = const [],
    this.currentSearchIndex = -1,
    this.highlightedMessageId,
    this.isSearching = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isConnected,
    bool? partnerTyping,
    bool? partnerOnline,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool? isSearchMode,
    List<ChatMessage>? searchResults,
    int? currentSearchIndex,
    String? highlightedMessageId,
    bool? isSearching,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      partnerTyping: partnerTyping ?? this.partnerTyping,
      partnerOnline: partnerOnline ?? this.partnerOnline,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: error,
      isSearchMode: isSearchMode ?? this.isSearchMode,
      searchResults: searchResults ?? this.searchResults,
      currentSearchIndex: currentSearchIndex ?? this.currentSearchIndex,
      highlightedMessageId: highlightedMessageId ?? this.highlightedMessageId,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

// Chat Notifier
class ChatNotifier extends Notifier<ChatState> {
  late final Dio _dio;
  IO.Socket? _socket;
  bool _chatScreenActive = false;

  @override
  ChatState build() {
    _dio = ref.read(dioProvider);

    ref.onDispose(() {
      _socket?.dispose();
      _socket = null;
    });

    return const ChatState();
  }

  /// Connect to the Socket.io server.
  void connect(String token) {
    _socket?.dispose();

    _socket = IO.io(
      AppConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      state = state.copyWith(isConnected: true);
    });

    _socket!.onDisconnect((_) {
      state = state.copyWith(isConnected: false);
    });

    _socket!.on('message:new', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final message = ChatMessage.fromJson(map);
        final tempId = map['_tempId'] as String?;
        final myId = ApiClient.getUserId();

        if (tempId != null && message.senderId == myId) {
          // 내가 보낸 메시지 → 임시 메시지를 서버 메시지로 교체
          final updated = state.messages.map((msg) {
            return msg.id == tempId ? message : msg;
          }).toList();
          state = state.copyWith(messages: updated);
        } else {
          // 상대방 메시지 (또는 tempId 없는 경우) → 앞에 추가
          // 중복 방지
          if (!state.messages.any((m) => m.id == message.id)) {
            state = state.copyWith(
              messages: [message, ...state.messages],
            );
          }
        }
        // 상대방 메시지면 뱃지 갱신 + 채팅 화면 활성 시에만 읽음 처리
        if (message.senderId != myId) {
          ref.read(badgeProvider.notifier).fetchBadges();
          if (_chatScreenActive) {
            markAsRead();
          }
        }
      }
    });

    _socket!.on('message:read', (_) {
      final updatedMessages = state.messages.map((msg) {
        return msg.copyWith(isRead: true);
      }).toList();
      state = state.copyWith(messages: updatedMessages);
    });

    _socket!.on('message:edited', (data) {
      if (data != null) {
        final edited = ChatMessage.fromJson(data as Map<String, dynamic>);
        final updated = state.messages.map((msg) {
          return msg.id == edited.id ? edited : msg;
        }).toList();
        state = state.copyWith(messages: updated);
      }
    });

    _socket!.on('message:deleted', (data) {
      if (data != null) {
        final messageId = (data as Map<String, dynamic>)['messageId'] as String;
        final updated = state.messages.where((msg) => msg.id != messageId).toList();
        state = state.copyWith(messages: updated);
      }
    });

    _socket!.on('typing:start', (_) {
      state = state.copyWith(partnerTyping: true);
    });

    _socket!.on('typing:stop', (_) {
      state = state.copyWith(partnerTyping: false);
    });

    _socket!.on('partner:online', (_) {
      state = state.copyWith(partnerOnline: true);
    });

    _socket!.on('partner:offline', (_) {
      state = state.copyWith(partnerOnline: false);
    });

    // 피드 실시간 수신
    _socket!.on('feed:new', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final feedJson = map['feed'] as Map<String, dynamic>;
        final feed = Feed.fromJson(feedJson);
        final myId = ApiClient.getUserId();
        if (feed.authorId != myId) {
          ref.read(feedProvider.notifier).addFeedFromSocket(feed);
        }
      }
    });

    _socket!.on('feed:deleted', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final feedId = map['feedId'] as String;
        ref.read(feedProvider.notifier).removeFeedFromSocket(feedId);
      }
    });

    // 피드 댓글 실시간 수신 (상대방 댓글만 반영, 내 댓글은 이미 로컬 처리)
    _socket!.on('feed:comment:new', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final feedId = map['feedId'] as String;
        final commentJson = map['comment'] as Map<String, dynamic>;
        final comment = FeedComment.fromJson(commentJson);
        final myId = ApiClient.getUserId();
        if (comment.authorId != myId) {
          ref.read(feedProvider.notifier).addComment(feedId, comment);
        }
      }
    });

    _socket!.on('feed:comment:deleted', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final feedId = map['feedId'] as String;
        final commentId = map['commentId'] as String;
        ref.read(feedProvider.notifier).removeComment(feedId, commentId);
      }
    });

    // 미션 실시간 수신
    _socket!.on('mission:complete', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final missionJson = map['mission'] as Map<String, dynamic>;
        final mission = Mission.fromJson(missionJson);
        ref.read(missionProvider.notifier).updateMissionFromSocket(mission);
      }
    });

    _socket!.on('mission:cancel', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final missionJson = map['mission'] as Map<String, dynamic>;
        final mission = Mission.fromJson(missionJson);
        ref.read(missionProvider.notifier).updateMissionFromSocket(mission);
      }
    });

    _socket!.connect();
  }

  /// Disconnect from the Socket.io server.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    state = state.copyWith(isConnected: false);
  }

  /// Send a chat message via socket with optimistic UI.
  void sendMessage({
    required String content,
    List<String> imageUrls = const [],
  }) {
    final myId = ApiClient.getUserId() ?? '';
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

    // 즉시 UI에 표시 (sending 상태)
    final optimistic = ChatMessage(
      id: tempId,
      content: content,
      imageUrls: imageUrls,
      senderId: myId,
      coupleId: '',
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    state = state.copyWith(messages: [optimistic, ...state.messages]);

    // 소켓 전송
    _socket?.emit('message:send', {
      'content': content,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      '_tempId': tempId,
    });

    // 5초 내 서버 응답 없으면 실패 처리
    Future.delayed(const Duration(seconds: 5), () {
      final idx = state.messages.indexWhere((m) => m.id == tempId);
      if (idx != -1 && state.messages[idx].status == MessageStatus.sending) {
        final updated = [...state.messages];
        updated[idx] = updated[idx].copyWith(status: MessageStatus.failed);
        state = state.copyWith(messages: updated);
      }
    });
  }

  /// Retry sending a failed message.
  void retryMessage(String tempId) {
    final idx = state.messages.indexWhere((m) => m.id == tempId);
    if (idx == -1) return;

    final msg = state.messages[idx];
    // 실패 메시지 제거
    final updated = [...state.messages];
    updated.removeAt(idx);
    state = state.copyWith(messages: updated);

    // 재전송
    sendMessage(content: msg.content, imageUrls: msg.imageUrls);
  }

  /// Edit a message via socket.
  void editMessage({required String messageId, required String content}) {
    _socket?.emit('message:edit', {
      'messageId': messageId,
      'content': content,
    });
  }

  /// Delete a message via socket.
  void deleteMessage({required String messageId}) {
    _socket?.emit('message:delete', {
      'messageId': messageId,
    });
  }

  /// Notify the server that the user is typing.
  void startTyping() {
    _socket?.emit('typing:start');
  }

  /// Notify the server that the user stopped typing.
  void stopTyping() {
    _socket?.emit('typing:stop');
  }

  /// 채팅 화면 활성 상태 확인
  bool get isChatScreenActive => _chatScreenActive;

  /// 채팅 화면 활성/비활성 상태 설정
  void setChatScreenActive(bool active) {
    _chatScreenActive = active;
  }

  /// Mark messages as read via socket.
  void markAsRead() {
    _socket?.emit('message:read');
  }

  /// Enter search mode.
  void enterSearchMode() {
    state = state.copyWith(isSearchMode: true);
  }

  /// Exit search mode and reload latest messages.
  Future<void> exitSearchMode() async {
    state = ChatState(
      isConnected: state.isConnected,
      partnerTyping: state.partnerTyping,
      partnerOnline: state.partnerOnline,
    );
    await fetchHistory();
  }

  /// Search messages by keyword.
  Future<void> searchMessages(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(
        searchResults: const [],
        currentSearchIndex: -1,
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(isSearching: true);

    try {
      final response = await _dio.get('/chat/search', queryParameters: {
        'q': query.trim(),
        'limit': 50,
      });
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        searchResults: messages,
        currentSearchIndex: messages.isEmpty ? -1 : 0,
        isSearching: false,
      );
    } catch (e) {
      state = state.copyWith(isSearching: false);
    }
  }

  /// Jump to a specific message, loading surrounding context.
  /// Returns the target index in the loaded messages list.
  Future<int> jumpToMessage(String messageId) async {
    try {
      final response =
          await _dio.get('/chat/messages/around/$messageId');
      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCursor = data['nextCursor'] as String?;
      final hasMore = data['hasMore'] as bool? ?? false;
      final targetIndex = data['targetIndex'] as int? ?? 0;

      state = ChatState(
        messages: messages,
        isConnected: state.isConnected,
        partnerTyping: state.partnerTyping,
        partnerOnline: state.partnerOnline,
        hasMore: hasMore,
        nextCursor: newCursor,
        isSearchMode: state.isSearchMode,
        searchResults: state.searchResults,
        currentSearchIndex: state.currentSearchIndex,
        highlightedMessageId: messageId,
      );

      return targetIndex;
    } catch (e) {
      return 0;
    }
  }

  /// Navigate to next (older) search result.
  Future<int> nextSearchResult() async {
    if (state.searchResults.isEmpty) return 0;
    final next = state.currentSearchIndex + 1 < state.searchResults.length
        ? state.currentSearchIndex + 1
        : 0;
    state = state.copyWith(currentSearchIndex: next);
    return jumpToMessage(state.searchResults[next].id);
  }

  /// Navigate to previous (newer) search result.
  Future<int> prevSearchResult() async {
    if (state.searchResults.isEmpty) return 0;
    final prev = state.currentSearchIndex > 0
        ? state.currentSearchIndex - 1
        : state.searchResults.length - 1;
    state = state.copyWith(currentSearchIndex: prev);
    return jumpToMessage(state.searchResults[prev].id);
  }

  /// Fetch message history with cursor-based pagination.
  Future<void> fetchHistory({String? cursor}) async {
    if (state.isLoading) return;
    if (cursor != null && !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final queryParams = <String, dynamic>{
        'limit': 30,
        if (cursor != null) 'cursor': cursor,
      };

      final response =
          await _dio.get('/chat/messages', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      final messagesJson = data['messages'] as List<dynamic>;
      final messages = messagesJson
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCursor = data['nextCursor'] as String?;
      final hasMore = data['hasMore'] as bool? ?? (newCursor != null);

      state = state.copyWith(
        messages: cursor == null ? messages : [...state.messages, ...messages],
        nextCursor: newCursor,
        hasMore: hasMore,
        isLoading: false,
      );
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '메시지를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }
}

// Providers
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

final isPartnerOnlineProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).partnerOnline;
});

final isPartnerTypingProvider = Provider<bool>((ref) {
  return ref.watch(chatProvider).partnerTyping;
});
