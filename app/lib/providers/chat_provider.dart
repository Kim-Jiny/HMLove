import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../core/api_client.dart';
import '../core/constants.dart';
import 'badge_provider.dart';

// Chat Message model
class ChatMessage {
  final String id;
  final String content;
  final String? imageUrl;
  final String senderId;
  final String? senderNickname;
  final String coupleId;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.senderId,
    this.senderNickname,
    required this.coupleId,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      senderId: json['senderId'] as String,
      senderNickname: json['senderNickname'] as String?,
      coupleId: json['coupleId'] as String,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imageUrl': imageUrl,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'coupleId': coupleId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    String? imageUrl,
    String? senderId,
    String? senderNickname,
    String? coupleId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      senderId: senderId ?? this.senderId,
      senderNickname: senderNickname ?? this.senderNickname,
      coupleId: coupleId ?? this.coupleId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
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

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isConnected = false,
    this.partnerTyping = false,
    this.partnerOnline = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
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
    );
  }
}

// Chat Notifier
class ChatNotifier extends Notifier<ChatState> {
  late final Dio _dio;
  IO.Socket? _socket;

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
        final message =
            ChatMessage.fromJson(data as Map<String, dynamic>);
        state = state.copyWith(
          messages: [message, ...state.messages],
        );
        // 상대방 메시지면 뱃지 갱신
        final myId = ApiClient.getUserId();
        if (message.senderId != myId) {
          ref.read(badgeProvider.notifier).fetchBadges();
        }
      }
    });

    _socket!.on('message:read', (_) {
      final updatedMessages = state.messages.map((msg) {
        return msg.copyWith(isRead: true);
      }).toList();
      state = state.copyWith(messages: updatedMessages);
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

    _socket!.connect();
  }

  /// Disconnect from the Socket.io server.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
    state = state.copyWith(isConnected: false);
  }

  /// Send a chat message via socket.
  void sendMessage({
    required String content,
    String? imageUrl,
  }) {
    _socket?.emit('message:send', {
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
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

  /// Mark messages as read via socket.
  void markAsRead() {
    _socket?.emit('message:read');
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
