import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/wish_item.dart';
import 'badge_provider.dart';
import 'calendar_provider.dart';
import 'feed_provider.dart';
import 'mission_provider.dart';
import 'question_provider.dart';
import 'wishlist_provider.dart';

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
  static const _sentinel = Object();

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
    Object? nextCursor = _sentinel,
    String? error,
    bool? isSearchMode,
    List<ChatMessage>? searchResults,
    int? currentSearchIndex,
    Object? highlightedMessageId = _sentinel,
    bool? isSearching,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      partnerTyping: partnerTyping ?? this.partnerTyping,
      partnerOnline: partnerOnline ?? this.partnerOnline,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: identical(nextCursor, _sentinel)
          ? this.nextCursor
          : nextCursor as String?,
      error: error,
      isSearchMode: isSearchMode ?? this.isSearchMode,
      searchResults: searchResults ?? this.searchResults,
      currentSearchIndex: currentSearchIndex ?? this.currentSearchIndex,
      highlightedMessageId: identical(highlightedMessageId, _sentinel)
          ? this.highlightedMessageId
          : highlightedMessageId as String?,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

// Chat Notifier
class ChatNotifier extends Notifier<ChatState> {
  late final Dio _dio;
  IO.Socket? _socket;
  bool _chatScreenActive = false;
  bool _hasConnectedOnce = false;
  bool _recoverStateOnNextConnect = false;

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
  void connect(String token, {bool recoverState = false}) {
    _socket?.dispose();

    _hasConnectedOnce = false;
    _recoverStateOnNextConnect = recoverState;

    _socket = IO.io(
      AppConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      final wasConnectedBefore = _hasConnectedOnce;
      final shouldRecoverState = _recoverStateOnNextConnect;
      _hasConnectedOnce = true;
      _recoverStateOnNextConnect = false;
      state = state.copyWith(isConnected: true);
      // 재연결 또는 서버 재시작 후 복구 시 상태 동기화
      if (wasConnectedBefore || shouldRecoverState) {
        _syncMissedMessages();
        _refreshRealtimeState();
      }
      // 재연결 시 sending 상태 메시지 자동 재전송
      _retrySendingMessages();
    });

    _socket!.onDisconnect((_) {
      state = state.copyWith(isConnected: false);
    });

    _socket!.onConnectError((_) {
      state = state.copyWith(isConnected: false);
    });

    _socket!.on('server:restart', (_) {
      state = state.copyWith(isConnected: false);
      _recoverStateOnNextConnect = true;
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
            state = state.copyWith(messages: [message, ...state.messages]);
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
        final updated = state.messages
            .where((msg) => msg.id != messageId)
            .toList();
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

    // 캘린더 실시간 동기화 (상대방이 변경한 경우만)
    _socket!.on('calendar:updated', (data) {
      if (data != null) {
        final map = data as Map<String, dynamic>;
        final senderId = map['senderId'] as String?;
        final myId = ApiClient.getUserId();
        if (senderId != myId) {
          ref.read(calendarProvider.notifier).refreshCurrentMonth();
        }
      }
    });

    // 위시리스트 실시간 동기화 (상대방 액션만 반영, 내 액션은 API 응답에서 처리)
    _socket!.on('wish:new', (data) {
      try {
        if (data != null) {
          final map = data as Map<String, dynamic>;
          final authorId = map['authorId'] as String?;
          final myId = ApiClient.getUserId();
          if (authorId == myId) return; // 내가 추가한 건 API 응답에서 처리
          final item = WishItem.fromJson(map);
          ref.read(wishlistProvider.notifier).onSocketNew(item);
        }
      } catch (e) {
        debugPrint('[Socket] wish:new parse error: $e');
      }
    });

    _socket!.on('wish:updated', (data) {
      try {
        if (data != null) {
          final item = WishItem.fromJson(data as Map<String, dynamic>);
          ref.read(wishlistProvider.notifier).onSocketUpdated(item);
        }
      } catch (e) {
        debugPrint('[Socket] wish:updated parse error: $e');
      }
    });

    _socket!.on('wish:toggled', (data) {
      try {
        if (data != null) {
          final item = WishItem.fromJson(data as Map<String, dynamic>);
          ref.read(wishlistProvider.notifier).onSocketToggled(item);
        }
      } catch (e) {
        debugPrint('[Socket] wish:toggled parse error: $e');
      }
    });

    _socket!.on('wish:deleted', (data) {
      try {
        if (data != null) {
          final map = data as Map<String, dynamic>;
          final id = map['id'] as String;
          ref.read(wishlistProvider.notifier).onSocketDeleted(id);
        }
      } catch (e) {
        debugPrint('[Socket] wish:deleted parse error: $e');
      }
    });

    // 질문 카드 실시간 동기화
    _socket!.on('question:answered', (data) {
      try {
        if (data != null) {
          ref.read(questionProvider.notifier).onPartnerAnswered();
        }
      } catch (e) {
        debugPrint('[Socket] question:answered error: $e');
      }
    });

    _socket!.connect();
  }

  /// 재연결 후 누락 메시지 동기화 — 마지막 메시지 ID 기반 after 파라미터 사용
  Future<void> _syncMissedMessages() async {
    if (state.messages.isEmpty) return;
    try {
      // temp- 접두사가 아닌 서버 메시지 중 가장 최근 것
      final lastServerMsg = state.messages
          .where((m) => !m.id.startsWith('temp-'))
          .firstOrNull;
      if (lastServerMsg == null) return;

      final response = await _dio.get(
        '/chat/messages',
        queryParameters: {'after': lastServerMsg.id, 'limit': 100},
      );
      final data = response.data as Map<String, dynamic>;
      final latest = (data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();

      if (latest.isEmpty) return;

      // 기존 메시지에 없는 새 메시지만 병합
      final existingIds = state.messages.map((m) => m.id).toSet();
      final newMessages = latest
          .where((m) => !existingIds.contains(m.id))
          .toList();

      if (newMessages.isNotEmpty) {
        state = state.copyWith(messages: [...newMessages, ...state.messages]);
      }

      // 채팅 화면 활성 시 읽음 처리
      if (_chatScreenActive) {
        markAsRead();
      }
      ref.read(badgeProvider.notifier).fetchBadges();
    } catch (e) {
      debugPrint('[Chat] syncMissedMessages error: $e');
    }
  }

  /// 재연결 후 소켓 의존 상태들만 새로고침한다.
  /// (fetchToday, fetchTodayMissions, fetchBadges 등은 home_screen.resumed에서 이미 호출됨)
  Future<void> _refreshRealtimeState() async {
    final month =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    try {
      await Future.wait([
        ref.read(feedProvider.notifier).fetchFeeds(refresh: true),
        ref.read(missionProvider.notifier).fetchCalendarMissions(month),
        ref.read(calendarProvider.notifier).refreshCurrentMonth(),
        ref.read(wishlistProvider.notifier).fetchItems(),
      ]);
    } catch (e) {
      debugPrint('[Chat] refreshRealtimeState error: $e');
    }
  }

  /// 소켓 연결 상태 확인 및 재연결
  void ensureConnected() {
    final token = ApiClient.getAccessToken();
    if (token == null) return;

    if (_socket == null) {
      connect(token);
    } else if (!_socket!.connected) {
      // 토큰이 변경되었으면 소켓 재생성, 아니면 재연결만 시도
      final socketAuth = _socket!.auth as Map?;
      final socketToken = socketAuth?['token'] as String?;
      if (socketToken != token) {
        // 토큰 갱신됨 → 소켓 재생성
        _socket!.dispose();
        _socket = null;
        connect(token, recoverState: true);
      } else {
        _recoverStateOnNextConnect = true;
        _socket!.connect();
      }
    }
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

    // 소켓 연결 보장
    ensureConnected();

    // 연결된 경우에만 즉시 전송, 미연결 시 onConnect에서 자동 재전송
    if (_socket?.connected == true) {
      _emitMessage(tempId: tempId, content: content, imageUrls: imageUrls);
    } else {
      // 미연결: 10초 내 재연결 안 되면 실패 처리 (재연결 시 자동 재전송됨)
      Future.delayed(const Duration(seconds: 10), () {
        final idx = state.messages.indexWhere((m) => m.id == tempId);
        if (idx != -1 && state.messages[idx].status == MessageStatus.sending) {
          final updated = [...state.messages];
          updated[idx] = updated[idx].copyWith(status: MessageStatus.failed);
          state = state.copyWith(messages: updated);
        }
      });
    }
  }

  /// 소켓으로 메시지 emit (내부 공용)
  void _emitMessage({
    required String tempId,
    required String content,
    List<String> imageUrls = const [],
  }) {
    _socket?.emit('message:send', {
      'content': content,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      '_tempId': tempId,
    });

    // 10초 내 서버 응답 없으면 실패 처리
    Future.delayed(const Duration(seconds: 10), () {
      final idx = state.messages.indexWhere((m) => m.id == tempId);
      if (idx != -1 && state.messages[idx].status == MessageStatus.sending) {
        final updated = [...state.messages];
        updated[idx] = updated[idx].copyWith(status: MessageStatus.failed);
        state = state.copyWith(messages: updated);
      }
    });
  }

  /// 재연결 시 미전송 메시지 자동 재전송 (sending + failed 모두)
  void _retrySendingMessages() {
    final pendingMessages = state.messages
        .where((m) =>
            (m.status == MessageStatus.sending ||
                m.status == MessageStatus.failed) &&
            m.id.startsWith('temp-'))
        .toList();

    if (pendingMessages.isEmpty) return;

    // failed → sending 상태로 변경
    final updated = state.messages.map((m) {
      if (m.status == MessageStatus.failed && m.id.startsWith('temp-')) {
        return m.copyWith(status: MessageStatus.sending);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);

    for (final msg in pendingMessages) {
      _emitMessage(
        tempId: msg.id,
        content: msg.content,
        imageUrls: msg.imageUrls,
      );
    }
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
    _socket?.emit('message:edit', {'messageId': messageId, 'content': content});
  }

  /// Delete a message via socket.
  void deleteMessage({required String messageId}) {
    _socket?.emit('message:delete', {'messageId': messageId});
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
      final response = await _dio.get(
        '/chat/search',
        queryParameters: {'q': query.trim(), 'limit': 50},
      );
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
      final response = await _dio.get('/chat/messages/around/$messageId');
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

      final response = await _dio.get(
        '/chat/messages',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      final messagesJson = data['messages'] as List<dynamic>;
      final messages = messagesJson
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCursor = data['nextCursor'] as String?;
      final hasMore = data['hasMore'] as bool? ?? (newCursor != null);

      if (cursor == null) {
        state = ChatState(
          messages: messages,
          nextCursor: newCursor,
          hasMore: hasMore,
          isLoading: false,
          isConnected: state.isConnected,
          partnerTyping: state.partnerTyping,
          partnerOnline: state.partnerOnline,
        );
      } else {
        state = ChatState(
          messages: [...state.messages, ...messages],
          nextCursor: newCursor,
          hasMore: hasMore,
          isLoading: false,
          isConnected: state.isConnected,
          partnerTyping: state.partnerTyping,
          partnerOnline: state.partnerOnline,
          isSearchMode: state.isSearchMode,
          searchResults: state.searchResults,
          currentSearchIndex: state.currentSearchIndex,
          highlightedMessageId: state.highlightedMessageId,
          isSearching: state.isSearching,
        );
      }
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '메시지를 불러오지 못했습니다';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '알 수 없는 오류가 발생했습니다');
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
