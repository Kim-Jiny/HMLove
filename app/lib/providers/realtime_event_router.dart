import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/api_client.dart';
import '../models/wish_item.dart';
import 'calendar_provider.dart';
import 'feed_provider.dart';
import 'mission_provider.dart';
import 'question_provider.dart';
import 'wishlist_provider.dart';

/// 채팅 외 기능(피드·미션·캘린더·위시리스트·질문)의 실시간 소켓 이벤트를
/// 각 feature provider 로 라우팅한다.
///
/// 소켓 자체는 여전히 ChatNotifier 가 소유하며, 이 함수는 그 소켓에 핸들러만
/// 등록한다. [isCurrent] 는 stale 소켓(재연결 후 이전 세대) 콜백을 무시하기 위한
/// 가드로, 호출부가 `() => _isCurrentSocket(socket, generation)` 를 넘긴다.
///
/// ChatNotifier 가 이 기능들의 모델/프로바이더에 직접 의존하지 않도록 분리한 것.
void registerRealtimeFeatureHandlers(
  io.Socket socket,
  Ref ref,
  bool Function() isCurrent,
) {
  // 피드 실시간 수신
  socket.on('feed:new', (data) {
    if (!isCurrent()) return;
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

  socket.on('feed:deleted', (data) {
    if (!isCurrent()) return;
    if (data != null) {
      final map = data as Map<String, dynamic>;
      final feedId = map['feedId'] as String;
      ref.read(feedProvider.notifier).removeFeedFromSocket(feedId);
    }
  });

  // 피드 댓글 실시간 수신 (상대방 댓글만 반영, 내 댓글은 이미 로컬 처리)
  socket.on('feed:comment:new', (data) {
    if (!isCurrent()) return;
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

  socket.on('feed:comment:deleted', (data) {
    if (!isCurrent()) return;
    if (data != null) {
      final map = data as Map<String, dynamic>;
      final feedId = map['feedId'] as String;
      final commentId = map['commentId'] as String;
      ref.read(feedProvider.notifier).removeComment(feedId, commentId);
    }
  });

  // 미션 실시간 수신
  socket.on('mission:complete', (data) {
    if (!isCurrent()) return;
    if (data != null) {
      final map = Map<String, dynamic>.from(data as Map);
      if (_isOwnActor(map)) return;
      final missionJson = Map<String, dynamic>.from(map['mission'] as Map);
      final mission = Mission.fromJson(missionJson);
      ref.read(missionProvider.notifier).updateMissionFromSocket(mission);
    }
  });

  socket.on('mission:cancel', (data) {
    if (!isCurrent()) return;
    if (data != null) {
      final map = Map<String, dynamic>.from(data as Map);
      if (_isOwnActor(map)) return;
      final missionJson = Map<String, dynamic>.from(map['mission'] as Map);
      final mission = Mission.fromJson(missionJson);
      ref.read(missionProvider.notifier).updateMissionFromSocket(mission);
    }
  });

  // 캘린더 실시간 동기화 (상대방이 변경한 경우만)
  socket.on('calendar:updated', (data) {
    if (!isCurrent()) return;
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
  socket.on('wish:new', (data) {
    if (!isCurrent()) return;
    try {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        if (_isOwnActor(map)) return;
        final itemMap = _socketItemPayload(map);
        final authorId = itemMap['authorId'] as String?;
        final myId = ApiClient.getUserId();
        if (authorId == myId) return; // 내가 추가한 건 API 응답에서 처리
        final item = WishItem.fromJson(itemMap);
        ref.read(wishlistProvider.notifier).onSocketNew(item);
      }
    } catch (e) {
      debugPrint('[Socket] wish:new parse error: $e');
    }
  });

  socket.on('wish:updated', (data) {
    if (!isCurrent()) return;
    try {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        if (_isOwnActor(map)) return;
        final item = WishItem.fromJson(_socketItemPayload(map));
        ref.read(wishlistProvider.notifier).onSocketUpdated(item);
      }
    } catch (e) {
      debugPrint('[Socket] wish:updated parse error: $e');
    }
  });

  socket.on('wish:toggled', (data) {
    if (!isCurrent()) return;
    try {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        if (_isOwnActor(map)) return;
        final item = WishItem.fromJson(_socketItemPayload(map));
        ref.read(wishlistProvider.notifier).onSocketToggled(item);
      }
    } catch (e) {
      debugPrint('[Socket] wish:toggled parse error: $e');
    }
  });

  socket.on('wish:deleted', (data) {
    if (!isCurrent()) return;
    try {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        if (_isOwnActor(map)) return;
        final id = map['id'] as String;
        ref.read(wishlistProvider.notifier).onSocketDeleted(id);
      }
    } catch (e) {
      debugPrint('[Socket] wish:deleted parse error: $e');
    }
  });

  // 질문 카드 실시간 동기화
  socket.on('question:answered', (data) {
    if (!isCurrent()) return;
    try {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        if (_isOwnActor(map, key: 'userId')) return;
        ref.read(questionProvider.notifier).onPartnerAnswered();
      }
    } catch (e) {
      debugPrint('[Socket] question:answered error: $e');
    }
  });
}

bool _isOwnActor(Map<String, dynamic> payload, {String key = 'actorId'}) {
  final actorId = payload[key] as String?;
  return actorId != null && actorId == ApiClient.getUserId();
}

Map<String, dynamic> _socketItemPayload(Map<String, dynamic> payload) {
  final nested = payload['item'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return payload;
}
