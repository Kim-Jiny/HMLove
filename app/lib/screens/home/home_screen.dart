import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/fortune_provider.dart';
import '../../providers/badge_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch data on load
    Future.microtask(() {
      ref.read(coupleProvider.notifier).fetchCouple();
      ref.read(moodProvider.notifier).fetchTodayMood();
      ref.read(fortuneProvider.notifier).fetchTodayFortune();
      ref.read(badgeProvider.notifier).fetchBadges();
    });
  }

  void _showMoodPicker() {
    final moods = [
      {'key': 'happy', 'emoji': '😊', 'label': '행복해'},
      {'key': 'love', 'emoji': '🥰', 'label': '사랑해'},
      {'key': 'sad', 'emoji': '😢', 'label': '슬퍼'},
      {'key': 'angry', 'emoji': '😤', 'label': '화나'},
      {'key': 'tired', 'emoji': '😴', 'label': '피곤해'},
      {'key': 'excited', 'emoji': '🤩', 'label': '신나'},
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
                await ref.read(moodProvider.notifier).setMood(
                      emoji: mood['key'] as String,
                    );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('HMLove'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          await Future.wait<void>([
            ref.read(coupleProvider.notifier).fetchCouple(),
            ref.read(moodProvider.notifier).fetchTodayMood(),
            ref.read(fortuneProvider.notifier).fetchTodayFortune(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // D-Day Card
              _DdayCard(
                daysTogether: daysTogether,
                startDate: coupleState.couple?.startDate,
                user1Name: user?.nickname ?? '나',
                user2Name: coupleState.couple?.getPartner(user?.id ?? '')?.nickname ?? '상대방',
              ),
              const SizedBox(height: 12),

              // Next Anniversary Card
              _AnniversaryCard(
                startDate: coupleState.couple?.startDate,
              ),
              const SizedBox(height: 12),

              // Mood Card
              _MoodCard(
                myMoodEmoji: moodState.myMood?.emoji,
                partnerMoodEmoji: moodState.partnerMood?.emoji,
                myName: user?.nickname ?? '나',
                partnerName: coupleState.couple
                        ?.getPartner(user?.id ?? '')
                        ?.nickname ??
                    '상대방',
                onTap: _showMoodPicker,
              ),
              const SizedBox(height: 12),

              // Today's Fortune Card
              _FortuneCard(
                luckyScore: fortuneState.fortune?.luckyScore,
                coupleLuck: fortuneState.fortune?.coupleLuck,
                isLoading: fortuneState.isLoading,
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

// D-Day Counter Card
class _DdayCard extends StatelessWidget {
  final int? daysTogether;
  final DateTime? startDate;
  final String user1Name;
  final String user2Name;

  const _DdayCard({
    this.daysTogether,
    this.startDate,
    required this.user1Name,
    required this.user2Name,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.primaryGradient,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user1Name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Text(
                  user2Name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              daysTogether != null ? '$daysTogether일' : '- 일',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              startDate != null
                  ? '${DateFormat('yyyy.MM.dd').format(startDate!)} ~'
                  : '',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Next Anniversary Card
class _AnniversaryCard extends StatelessWidget {
  final DateTime? startDate;

  const _AnniversaryCard({this.startDate});

  Map<String, dynamic>? _getNextAnniversary() {
    if (startDate == null) return null;

    final now = DateTime.now();
    final milestones = [100, 200, 300, 365, 500, 700, 730, 1000, 1095, 1461];

    for (final days in milestones) {
      final date = startDate!.add(Duration(days: days - 1));
      if (date.isAfter(now)) {
        final daysLeft = date.difference(now).inDays;
        return {
          'name': '$days일',
          'date': date,
          'daysLeft': daysLeft,
        };
      }
    }

    // Annual anniversary
    int year = now.year - startDate!.year;
    if (DateTime(now.year, startDate!.month, startDate!.day).isBefore(now)) {
      year++;
    }
    final nextAnniv = DateTime(
      startDate!.year + year,
      startDate!.month,
      startDate!.day,
    );
    return {
      'name': '$year주년',
      'date': nextAnniv,
      'daysLeft': nextAnniv.difference(now).inDays,
    };
  }

  @override
  Widget build(BuildContext context) {
    final anniversary = _getNextAnniversary();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.celebration_outlined,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '다음 기념일',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    anniversary != null
                        ? anniversary['name'] as String
                        : '정보 없음',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (anniversary != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'D-${anniversary['daysLeft']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    DateFormat('M월 d일')
                        .format(anniversary['date'] as DateTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Mood Card
class _MoodCard extends StatelessWidget {
  final String? myMoodEmoji;
  final String? partnerMoodEmoji;
  final String myName;
  final String partnerName;
  final VoidCallback onTap;

  const _MoodCard({
    this.myMoodEmoji,
    this.partnerMoodEmoji,
    required this.myName,
    required this.partnerName,
    required this.onTap,
  });

  String _getMoodDisplay(String? emoji) {
    switch (emoji) {
      case 'happy':
        return '😊';
      case 'love':
        return '🥰';
      case 'sad':
        return '😢';
      case 'angry':
        return '😤';
      case 'tired':
        return '😴';
      case 'excited':
        return '🤩';
      default:
        return '😶';
    }
  }

  String _getMoodText(String? emoji) {
    switch (emoji) {
      case 'happy':
        return '행복해';
      case 'love':
        return '사랑해';
      case 'sad':
        return '슬퍼';
      case 'angry':
        return '화나';
      case 'tired':
        return '피곤해';
      case 'excited':
        return '신나';
      default:
        return '설정 안 됨';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '오늘의 기분',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    '탭하여 변경',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _getMoodDisplay(myMoodEmoji),
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          myName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getMoodText(myMoodEmoji),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.favorite,
                    color: AppTheme.primaryLight,
                    size: 20,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _getMoodDisplay(partnerMoodEmoji),
                          style: const TextStyle(fontSize: 36),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          partnerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getMoodText(partnerMoodEmoji),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Today's Fortune Card
class _FortuneCard extends StatelessWidget {
  final int? luckyScore;
  final String? coupleLuck;
  final bool isLoading;
  final VoidCallback onTap;

  const _FortuneCard({
    this.luckyScore,
    this.coupleLuck,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 커플 운세',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isLoading)
                      const Text(
                        '불러오는 중...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    else if (luckyScore != null)
                      Text(
                        '행운 점수: $luckyScore점',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      const Text(
                        '탭하여 오늘의 운세를 확인하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
