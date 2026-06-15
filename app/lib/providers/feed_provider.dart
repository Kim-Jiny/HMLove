import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Feed model
class Feed {
  final String id;
  final String content;
  final List<String> imageUrls;
  final String? type;
  final String coupleId;
  final String authorId;
  final String? authorNickname;
  final String? authorProfileImage;
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final List<FeedComment> recentComments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Feed({
    required this.id,
    required this.content,
    this.imageUrls = const [],
    this.type,
    required this.coupleId,
    required this.authorId,
    this.authorNickname,
    this.authorProfileImage,
    this.isLiked = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.recentComments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasImages => imageUrls.isNotEmpty;

  static List<String> parseImageUrls(Map<String, dynamic> json) {
    final imageUrls = json['imageUrls'];
    if (imageUrls is List) {
      return imageUrls.whereType<String>().where((e) => e.isNotEmpty).toList();
    }

    final imageUrl = json['imageUrl'];
    if (imageUrl is String && imageUrl.isNotEmpty) {
      return [imageUrl];
    }

    return const [];
  }

  factory Feed.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Feed(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      imageUrls: parseImageUrls(json),
      type: json['type'] as String?,
      coupleId: json['coupleId'] as String,
      authorId: json['authorId'] as String,
      authorNickname: author?['nickname'] as String? ??
          json['authorNickname'] as String?,
      authorProfileImage: author?['profileImage'] as String? ??
          json['authorProfileImage'] as String?,
      isLiked: json['isLiked'] as bool? ?? false,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      recentComments: (json['recentComments'] as List<dynamic>?)
              ?.map((e) => FeedComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Feed copyWith({
    bool? isLiked,
    int? likeCount,
    int? commentCount,
    List<FeedComment>? recentComments,
  }) {
    return Feed(
      id: id,
      content: content,
      imageUrls: imageUrls,
      type: type,
      coupleId: coupleId,
      authorId: authorId,
      authorNickname: authorNickname,
      authorProfileImage: authorProfileImage,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      recentComments: recentComments ?? this.recentComments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// Comment model
class FeedComment {
  final String id;
  final String feedId;
  final String authorId;
  final String? authorNickname;
  final String? authorProfileImage;
  final String content;
  final DateTime createdAt;

  const FeedComment({
    required this.id,
    required this.feedId,
    required this.authorId,
    this.authorNickname,
    this.authorProfileImage,
    required this.content,
    required this.createdAt,
  });

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return FeedComment(
      id: json['id'] as String,
      feedId: json['feedId'] as String,
      authorId: json['authorId'] as String,
      authorNickname: author?['nickname'] as String?,
      authorProfileImage: author?['profileImage'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// Feed state class
class FeedState {
  static const _sentinel = Object();

  final List<Feed> feeds;
  final bool isLoading;
  final String? nextCursor;
  final bool hasMore;
  final String? error;

  const FeedState({
    this.feeds = const [],
    this.isLoading = false,
    this.nextCursor,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<Feed>? feeds,
    bool? isLoading,
    String? nextCursor,
    bool? hasMore,
    Object? error = _sentinel,
  }) {
    return FeedState(
      feeds: feeds ?? this.feeds,
      isLoading: isLoading ?? this.isLoading,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

// Feed Notifier
class FeedNotifier extends Notifier<FeedState> {
  late final Dio _dio;

  @override
  FeedState build() {
    _dio = ref.read(dioProvider);
    return const FeedState();
  }

  String _extractErrorMessage(Object data, String fallback) {
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    return fallback;
  }

  Future<void> fetchFeeds({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final cursor = refresh ? null : state.nextCursor;
      final queryParams = <String, dynamic>{'limit': 20};
      if (cursor != null) queryParams['cursor'] = cursor;

      final response = await _dio.get('/feed', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      final feedsJson = data['feeds'] as List<dynamic>;
      final feeds = feedsJson
          .map((e) => Feed.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCursor = data['nextCursor'] as String?;
      final hasMore = data['hasMore'] as bool? ?? (newCursor != null);

      if (refresh) {
        state = FeedState(
          feeds: feeds,
          nextCursor: newCursor,
          hasMore: hasMore,
          isLoading: false,
        );
      } else {
        state = FeedState(
          feeds: [...state.feeds, ...feeds],
          nextCursor: newCursor,
          hasMore: hasMore,
          isLoading: false,
        );
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(
        e.response?.data,
        '피드를 불러오지 못했습니다',
      );
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
    }
  }

  Future<bool> createFeed({
    required String content,
    List<String> imageUrls = const [],
    String? type,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final payload = <String, dynamic>{'content': content};
      if (imageUrls.isNotEmpty) payload['imageUrls'] = imageUrls;
      if (type != null) payload['type'] = type;

      final response = await _dio.post('/feed', data: payload);

      final data = response.data as Map<String, dynamic>;
      final feedJson = data['feed'] as Map<String, dynamic>? ?? data;
      final feed = Feed.fromJson(feedJson);
      state = state.copyWith(
        feeds: [feed, ...state.feeds],
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message = _extractErrorMessage(
        e.response?.data,
        '피드 작성에 실패했습니다',
      );
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  Future<bool> deleteFeed(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _dio.delete('/feed/$id');
      final updatedFeeds = state.feeds.where((feed) => feed.id != id).toList();
      state = state.copyWith(feeds: updatedFeeds, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = _extractErrorMessage(
        e.response?.data,
        '피드 삭제에 실패했습니다',
      );
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '알 수 없는 오류가 발생했습니다',
      );
      return false;
    }
  }

  /// 소켓으로 받은 새 피드 추가 (상대방이 올린 피드)
  void addFeedFromSocket(Feed feed) {
    // 중복 방지
    if (state.feeds.any((f) => f.id == feed.id)) return;
    state = state.copyWith(feeds: [feed, ...state.feeds]);
  }

  /// 소켓으로 받은 피드 삭제
  void removeFeedFromSocket(String feedId) {
    final updatedFeeds = state.feeds.where((f) => f.id != feedId).toList();
    if (updatedFeeds.length != state.feeds.length) {
      state = state.copyWith(feeds: updatedFeeds);
    }
  }

  /// Toggle like on a feed
  Future<void> toggleLike(String feedId) async {
    // Optimistic update
    final idx = state.feeds.indexWhere((f) => f.id == feedId);
    if (idx == -1) return;

    final feed = state.feeds[idx];
    final newLiked = !feed.isLiked;
    final newCount = feed.likeCount + (newLiked ? 1 : -1);

    final optimisticFeeds = [...state.feeds];
    optimisticFeeds[idx] = feed.copyWith(isLiked: newLiked, likeCount: newCount);
    state = state.copyWith(feeds: optimisticFeeds);

    try {
      final response = await _dio.post('/feed/$feedId/like');
      final data = response.data as Map<String, dynamic>;
      // Re-read state after await to avoid stale list
      final currentIdx = state.feeds.indexWhere((f) => f.id == feedId);
      if (currentIdx == -1) return;
      final currentFeeds = [...state.feeds];
      currentFeeds[currentIdx] = state.feeds[currentIdx].copyWith(
        isLiked: data['isLiked'] as bool? ?? newLiked,
        likeCount: (data['likeCount'] as num?)?.toInt() ?? newCount,
      );
      state = state.copyWith(feeds: currentFeeds);
    } catch (_) {
      // Re-read state and revert
      final currentIdx = state.feeds.indexWhere((f) => f.id == feedId);
      if (currentIdx == -1) return;
      final revertFeeds = [...state.feeds];
      revertFeeds[currentIdx] = state.feeds[currentIdx].copyWith(
        isLiked: feed.isLiked,
        likeCount: feed.likeCount,
      );
      state = state.copyWith(feeds: revertFeeds);
    }
  }

  /// Update comment count locally
  void updateCommentCount(String feedId, int delta) {
    final idx = state.feeds.indexWhere((f) => f.id == feedId);
    if (idx == -1) return;
    final feed = state.feeds[idx];
    final updatedFeeds = [...state.feeds];
    updatedFeeds[idx] =
        feed.copyWith(commentCount: feed.commentCount + delta);
    state = state.copyWith(feeds: updatedFeeds);
  }

  /// 댓글 추가 시 recentComments도 업데이트
  void addComment(String feedId, FeedComment comment) {
    final idx = state.feeds.indexWhere((f) => f.id == feedId);
    if (idx == -1) return;
    final feed = state.feeds[idx];
    final updatedComments = [...feed.recentComments, comment];
    // 최근 3개만 유지
    final trimmed = updatedComments.length > 3
        ? updatedComments.sublist(updatedComments.length - 3)
        : updatedComments;
    final updatedFeeds = [...state.feeds];
    updatedFeeds[idx] = feed.copyWith(
      commentCount: feed.commentCount + 1,
      recentComments: trimmed,
    );
    state = state.copyWith(feeds: updatedFeeds);
  }

  /// 댓글 삭제 시 recentComments에서도 제거
  void removeComment(String feedId, String commentId) {
    final idx = state.feeds.indexWhere((f) => f.id == feedId);
    if (idx == -1) return;
    final feed = state.feeds[idx];
    final updatedComments =
        feed.recentComments.where((c) => c.id != commentId).toList();
    final updatedFeeds = [...state.feeds];
    updatedFeeds[idx] = feed.copyWith(
      commentCount: (feed.commentCount - 1).clamp(0, 999999),
      recentComments: updatedComments,
    );
    state = state.copyWith(feeds: updatedFeeds);
  }

  /// 단일 피드 새로고침 (서버에서 최신 데이터)
  Future<void> refreshSingleFeed(String feedId) async {
    try {
      final response = await _dio.get('/feed/$feedId');
      final data = response.data as Map<String, dynamic>;
      final feedJson = data['feed'] as Map<String, dynamic>? ?? data;
      final updatedFeed = Feed.fromJson(feedJson);
      final idx = state.feeds.indexWhere((f) => f.id == feedId);
      if (idx == -1) return;
      final updatedFeeds = [...state.feeds];
      updatedFeeds[idx] = updatedFeed;
      state = state.copyWith(feeds: updatedFeeds);
    } catch (e) {
      debugPrint('[Feed] refreshSingleFeed error: $e');
    }
  }
}

// Providers
final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
