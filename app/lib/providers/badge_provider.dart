import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/api_client.dart';
import '../core/constants.dart';

class BadgeState {
  final int unreadChatCount;
  final int unseenFeedCount;

  const BadgeState({this.unreadChatCount = 0, this.unseenFeedCount = 0});

  BadgeState copyWith({int? unreadChatCount, int? unseenFeedCount}) {
    return BadgeState(
      unreadChatCount: unreadChatCount ?? this.unreadChatCount,
      unseenFeedCount: unseenFeedCount ?? this.unseenFeedCount,
    );
  }
}

class BadgeNotifier extends Notifier<BadgeState> {
  late final Dio _dio;

  @override
  BadgeState build() {
    _dio = ref.read(dioProvider);
    return const BadgeState();
  }

  Future<void> fetchBadges() async {
    // 순차 실행으로 race condition 방지
    await _fetchChatUnread();
    await _fetchFeedUnseen();
  }

  void applyCounts({int? unreadChatCount, int? unseenFeedCount}) {
    state = state.copyWith(
      unreadChatCount: unreadChatCount,
      unseenFeedCount: unseenFeedCount,
    );
  }

  Future<void> _fetchChatUnread() async {
    try {
      final response = await _dio.get('/chat/unread-count');
      final count =
          (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
      state = state.copyWith(unreadChatCount: count);
    } catch (e) {
      debugPrint('[Badge] fetchChatUnread error: $e');
    }
  }

  Future<void> _fetchFeedUnseen() async {
    try {
      final box = Hive.box(AppConstants.settingsBox);
      final since = box.get('lastSeenFeedAt') as String?;
      final queryParams = <String, dynamic>{if (since != null) 'since': since};
      final response = await _dio.get(
        '/feed/unread-count',
        queryParameters: queryParams,
      );
      final count =
          (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
      state = state.copyWith(unseenFeedCount: count);
    } catch (e) {
      debugPrint('[Badge] fetchFeedUnseen error: $e');
    }
  }

  void clearChatBadge() {
    state = state.copyWith(unreadChatCount: 0);
  }

  void clearFeedBadge() {
    final box = Hive.box(AppConstants.settingsBox);
    box.put('lastSeenFeedAt', DateTime.now().toUtc().toIso8601String());
    state = state.copyWith(unseenFeedCount: 0);
  }
}

final badgeProvider = NotifierProvider<BadgeNotifier, BadgeState>(
  BadgeNotifier.new,
);
