import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../models/daily_question.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/question_provider.dart';

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  final _answerController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(questionProvider.notifier).fetchToday();
      ref.read(questionProvider.notifier).fetchHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    setState(() => _isSubmitting = true);
    final success =
        await ref.read(questionProvider.notifier).submitAnswer(answer);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _answerController.clear();
        showTopSnackBar(context, '답변이 제출되었습니다!');
      } else {
        showTopSnackBar(context, '답변 제출에 실패했습니다.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(questionProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    final coupleState = ref.watch(coupleProvider);
    final partner = coupleState.couple?.getPartner(userId ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 질문')),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          await Future.wait([
            ref.read(questionProvider.notifier).fetchToday(),
            ref.read(questionProvider.notifier).fetchHistory(refresh: true),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 오늘의 질문 카드
            if (state.isLoading && state.today == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state.today != null)
              _TodayQuestionCard(
                question: state.today!,
                userId: userId ?? '',
                partnerName: partner?.nickname ?? '상대방',
                answerController: _answerController,
                isSubmitting: _isSubmitting,
                onSubmit: _submitAnswer,
              ),

            const SizedBox(height: 24),

            // 히스토리
            const Text(
              '지난 질문',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (state.history.isEmpty && !state.isHistoryLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '아직 지난 질문이 없어요',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ...state.history.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryCard(
                    item: item,
                    userId: userId ?? '',
                    partnerName: partner?.nickname ?? '상대방',
                  ),
                )),
            if (state.hasMore)
              Center(
                child: state.isHistoryLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    : TextButton(
                        onPressed: () =>
                            ref.read(questionProvider.notifier).fetchHistory(),
                        child: const Text('더 보기'),
                      ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TodayQuestionCard extends StatelessWidget {
  final DailyQuestion question;
  final String userId;
  final String partnerName;
  final TextEditingController answerController;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _TodayQuestionCard({
    required this.question,
    required this.userId,
    required this.partnerName,
    required this.answerController,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F51B5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.quiz_outlined,
                    color: Color(0xFF3F51B5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '오늘의 질문',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  question.date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 질문 텍스트
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                question.questionText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 내 답변
            if (question.myAnswer != null) ...[
              _AnswerBubble(
                label: '나의 답변',
                answer: question.myAnswer!.answer,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 8),
            ],

            // 파트너 답변
            if (question.partnerAnswer != null) ...[
              _AnswerBubble(
                label: '$partnerName의 답변',
                answer: question.partnerAnswer!.answer,
                color: const Color(0xFF3F51B5),
              ),
            ] else if (question.partnerAnswered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: AppTheme.textHint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$partnerName이(가) 답변했어요! 둘 다 답변하면 공개됩니다.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (question.myAnswer != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$partnerName의 답변을 기다리고 있어요...',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // 답변 입력 (아직 미답변일 때)
            if (question.myAnswer == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: answerController,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '답변을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('답변 제출'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerBubble extends StatelessWidget {
  final String label;
  final String answer;
  final Color color;

  const _AnswerBubble({
    required this.label,
    required this.answer,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Text(
            answer,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final QuestionHistoryItem item;
  final String userId;
  final String partnerName;

  const _HistoryCard({
    required this.item,
    required this.userId,
    required this.partnerName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          item.questionText,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.date,
          style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
        ),
        trailing: Icon(
          item.bothAnswered ? Icons.check_circle : Icons.radio_button_unchecked,
          color: item.bothAnswered ? AppTheme.primaryColor : Colors.grey.shade400,
          size: 20,
        ),
        children: [
          if (item.myAnswer != null)
            _AnswerBubble(
              label: '나의 답변',
              answer: item.myAnswer!.answer,
              color: AppTheme.primaryColor,
            ),
          if (item.myAnswer != null && item.partnerAnswer != null)
            const SizedBox(height: 8),
          if (item.partnerAnswer != null)
            _AnswerBubble(
              label: '$partnerName의 답변',
              answer: item.partnerAnswer!.answer,
              color: const Color(0xFF3F51B5),
            )
          else if (item.partnerAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$partnerName이(가) 답변했어요 (아직 미공개)',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          if (item.myAnswer == null && item.partnerAnswer == null && !item.partnerAnswered)
            const Text(
              '답변 없음',
              style: TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),
        ],
      ),
    );
  }
}
