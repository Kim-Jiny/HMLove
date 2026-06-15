import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/mood_emojis.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../core/widget_service.dart';
import '../../widgets/banner_ad_widget.dart';
import 'widgets/anniversary_card.dart';
import 'widgets/dday_card.dart';
import 'widgets/doodle_card.dart';
import 'widgets/fortune_card.dart';
import 'widgets/mission_card.dart';
import 'widgets/mood_card.dart';
import 'widgets/question_mini_card.dart';
import 'widgets/wishlist_preview_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/fortune_provider.dart';
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
    final partner = couple.getPartner(u?.id ?? '');
    final anniversary = _getNextAnniversary(couple.startDate);
    WidgetService.updateCoupleData(
      myName: u?.nickname ?? '나',
      partnerName: partner?.nickname ?? '상대방',
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
    final moods = [
      for (final entry in moodEmojis.entries)
        {
          'key': entry.key,
          'emoji': entry.value,
          'label': moodLabels[entry.key] ?? '',
        },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '오늘의 기분을 선택하세요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: moods.map((mood) {
            return InkWell(
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(moodProvider.notifier)
                    .setMood(emoji: mood['key'] as String);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mood['emoji'] as String,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mood['label'] as String,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final coupleState = ref.watch(coupleProvider);
    final daysTogether = ref.watch(daysSinceStartProvider);
    final moodState = ref.watch(moodProvider);
    final fortuneState = ref.watch(fortuneProvider);
    final unreadLetters = ref.watch(unreadLettersCountProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final missionState = ref.watch(missionProvider);
    final questionState = ref.watch(questionProvider);
    final wishlistState = ref.watch(wishlistProvider);
    final doodleState = ref.watch(doodleProvider);

    // Sync widget data when couple/mood/doodle changes
    ref.listen(coupleProvider, (_, next) => _syncWidgetCouple(next));
    ref.listen(moodProvider, (_, next) => _syncWidgetMood(next));
    ref.listen(doodleProvider, (_, next) => _syncWidgetDoodle(next));

    return Scaffold(
      appBar: AppBar(
        title: const Text('우리연애'),
        actions: [
          if (unreadLetters > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.mail_outlined),
                  onPressed: () => context.push('/letter'),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadLetters > 9 ? '9+' : '$unreadLetters',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          await fetchAndApplyHomeSummary(ref);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // D-Day Card
              DdayCard(
                daysTogether: daysTogether,
                startDate: coupleState.couple?.startDate,
                user1Name: user?.nickname ?? '나',
                user2Name:
                    coupleState.couple?.getPartner(user?.id ?? '')?.nickname ??
                    '상대방',
                onEditDate: () =>
                    _showEditStartDate(coupleState.couple?.startDate),
              ),
              const SizedBox(height: 12),

              // Next Anniversary Card
              AnniversaryCard(
                startDate: coupleState.couple?.startDate,
                onTap: () => context.push('/anniversary'),
              ),
              const SizedBox(height: 12),

              // Question Card
              QuestionMiniCard(
                question: questionState.today,
                onTap: () => context.push('/question'),
              ),
              const SizedBox(height: 12),

              WishlistPreviewCard(
                state: wishlistState,
                onTap: () => context.push('/wishlist'),
              ),
              const SizedBox(height: 12),

              // Doodle Card (그림 보내기)
              DoodleCard(
                latest: doodleState.latestReceived,
                onTap: () => context.push('/doodle'),
              ),
              const SizedBox(height: 12),

              // Banner Ad
              BannerAdWidget(adUnitId: AppConstants.adMobHomeBanner),
              const SizedBox(height: 12),

              // Mission Card
              MissionCard(
                daily: missionState.daily,
                weekly: missionState.weekly,
                isLoading: missionState.isLoading,
                onComplete: (id) async {
                  final success = await ref
                      .read(missionProvider.notifier)
                      .completeMission(id);
                  if (!context.mounted) return;
                  showTopSnackBar(
                    context,
                    success ? '미션 완료!' : '미션 완료에 실패했습니다.',
                    isError: !success,
                  );
                },
                onCancel: (id) async {
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
                  if (confirm == true) {
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
                },
              ),
              const SizedBox(height: 12),

              // Mood Card
              MoodCard(
                myMoodEmoji: moodState.myMood?.emoji,
                partnerMoodEmoji: moodState.partnerMood?.emoji,
                myName: user?.nickname ?? '나',
                partnerName:
                    coupleState.couple?.getPartner(user?.id ?? '')?.nickname ??
                    '상대방',
                onTap: _showMoodPicker,
              ),
              const SizedBox(height: 12),

              // Today's Fortune Card
              FortuneCard(
                luckyScore: fortuneState.fortune?.luckyScore,
                coupleLuck: fortuneState.fortune?.coupleLuck,
                isLoading: fortuneState.isLoading,
                exists: fortuneState.exists,
                onTap: () {
                  context.push('/fortune');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
