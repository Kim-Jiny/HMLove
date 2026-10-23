import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/mood_emojis.dart';
import '../../widgets/cute/mood_face.dart';
import '../../widgets/cute/motion.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../core/widget_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../couple/invite_code_dialog.dart';
import 'widgets/home_sections.dart';
import '../../widgets/cute/sticker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/letter_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/mission_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/doodle_provider.dart';
import '../../providers/home_summary_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

Map<String, dynamic>? _getNextAnniversary(DateTime? startDate) {
  if (startDate == null) return null;
  final today = DateUtils.dateOnly(DateTime.now());
  final start = DateUtils.dateOnly(startDate);
  final milestones = [50, 100, 200, 300, 365, 500, 700, 730, 1000, 1095, 1461];
  for (final days in milestones) {
    final date = start.add(Duration(days: days - 1));
    if (date.isAfter(today)) {
      return {
        'name': '$days일',
        'date': date,
        'daysLeft': date.difference(today).inDays,
      };
    }
  }
  int year = today.year - start.year;
  if (DateTime(today.year, start.month, start.day).isBefore(today)) year++;
  final nextAnniv = DateTime(start.year + year, start.month, start.day);
  return {
    'name': '$year주년',
    'date': nextAnniv,
    'daysLeft': nextAnniv.difference(today).inDays,
  };
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fetch data on load

    Future.microtask(() async {
      if (!mounted) return;
      await fetchAndApplyHomeSummary(ref);
      if (!mounted) return;
      _syncWidgetCouple(ref.read(coupleProvider));
      _syncWidgetMood(ref.read(moodProvider));
      _syncWidgetDoodle(ref.read(doodleProvider));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background → sync all widget data
      _syncWidgetCouple(ref.read(coupleProvider));
      _syncWidgetMood(ref.read(moodProvider));
      _syncWidgetDoodle(ref.read(doodleProvider));
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground → refresh all data
      fetchAndApplyHomeSummary(ref);
    }
  }

  void _syncWidgetCouple(dynamic coupleState) {
    final couple = coupleState.couple;
    if (couple == null) {
      WidgetService.clearData();
      return;
    }
    final u = ref.read(currentUserProvider);
    final anniversary = _getNextAnniversary(couple.startDate);
    WidgetService.updateCoupleData(
      myName: u?.nickname ?? '나',
      partnerName: couple.partnerDisplayName(u?.id ?? ''),
      daysTogether: couple.daysTogether,
      startDate:
          '${couple.startDate.year}.${couple.startDate.month.toString().padLeft(2, '0')}.${couple.startDate.day.toString().padLeft(2, '0')}',
      nextAnniversaryName: anniversary?['name'] as String?,
      nextAnniversaryDaysLeft: anniversary?['daysLeft'] as int?,
    );
  }

  void _syncWidgetMood(dynamic moodState) {
    WidgetService.updateMoodData(
      myMoodKey: moodState.myMood?.emoji,
      partnerMoodKey: moodState.partnerMood?.emoji,
    );
  }

  void _syncWidgetDoodle(DoodleState doodleState) {
    final latest = doodleState.latestReceived;
    WidgetService.updateDoodleData(
      imageUrl: latest?.imageUrl,
      receivedAt: latest?.createdAt,
      senderName: latest?.senderNickname,
    );
  }

  void _showEditStartDate(DateTime? currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '사귄 날짜를 선택하세요',
      cancelText: '취소',
      confirmText: '변경',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('사귄 날짜 변경'),
          content: Text(
            '${DateFormat('yyyy년 M월 d일').format(picked)}로 변경하시겠습니까?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('변경'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final success = await ref
            .read(coupleProvider.notifier)
            .updateStartDate(picked);
        if (mounted) {
          showTopSnackBar(
            context,
            success ? '사귄 날짜가 변경되었습니다.' : '날짜 변경에 실패했습니다.',
            isError: !success,
          );
        }
      }
    }
  }

  void _showMoodPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '오늘의 기분을 골라주세요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in moodLabels.entries.indexed)
                FadeSlideIn(
                  index: entry.$1 ~/ 3,
                  child: Bouncy(
                    pressedScale: 0.85,
                    onTap: () async {
                      Navigator.pop(context);
                      await ref
                          .read(moodProvider.notifier)
                          .setMood(emoji: entry.$2.key);
                    },
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MoodFace(moodKey: entry.$2.key, size: 54),
                          const SizedBox(height: 4),
                          Text(
                            entry.$2.value,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isSolo = ref.watch(isSoloProvider);
    final coupleState = ref.watch(coupleProvider);
    final daysTogether = ref.watch(daysSinceStartProvider);
    final moodState = ref.watch(moodProvider);
    final unreadLetters = ref.watch(unreadLettersCountProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final missionState = ref.watch(missionProvider);
    final questionState = ref.watch(questionProvider);
    final wishlistState = ref.watch(wishlistProvider);

    // Sync widget data when couple/mood/doodle changes
    ref.listen(coupleProvider, (_, next) => _syncWidgetCouple(next));
    ref.listen(moodProvider, (_, next) => _syncWidgetMood(next));
    ref.listen(doodleProvider, (_, next) => _syncWidgetDoodle(next));

    final couple = coupleState.couple;
    final anniversary = _getNextAnniversary(couple?.startDate);

    Future<void> onCompleteMission(String id) async {
      final success = await ref
          .read(missionProvider.notifier)
          .completeMission(id);
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        success ? '미션 완료!' : '미션 완료에 실패했습니다.',
        isError: !success,
      );
    }

    Future<void> onCancelMission(String id) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('미션 취소'),
          content: const Text('미션 완료를 취소하시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('취소하기'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      final success = await ref
          .read(missionProvider.notifier)
          .cancelMission(id);
      if (!context.mounted) return;
      showTopSnackBar(
        context,
        success ? '미션 완료가 취소되었습니다.' : '취소에 실패했습니다.',
        isError: !success,
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () async {
          await fetchAndApplyHomeSummary(ref);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: staggered([
              HomeHero(
                myName: user?.nickname ?? '나',
                partnerName:
                    couple?.partnerDisplayName(user?.id ?? '') ?? '상대방',
                myMood: moodState.myMood?.emoji,
                partnerMood: moodState.partnerMood?.emoji,
                daysTogether: daysTogether,
                startDate: couple?.startDate,
                waitingForPartner: isSolo && couple != null,
                nextAnniversaryName: anniversary?['name'] as String?,
                nextAnniversaryDaysLeft: anniversary?['daysLeft'] as int?,
                actions: HeroIconButton(
                  icon: Icons.notifications_none_rounded,
                  badge: unreadNotifications,
                  onTap: () => context.push('/notifications'),
                ),
                onEditDate: () => _showEditStartDate(couple?.startDate),
                onPickMood: _showMoodPicker,
                onInvite: () {
                  if (couple != null) {
                    showInviteCodeDialog(context, couple.inviteCode);
                  }
                },
                onAnniversary: () => context.push('/anniversary'),
              ),

              ShortcutRow(
                items: [
                  ShortcutItem(
                    label: '기념일',
                    icon: const Icon(
                      Icons.celebration_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    background: AppTheme.primarySoft,
                    onTap: () => context.push('/anniversary'),
                  ),
                  ShortcutItem(
                    label: '편지',
                    icon: const Sticker(StickerKind.gift, size: 30),
                    background: AppTheme.lavenderSoft,
                    badge: unreadLetters,
                    onTap: () => context.push('/letter'),
                  ),
                  ShortcutItem(
                    label: '위시',
                    icon: const Sticker(StickerKind.heart, size: 28),
                    background: AppTheme.peachSoft,
                    onTap: () => context.push('/wishlist'),
                  ),
                  ShortcutItem(
                    label: '운세',
                    icon: const Sticker(StickerKind.sparkle, size: 30),
                    background: AppTheme.butterSoft,
                    onTap: () => context.push('/fortune'),
                  ),
                  if (!isSolo)
                    ShortcutItem(
                      label: '그림',
                      icon: const Icon(
                        Icons.brush_rounded,
                        color: AppTheme.mint,
                      ),
                      background: AppTheme.mintSoft,
                      onTap: () => context.push('/doodle'),
                    ),
                ],
              ),

              const SectionHeader(title: '오늘의 질문'),
              QuestionBubble(
                question: questionState.today,
                waitingForPartner: isSolo,
                onTap: () => context.push('/question'),
              ),

              const SectionHeader(title: '커플 미션'),
              MissionSection(
                daily: missionState.daily,
                weekly: missionState.weekly,
                isLoading: missionState.isLoading,
                onComplete: onCompleteMission,
                onCancel: onCancelMission,
              ),

              SectionHeader(
                title: '위시리스트',
                actionLabel: '전체보기',
                onAction: () => context.push('/wishlist'),
              ),
              WishStrip(
                state: wishlistState,
                onTap: () => context.push('/wishlist'),
              ),

              const SizedBox(height: 20),
              BannerAdWidget(adUnitId: AppConstants.adMobHomeBanner),
              const SizedBox(height: 28),
            ]),
          ),
        ),
      ),
    );
  }
}
