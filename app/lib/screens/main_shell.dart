import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/push_notification_service.dart';
import '../core/theme.dart';
import '../providers/badge_provider.dart';
import '../providers/chat_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(badgeProvider.notifier).fetchBadges();
      // 소켓 연결 (채팅 실시간 수신을 위해)
      final token = ApiClient.getAccessToken();
      if (token != null) {
        ref.read(chatProvider.notifier).connect(token);
      }
    });
    // 푸시 알림 초기화 - UI가 완전히 빌드된 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(badgeProvider);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: (index) {
            // 탭 이동 시 뱃지 클리어
            if (index == 1) {
              ref.read(badgeProvider.notifier).clearChatBadge();
            } else if (index == 3) {
              ref.read(badgeProvider.notifier).clearFeedBadge();
            }
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: _BadgeIcon(
                icon: Icons.chat_bubble_outline,
                count: badges.unreadChatCount,
              ),
              activeIcon: _BadgeIcon(
                icon: Icons.chat_bubble,
                count: badges.unreadChatCount,
              ),
              label: '채팅',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: '캘린더',
            ),
            BottomNavigationBarItem(
              icon: _BadgeIcon(
                icon: Icons.feed_outlined,
                count: badges.unseenFeedCount,
              ),
              activeIcon: _BadgeIcon(
                icon: Icons.feed,
                count: badges.unseenFeedCount,
              ),
              label: '피드',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.more_horiz),
              activeIcon: Icon(Icons.more_horiz),
              label: '더보기',
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _BadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);

    return Badge(
      label: count > 99
          ? const Text('99+', style: TextStyle(fontSize: 9))
          : Text('$count', style: const TextStyle(fontSize: 10)),
      backgroundColor: AppTheme.primaryColor,
      child: Icon(icon),
    );
  }
}
