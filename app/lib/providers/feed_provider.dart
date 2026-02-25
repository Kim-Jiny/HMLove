import 'package:dio/dio.dart';
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

  factory Feed.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Feed(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
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
    String? error,
  }) {
    return FeedState(
      feeds: feeds ?? this.feeds,
      isLoading: isLoading ?? this.isLoading,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      error: error,
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

  Future<void> fetchFeeds({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final cursor = refresh ? null : state.nextCursor;
      final queryParams = <String, dynamic>{
        'limit': 20,
        if (cursor != null) 'cursor': cursor,
      };

      final response = await _dio.get('/feed', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      final feedsJson = data['feeds'] as List<dynamic>;
      final feeds = feedsJson
          .map((e) => Feed.fromJson(e as Map<String, dynamic>))
          .toList();
      final newCursor = data['nextCursor'] as String?;
      final hasMore = data['hasMore'] as bool? ?? (newCursor != null);

      state = state.copyWith(
        feeds: refresh ? feeds : [...state.feeds, ...feeds],
        nextCursor: newCursor,
        hasMore: hasMore,
        isLoading: false,
      );
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '피드를 불러오지 못했습니다';
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
      final response = await _dio.post('/feed', data: {
        'content': content,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (type != null) 'type': type,
      });

      final data = response.data as Map<String, dynamic>;
      final feedJson = data['feed'] as Map<String, dynamic>? ?? data;
      final feed = Feed.fromJson(feedJson);
      state = state.copyWith(
        feeds: [feed, ...state.feeds],
        isLoading: false,
      );
      return true;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? '피드 작성에 실패했습니다';
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
      final message =
          e.response?.data?['message'] as String? ?? '피드 삭제에 실패했습니다';
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

  /// Toggle like on a feed
  Future<void> toggleLike(String feedId) async {
    // Optimistic update
    final idx = state.feeds.indexWhere((f) => f.id == feedId);
    if (idx == -1) return;

    final feed = state.feeds[idx];
    final newLiked = !feed.isLiked;
    final newCount = feed.likeCount + (newLiked ? 1 : -1);

    final updatedFeeds = [...state.feeds];
    updatedFeeds[idx] = feed.copyWith(isLiked: newLiked, likeCount: newCount);
    state = state.copyWith(feeds: updatedFeeds);

    try {
      final response = await _dio.post('/feed/$feedId/like');
      final data = response.data as Map<String, dynamic>;
      // Sync with server response
      updatedFeeds[idx] = feed.copyWith(
        isLiked: data['isLiked'] as bool,
        likeCount: data['likeCount'] as int,
      );
      state = state.copyWith(feeds: updatedFeeds);
    } catch (_) {
      // Revert on error
      updatedFeeds[idx] = feed;
      state = state.copyWith(feeds: updatedFeeds);
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
}

// Providers
final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
