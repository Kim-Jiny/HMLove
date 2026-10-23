import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/mood_emojis.dart';
import '../../../core/theme.dart';
import '../../../models/daily_question.dart';
import '../../../providers/mission_provider.dart';
import '../../../providers/wishlist_provider.dart';
import '../../../widgets/cute/mood_face.dart';
import '../../../widgets/cute/motion.dart';
import '../../../widgets/cute/sticker.dart';

/// 홈 상단 히어로: 화면 끝까지 닿는 파스텔 면 위에 두 사람의 오늘 기분과 D-day 를 둔다.
/// 카드 테두리 없이 면 자체가 영역이 된다.
class HomeHero extends StatelessWidget {
  final String myName;
  final String partnerName;
  final String? myMood;
  final String? partnerMood;
  final int? daysTogether;
  final DateTime? startDate;
  final bool waitingForPartner;
  final String? nextAnniversaryName;
  final int? nextAnniversaryDaysLeft;
  final Widget actions;
  final VoidCallback onEditDate;
  final VoidCallback onPickMood;
  final VoidCallback onInvite;
  final VoidCallback onAnniversary;
  final VoidCallback? onPoke;
  final VoidCallback? onPokeLong;

  const HomeHero({
    super.key,
    required this.myName,
    required this.partnerName,
    required this.myMood,
    required this.partnerMood,
    required this.daysTogether,
    required this.startDate,
    required this.waitingForPartner,
    required this.nextAnniversaryName,
    required this.nextAnniversaryDaysLeft,
    required this.actions,
    required this.onEditDate,
    required this.onPickMood,
    required this.onInvite,
    required this.onAnniversary,
    this.onPoke,
    this.onPokeLong,
  });

  Widget _person(String name, String? mood, {required bool mine}) {
    return Expanded(
      child: Column(
        children: [
          Bouncy(
            onTap: mine ? onPickMood : null,
            pressedScale: 0.9,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                MoodFace(moodKey: mood, size: 76, pop: true),
                if (mine)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.ink, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 11,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(
            mood == null
                ? (mine ? '기분을 알려주세요' : '아직이에요')
                : (moodLabels[mood] ?? ''),
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE3EC), Color(0xFFF0EDFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
        border: Border(
          bottom: BorderSide(color: AppTheme.ink, width: AppTheme.outlineWidth),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '우리연애',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              actions,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _person(myName, myMood, mine: true),
              Padding(
                padding: const EdgeInsets.only(top: 26),
                // 누르면 '보고싶어' 콕, 길게 누르면 다른 스티커 선택
                child: Bouncy(
                  onTap: onPoke,
                  onLongPress: onPokeLong,
                  pressedScale: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Heartbeat(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: AppTheme.primaryColor.withValues(alpha: 0.9),
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              _person(partnerName, partnerMood, mine: false),
            ],
          ),
          const SizedBox(height: 18),
          Bouncy(
            onTap: onEditDate,
            pressedScale: 0.96,
            child: Column(
              children: [
                Text(
                  daysTogether != null ? 'D+$daysTogether' : 'D+-',
                  style: const TextStyle(
                    fontSize: 54,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  startDate != null
                      ? '${DateFormat('yyyy.MM.dd').format(startDate!)} 부터 함께'
                      : '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (nextAnniversaryName != null)
                _HeroPill(
                  icon: Icons.celebration_rounded,
                  label: '$nextAnniversaryName · D-$nextAnniversaryDaysLeft',
                  onTap: onAnniversary,
                ),
              if (waitingForPartner)
                _HeroPill(
                  icon: Icons.person_add_alt_1_rounded,
                  label: '상대방 초대하기',
                  onTap: onInvite,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.ink, width: 1.3),
          boxShadow: AppTheme.cartoonShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 히어로 우측 상단의 동그란 아이콘 버튼(알림 등).
class HeroIconButton extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const HeroIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.ink, width: 1.3),
      ),
      child: Icon(icon, size: 20, color: AppTheme.ink),
    );
    return Bouncy(
      onTap: onTap,
      pressedScale: 0.88,
      child: badge > 0
          ? Badge(
              label: Text(badge > 9 ? '9+' : '$badge'),
              backgroundColor: AppTheme.primaryColor,
              child: btn,
            )
          : btn,
    );
  }
}

/// 섹션 제목 줄: 카드 대신 이 한 줄이 영역을 구분한다.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            Bouncy(
              onTap: onAction,
              child: Text(
                '$actionLabel ›',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 둥근 바로가기 버튼 한 줄 (기념일·편지·위시·운세·그림).
class ShortcutItem {
  final String label;
  final Widget icon;
  final Color background;
  final int badge;
  final VoidCallback onTap;
  const ShortcutItem({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
    this.badge = 0,
  });
}

class ShortcutRow extends StatelessWidget {
  final List<ShortcutItem> items;
  const ShortcutRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final e in items)
            Bouncy(
              onTap: e.onTap,
              pressedScale: 0.86,
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Badge(
                      isLabelVisible: e.badge > 0,
                      label: Text('${e.badge}'),
                      backgroundColor: AppTheme.primaryColor,
                      child: Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: e.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.ink,
                            width: AppTheme.outlineWidth,
                          ),
                          boxShadow: AppTheme.cartoonShadow,
                        ),
                        child: e.icon,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      e.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 오늘의 질문: 카드 대신 말풍선. 꼬리가 달려 "누가 말을 거는" 느낌을 준다.
class QuestionBubble extends StatelessWidget {
  final DailyQuestion? question;
  final bool waitingForPartner;
  final VoidCallback onTap;
  const QuestionBubble({
    super.key,
    required this.question,
    required this.waitingForPartner,
    required this.onTap,
  });

  ({String text, Color color}) get _status {
    final q = question;
    if (q == null) return (text: '눌러서 확인해요', color: AppTheme.lavender);
    if (q.myAnswer == null) return (text: '아직 답하지 않았어요', color: AppTheme.peach);
    if (q.canReveal && q.partnerAnswer != null) {
      return (text: '둘 다 답했어요', color: AppTheme.mint);
    }
    if (waitingForPartner) return (text: '답변을 남겼어요', color: AppTheme.mint);
    return (text: '상대방 답변을 기다리는 중', color: AppTheme.sky);
  }

  @override
  Widget build(BuildContext context) {
    final st = _status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Bouncy(
        onTap: onTap,
        pressedScale: 0.97,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lavenderSoft,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppTheme.ink,
                  width: AppTheme.outlineWidth,
                ),
                boxShadow: AppTheme.cartoonShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question?.questionText ?? '오늘의 질문을 불러오고 있어요',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          st.text,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: st.color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '답하러 가기 ›',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lavender,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: CustomPaint(
                size: const Size(24, 14),
                painter: _BubbleTailPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -2)
      ..lineTo(size.width * 0.35, size.height)
      ..lineTo(size.width, -2)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.lavenderSoft);
    final line = Paint()
      ..color = AppTheme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppTheme.outlineWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.35, size.height)
        ..lineTo(size.width, 0),
      line,
    );
    // 말풍선 아랫변 선을 꼬리 부분만 지운다
    canvas.drawLine(
      const Offset(1.5, -1),
      Offset(size.width - 1.5, -1),
      Paint()
        ..color = AppTheme.lavenderSoft
        ..strokeWidth = AppTheme.outlineWidth + 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 미션: 카드 없이 체크 줄로. 눌러서 완료/취소.
class MissionSection extends StatelessWidget {
  final Mission? daily;
  final Mission? weekly;
  final bool isLoading;
  final void Function(String id) onComplete;
  final void Function(String id) onCancel;
  const MissionSection({
    super.key,
    required this.daily,
    required this.weekly,
    required this.isLoading,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final missions = [(daily, '오늘'), (weekly, '이번 주')];
    if (isLoading && daily == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('불러오는 중...', style: TextStyle(color: AppTheme.textHint)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final (m, label) in missions)
            if (m != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Bouncy(
                  onTap: () =>
                      m.isCompleted ? onCancel(m.id) : onComplete(m.id),
                  pressedScale: 0.97,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: m.isCompleted ? AppTheme.mintSoft : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.ink, width: 1.3),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.elasticOut,
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: m.isCompleted ? AppTheme.mint : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.ink, width: 1.5),
                          ),
                          child: m.isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$label 미션',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  decoration: m.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: m.isCompleted
                                      ? AppTheme.textSecondary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(m.emoji, style: const TextStyle(fontSize: 22)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 위시리스트: 즐겨찾기를 가로 칩으로 훑어본다.
class WishStrip extends StatelessWidget {
  final WishlistState state;
  final VoidCallback onTap;
  const WishStrip({super.key, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = state.items.where((e) => e.isFavorite).toList();
    final shown = (items.isEmpty ? state.items : items).take(8).toList();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (shown.isEmpty)
            _WishChip(
              leading: const Sticker(StickerKind.heart, size: 18),
              label: '첫 위시를 추가해볼까요?',
              onTap: onTap,
            ),
          for (final w in shown)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _WishChip(
                leading: Sticker(stickerFor(w.category), size: 18),
                label: w.title,
                done: w.isCompleted,
                onTap: onTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _WishChip extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool done;
  final VoidCallback onTap;
  const _WishChip({
    required this.leading,
    required this.label,
    required this.onTap,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.peachSoft,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: AppTheme.ink, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? AppTheme.textHint : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
