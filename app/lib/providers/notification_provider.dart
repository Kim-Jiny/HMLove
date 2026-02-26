import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final bool hasMore;
  final String? nextCursor;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.hasMore = false,
    this.nextCursor,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    bool? hasMore,
    String? nextCursor,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  late final Dio _dio;

  @override
  NotificationState build() {
    _dio = ref.read(dioProvider);
    return const NotificationState();
  }

  Future<void> fetchUnreadCount() async {
    try {
      final response = await _dio.get('/notification/unread-count');
      final count = (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    try {
      final params = <String, dynamic>{'limit': '20'};
      if (!refresh && state.nextCursor != null) {
        params['cursor'] = state.nextCursor;
      }

      final response = await _dio.get('/notification', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final list = (data['notifications'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();

      if (refresh) {
        state = state.copyWith(
          notifications: list,
          hasMore: data['hasMore'] as bool? ?? false,
          nextCursor: data['nextCursor'] as String?,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          notifications: [...state.notifications, ...list],
          hasMore: data['hasMore'] as bool? ?? false,
          nextCursor: data['nextCursor'] as String?,
          isLoading: false,
        );
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _dio.patch('/notification/read-all');
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
        unreadCount: 0,
      );
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.patch('/notification/$id/read');
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == id) return n.copyWith(isRead: true);
          return n;
        }).toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
      );
    } catch (_) {}
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
  NotificationNotifier.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
