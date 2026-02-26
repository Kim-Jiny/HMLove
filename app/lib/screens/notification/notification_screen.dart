import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/theme.dart';
import '../../providers/notification_provider.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationProvider.notifier).fetchNotifications(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final nState = ref.read(notificationProvider);
      if (nState.hasMore && !nState.isLoading) {
        ref.read(notificationProvider.notifier).fetchNotifications();
      }
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'feed':
        return Icons.article_outlined;
      case 'feed_like':
        return Icons.favorite_border;
      case 'feed_comment':
        return Icons.chat_bubble_outline;
      case 'letter':
        return Icons.mail_outlined;
      case 'calendar':
        return Icons.event_outlined;
      case 'mood':
        return Icons.mood_outlined;
      case 'fight':
        return Icons.flash_on_outlined;
      case 'fortune':
        return Icons.auto_awesome_outlined;
      case 'inquiry':
        return Icons.support_agent_outlined;
      case 'couple_left':
        return Icons.heart_broken_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'feed':
        return Colors.blue;
      case 'feed_like':
        return Colors.red;
      case 'feed_comment':
        return Colors.green;
      case 'letter':
        return Colors.purple;
      case 'calendar':
        return Colors.orange;
      case 'mood':
        return Colors.amber;
      case 'fight':
        return Colors.deepOrange;
      case 'fortune':
        return Colors.teal;
      case 'inquiry':
        return Colors.indigo;
      case 'couple_left':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  void _onTapNotification(AppNotification notification) {
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markRead(notification.id);
    }

    final data = notification.data;
    switch (notification.type) {
      case 'feed':
      case 'feed_like':
      case 'feed_comment':
        context.push('/feed');
        break;
      case 'letter':
        final letterId = data?['letterId'] as String?;
        if (letterId != null) {
          context.push('/letter/$letterId');
        } else {
          context.push('/letter');
        }
        break;
      case 'calendar':
        context.push('/calendar');
        break;
      case 'fortune':
        context.push('/fortune');
        break;
      case 'fight':
        context.push('/fight');
        break;
      case 'inquiry':
        context.push('/more');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nState = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          if (nState.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllRead();
              },
              child: const Text(
                '모두 읽음',
                style: TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      body: nState.notifications.isEmpty && !nState.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppTheme.textHint,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '알림이 없습니다',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await ref
                    .read(notificationProvider.notifier)
                    .fetchNotifications(refresh: true);
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: nState.notifications.length + (nState.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == nState.notifications.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final notification = nState.notifications[index];
                  final typeColor = _colorForType(notification.type);

                  return InkWell(
                    onTap: () => _onTapNotification(notification),
                    child: Container(
                      color: notification.isRead
                          ? null
                          : AppTheme.primaryColor.withValues(alpha: 0.05),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _iconForType(notification.type),
                              color: typeColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notification.body,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeago.format(
                                    notification.createdAt,
                                    locale: 'ko',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!notification.isRead)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 8),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
