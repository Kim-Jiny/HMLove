import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/letter_provider.dart';

class LetterReadScreen extends ConsumerStatefulWidget {
  final String letterId;

  const LetterReadScreen({super.key, required this.letterId});

  @override
  ConsumerState<LetterReadScreen> createState() => _LetterReadScreenState();
}

class _LetterReadScreenState extends ConsumerState<LetterReadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    Future.microtask(() {
      ref.read(letterProvider.notifier).fetchLetter(widget.letterId);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letterState = ref.watch(letterProvider);
    final letter = letterState.selectedLetter;

    if (letterState.isLoading || letter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('편지')),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
      );
    }

    final currentUserId = ApiClient.getUserId();
    final isWriter = letter.writerId == currentUserId;

    // 수신자이고 아직 배달 전이면 잠금 화면
    if (!isWriter && !letter.isDelivered) {
      return _buildLockedView(letter.deliveryDate);
    }

    // 수신자이고 배달 완료되었으면 읽음 처리
    if (!isWriter && !letter.isRead) {
      Future.microtask(() {
        ref.read(letterProvider.notifier).markAsRead(widget.letterId);
      });
    }

    // Start fade animation
    if (!_fadeController.isCompleted) {
      _fadeController.forward();
    }

    return _buildLetterView(letter, isWriter: isWriter);
  }

  Widget _buildLockedView(DateTime deliveryDate) {
    final now = DateTime.now();
    final difference = deliveryDate.difference(now);
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    return Scaffold(
      appBar: AppBar(title: const Text('편지')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFFFF5F7),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sealed envelope icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outlined,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '아직 열어볼 수 없어요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${DateFormat('yyyy년 M월 d일 HH:mm').format(deliveryDate.toLocal())}에 전달 예정',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Countdown
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CountdownUnit(
                    value: days.toString(),
                    label: '일',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFF0F0F0),
                  ),
                  _CountdownUnit(
                    value: hours.toString().padLeft(2, '0'),
                    label: '시간',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFF0F0F0),
                  ),
                  _CountdownUnit(
                    value: minutes.toString().padLeft(2, '0'),
                    label: '분',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '조금만 더 기다려주세요',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterView(Letter letter, {required bool isWriter}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('편지'),
        actions: [
          if (isWriter && !letter.isDelivered) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_send_outlined,
                      size: 14,
                      color: AppTheme.warningColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('M/d HH:mm').format(letter.deliveryDate.toLocal())} 발송 예정',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '수정',
              onPressed: () {
                context.push('/letter/write', extra: letter);
              },
            ),
          ],
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFFFF5F7),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE8DDD0),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From
                  if (letter.writerNickname != null) ...[
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryLight.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              letter.writerNickname!.isNotEmpty
                                  ? letter.writerNickname![0]
                                  : '?',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              letter.writerNickname!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Text(
                              'From',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Title
                  Text(
                    letter.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Delivery date
                  Text(
                    DateFormat('yyyy년 M월 d일 HH:mm')
                        .format(letter.deliveryDate.toLocal()),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const Divider(
                    color: Color(0xFFE8DDD0),
                    height: 32,
                  ),

                  // Content
                  Text(
                    letter.content ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 2.0,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Heart decoration
                  Center(
                    child: Icon(
                      Icons.favorite,
                      color: AppTheme.primaryLight.withValues(alpha: 0.5),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final String value;
  final String label;

  const _CountdownUnit({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
