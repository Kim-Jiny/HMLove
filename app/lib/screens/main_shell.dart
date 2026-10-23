import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/connectivity_service.dart';
import '../core/push_notification_service.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../providers/badge_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/couple_provider.dart';
import '../providers/letter_provider.dart';
import 'cute_nav_bar.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      ref.read(badgeProvider.notifier).fetchBadges();
      ref.read(letterProvider.notifier).fetchLetters();
      // 소켓 연결 (채팅 실시간 수신을 위해)
      ref.read(chatProvider.notifier).ensureConnected();
      // 콜드 스타트 시점엔 lifecycle이 이미 resumed라서 didChangeAppLifecycleState
      // 가 안 불릴 수 있다. 백그라운드에서 위젯이 본 월(pending hydration)을
      // 한 번 따라잡아 둔다 (extras 비면 즉시 return).
      ref.read(calendarProvider.notifier).catchUpWidgetMissingMonths();
    });
    // 푸시 알림 초기화 - UI가 완전히 빌드된 후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.onCoupleLeft = _onCoupleLeft;
      PushNotificationService.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationService.onCoupleLeft = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 상대 연결 전이라면 그 사이 상대가 합류했을 수 있다. 합류했으면 채팅 탭이
      // 열리고 상대 이름이 실제 닉네임으로 바뀌도록 인증·커플 정보를 갱신한다.
      if (ref.read(isSoloProvider)) {
        ref.read(authProvider.notifier).checkAuthStatus();
        ref.read(coupleProvider.notifier).fetchCouple();
      }
      // 앱 포그라운드 복귀 시 기존 transport를 신뢰하지 않고 소켓을 새로 만든다.
      ref.read(chatProvider.notifier).refreshConnectionOnResume();
      // 위젯이 백그라운드에서 prev/next로 이동했을 수 있다. EventKit에 접근할 수
      // 없는 위젯 익스텐션을 대신해 device/holiday 캐시를 채워준다.
      ref.read(calendarProvider.notifier).catchUpWidgetMissingMonths();
    }
  }

  void _onCoupleLeft() {
    // auth 상태 갱신 (isCoupleComplete → false, hasExistingCoupleData 확인)
    ref.read(authProvider.notifier).checkAuthStatus();
    // couple 정보 갱신
    ref.read(coupleProvider.notifier).fetchCouple();
    // 알림 다이얼로그
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('커플 해제 알림'),
            ],
          ),
          content: const Text(
            '상대방이 커플을 해제했습니다.\n'
            '기존 데이터는 계속 확인할 수 있으며,\n'
            '더보기 탭에서 초대 코드를 확인할 수 있습니다.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  void _selectBranch(int index) {
    final badgesNotifier = ref.read(badgeProvider.notifier);
    // 탭 이동 시 뱃지 클리어
    if (index == 1) {
      badgesNotifier.clearChatBadge();
    } else if (index == 3) {
      badgesNotifier.clearFeedBadge();
    }

    // 채팅 탭 활성 상태 관리 (indexedStack은 dispose 안 되므로 여기서 제어)
    ref.read(chatProvider.notifier).setChatScreenActive(index == 1);

    // Navigator.push로 열린 하위 화면들 pop (탭 루트로 복귀)
    shellBranchKeys[index]?.currentState?.popUntil((route) => route.isFirst);
    widget.navigationShell.goBranch(index, initialLocation: true);
  }

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(badgeProvider);
    final isSolo = ref.watch(isSoloProvider);
    // 상대가 연결되면 홈이 한가운데 오도록 5탭, 연결 전엔 채팅(branch 1)을 뺀 4탭.
    final visibleBranches = isSolo ? const [0, 2, 3, 4] : const [2, 1, 0, 3, 4];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // 홈이 아닌 탭 → 홈으로 이동
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        // 홈 브랜치이지만 루트(/home)가 아니면(위젯으로 /doodle 직접 진입 등)
        // 앱 종료가 아니라 홈으로 복귀시킨다. go('/doodle') 는 홈 브랜치 스택을
        // [/doodle] 로 만들어 pop 할 게 없으므로 여기서 명시적으로 처리.
        final loc = GoRouterState.of(context).uri.path;
        if (loc != '/home') {
          widget.navigationShell.goBranch(0, initialLocation: true);
          return;
        }

        // 홈 탭에서 2초 내 두 번 누르면 앱 종료
        final now = DateTime.now();
        if (_lastBackPressed != null &&
            now.difference(_lastBackPressed!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPressed = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('한 번 더 누르면 앱이 종료됩니다'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: widget.navigationShell),
          ],
        ),
        bottomNavigationBar: CuteNavBar(
          selectedBranch: widget.navigationShell.currentIndex,
          entries: [
            for (final branch in visibleBranches)
              switch (branch) {
                0 => const NavEntry(
                  branch: 0,
                  label: '홈',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                ),
                1 => NavEntry(
                  branch: 1,
                  label: '채팅',
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  badge: badges.unreadChatCount,
                ),
                2 => const NavEntry(
                  branch: 2,
                  label: '캘린더',
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                ),
                3 => NavEntry(
                  branch: 3,
                  label: '피드',
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories_rounded,
                  badge: badges.unseenFeedCount,
                ),
                _ => const NavEntry(
                  branch: 4,
                  label: '더보기',
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view_rounded,
                ),
              },
          ],
          onSelect: _selectBranch,
        ),
      ),
    );
  }
}
