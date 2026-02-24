import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/fortune_provider.dart';

class FortuneScreen extends ConsumerStatefulWidget {
  const FortuneScreen({super.key});

  @override
  ConsumerState<FortuneScreen> createState() => _FortuneScreenState();
}

class _FortuneScreenState extends ConsumerState<FortuneScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    Future.microtask(() {
      final state = ref.read(fortuneProvider);
      if (state.fortune != null) {
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchFortune() async {
    await ref.read(fortuneProvider.notifier).fetchTodayFortune();
    if (mounted) {
      _animController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fortuneState = ref.watch(fortuneProvider);
    final fortune = fortuneState.fortune;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 커플 운세'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _fetchFortune,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: fortuneState.isLoading
              ? _buildLoadingState()
              : fortune == null
                  ? _buildInitialState()
                  : _buildFortuneContent(fortune),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shimmer circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryLight.withValues(alpha: 0.3),
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryLight.withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '운세를 확인하고 있어요...',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mystical decoration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF9C27B0).withValues(alpha: 0.1),
                    const Color(0xFF9C27B0).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  size: 56,
                  color: Color(0xFF9C27B0),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '오늘의 운세를 확인해보세요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '둘만의 특별한 운세가 기다리고 있어요',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchFortune,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('운세 확인하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFortuneContent(dynamic fortune) {
    final luckyScore = fortune.luckyScore ?? 0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Lucky Score Card
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFFCE93D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      '오늘의 럭키 점수',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Circular progress
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: _CircularScorePainter(
                          score: luckyScore.toDouble(),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          progressColor: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            '$luckyScore',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getScoreLabel(luckyScore),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // General Luck
            _FortuneCard(
              icon: Icons.stars_outlined,
              iconColor: const Color(0xFFFF9800),
              title: '종합 운세',
              content: fortune.generalLuck ?? '정보를 불러올 수 없습니다',
            ),
            const SizedBox(height: 8),

            // Couple Luck
            _FortuneCard(
              icon: Icons.favorite_outlined,
              iconColor: AppTheme.primaryColor,
              title: '커플 운세',
              content: fortune.coupleLuck ?? '정보를 불러올 수 없습니다',
            ),
            const SizedBox(height: 8),

            // Date Tip
            _FortuneCard(
              icon: Icons.restaurant_outlined,
              iconColor: const Color(0xFF4CAF50),
              title: '데이트 팁',
              content: fortune.dateTip ?? '정보를 불러올 수 없습니다',
            ),
            const SizedBox(height: 8),

            // Personal Fortunes
            if (fortune.user1Luck != null || fortune.user2Luck != null) ...[
              const SizedBox(height: 4),
              _buildPersonalFortunes(fortune),
              const SizedBox(height: 4),
            ],

            // Caution
            _FortuneCard(
              icon: Icons.warning_amber_outlined,
              iconColor: const Color(0xFFF44336),
              title: '주의사항',
              content: fortune.caution ?? '정보를 불러올 수 없습니다',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalFortunes(dynamic fortune) {
    final currentUserId = ref.read(currentUserProvider)?.id;
    final couple = ref.read(coupleProvider).couple;

    // 현재 유저와 파트너 이름 매칭
    String myName = '나';
    String partnerName = '상대방';
    String? myLuck;
    String? partnerLuck;

    if (couple != null && currentUserId != null) {
      for (final user in couple.users) {
        if (user.id == currentUserId) {
          myName = user.nickname;
        } else {
          partnerName = user.nickname;
        }
      }
    }

    if (fortune.user1Id == currentUserId) {
      myLuck = fortune.user1Luck;
      partnerLuck = fortune.user2Luck;
    } else {
      myLuck = fortune.user2Luck;
      partnerLuck = fortune.user1Luck;
    }

    return Column(
      children: [
        if (myLuck != null)
          _FortuneCard(
            icon: Icons.person,
            iconColor: const Color(0xFF2196F3),
            title: '$myName의 오늘 운세',
            content: myLuck,
          ),
        if (myLuck != null && partnerLuck != null)
          const SizedBox(height: 8),
        if (partnerLuck != null)
          _FortuneCard(
            icon: Icons.person_outline,
            iconColor: const Color(0xFFE91E63),
            title: '$partnerName의 오늘 운세',
            content: partnerLuck,
          ),
      ],
    );
  }

  String _getScoreLabel(int score) {
    if (score >= 90) return '최고의 하루!';
    if (score >= 75) return '좋은 하루가 될 거예요';
    if (score >= 60) return '무난한 하루';
    if (score >= 40) return '조금 주의가 필요해요';
    return '서로 배려가 필요한 날';
  }
}

class _FortuneCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _FortuneCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularScorePainter extends CustomPainter {
  final double score;
  final Color backgroundColor;
  final Color progressColor;

  _CircularScorePainter({
    required this.score,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularScorePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
