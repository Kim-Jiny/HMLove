import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

// Feed model
class Feed {
  final String id;
  final String content;
  final String? imageUrl;
  final String? type;
  final String coupleId;
  final String authorId;
  final String? authorNickname;
  final String? authorProfileImage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Feed({
    required this.id,
    required this.content,
    this.imageUrl,
    this.type,
    required this.coupleId,
    required this.authorId,
    this.authorNickname,
    this.authorProfileImage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      type: json['type'] as String?,
      coupleId: json['coupleId'] as String,
      authorId: json['authorId'] as String,
      authorNickname: json['authorNickname'] as String?,
      authorProfileImage: json['authorProfileImage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'imageUrl': imageUrl,
      'type': type,
      'coupleId': coupleId,
      'authorId': authorId,
      'authorNickname': authorNickname,
      'authorProfileImage': authorProfileImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
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

  /// Fetch feeds with cursor-based pagination.
  /// If [refresh] is true, resets the list and fetches from the beginning.
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

  /// Create a new feed post.
  Future<bool> createFeed({
    required String content,
    String? imageUrl,
    String? type,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _dio.post('/feed', data: {
        'content': content,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (type != null) 'type': type,
      });

      final feed = Feed.fromJson(response.data as Map<String, dynamic>);
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

  /// Delete a feed post.
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
}

// Providers
final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
