import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/letter_provider.dart';

class LetterListScreen extends ConsumerStatefulWidget {
  const LetterListScreen({super.key});

  @override
  ConsumerState<LetterListScreen> createState() => _LetterListScreenState();
}

class _LetterListScreenState extends ConsumerState<LetterListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(letterProvider.notifier).fetchLetters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letterState = ref.watch(letterProvider);
    final currentUserId = ApiClient.getUserId();
    final allLetters = letterState.letters;

    // 보낸 편지: 내가 쓴 모든 편지 (SCHEDULED 포함)
    final sentLetters =
        allLetters.where((l) => l.writerId == currentUserId).toList();

    // 받은 편지: 배달 완료된 편지만
    final receivedLetters = allLetters
        .where((l) => l.receiverId == currentUserId && l.isDelivered)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('편지함'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('보낸 편지'),
                  if (sentLetters.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${sentLetters.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('받은 편지'),
                  if (receivedLetters.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${receivedLetters.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: letterState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Sent letters tab
                _LetterListTab(
                  letters: sentLetters,
                  isSent: true,
                  emptyMessage: '아직 보낸 편지가 없어요',
                  emptySubMessage: '소중한 마음을 편지로 전해보세요',
                  onRefresh: () async {
                    await ref.read(letterProvider.notifier).fetchLetters();
                  },
                ),
                // Received letters tab
                _LetterListTab(
                  letters: receivedLetters,
                  isSent: false,
                  emptyMessage: '아직 받은 편지가 없어요',
                  emptySubMessage: '편지가 도착하면 여기에 표시됩니다',
                  onRefresh: () async {
                    await ref.read(letterProvider.notifier).fetchLetters();
                  },
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/letter/write');
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _LetterListTab extends StatelessWidget {
  final List<Letter> letters;
  final bool isSent;
  final String emptyMessage;
  final String emptySubMessage;
  final Future<void> Function() onRefresh;

  const _LetterListTab({
    required this.letters,
    required this.isSent,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSent
                    ? Icons.outgoing_mail
                    : Icons.markunread_mailbox_outlined,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubMessage,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: letters.length,
        itemBuilder: (context, index) {
          final letter = letters[index];
          return _LetterCard(
            letter: letter,
            isSent: isSent,
          );
        },
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  final Letter letter;
  final bool isSent;

  const _LetterCard({
    required this.letter,
    required this.isSent,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return AppTheme.textSecondary;
      case 'SCHEDULED':
        return AppTheme.warningColor;
      case 'DELIVERED':
        return AppTheme.successColor;
      default:
        return AppTheme.textHint;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return '임시저장';
      case 'SCHEDULED':
        return '발송 예정';
      case 'DELIVERED':
        return '전달됨';
      default:
        return '알 수 없음';
    }
  }

  IconData _getEnvelopeIcon() {
    if (!isSent) {
      final isRead = letter.isRead;
      return isRead
          ? Icons.drafts_outlined
          : Icons.mark_email_unread_outlined;
    }
    // Sent letter
    if (letter.isScheduled) {
      return Icons.schedule_send_outlined;
    }
    return Icons.send_outlined;
  }

  String? _getDdayText() {
    if (!letter.isScheduled) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final delivery =
        DateTime(letter.deliveryDate.year, letter.deliveryDate.month, letter.deliveryDate.day);
    final diff = delivery.difference(today).inDays;
    if (diff <= 0) return 'D-Day';
    return 'D-$diff';
  }

  @override
  Widget build(BuildContext context) {
    final status = letter.status;
    final isUnreadDelivered = !isSent && letter.isDelivered && !letter.isRead;
    final ddayText = isSent ? _getDdayText() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isSent && !letter.isDelivered) {
            context.push('/letter/write', extra: letter);
          } else {
            context.push('/letter/${letter.id}');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isUnreadDelivered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                )
              : null,
          child: Row(
            children: [
              // Envelope icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: letter.isScheduled
                      ? AppTheme.warningColor.withValues(alpha: 0.1)
                      : isUnreadDelivered
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : AppTheme.primaryLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getEnvelopeIcon(),
                  color: letter.isScheduled
                      ? AppTheme.warningColor
                      : isUnreadDelivered
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Title and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      letter.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isUnreadDelivered
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          DateFormat('yyyy년 M월 d일 HH:mm')
                              .format(letter.deliveryDate.toLocal()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (ddayText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ddayText,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warningColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
