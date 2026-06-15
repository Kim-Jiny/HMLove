import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/daily_question.dart';

// Today's Question Mini Card
class QuestionMiniCard extends StatelessWidget {
  final DailyQuestion? question;
  final VoidCallback onTap;

  const QuestionMiniCard({super.key, this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    final q = question;
    if (q == null) {
      statusText = '오늘의 질문을 확인하세요';
      statusColor = const Color(0xFF3F51B5);
      statusIcon = Icons.quiz_outlined;
    } else if (q.myAnswer == null) {
      statusText = '아직 답변하지 않았어요';
      statusColor = const Color(0xFFFF9800);
      statusIcon = Icons.edit_outlined;
    } else if (q.partnerAnswered && !q.canReveal) {
      statusText = '둘 다 답변했어요! 곧 공개됩니다';
      statusColor = const Color(0xFF9C27B0);
      statusIcon = Icons.lock_clock;
    } else if (!q.canReveal) {
      statusText = '상대방 답변을 기다리고 있어요';
      statusColor = const Color(0xFF2196F3);
      statusIcon = Icons.hourglass_empty;
    } else {
      statusText = '둘 다 답변 완료!';
      statusColor = const Color(0xFF4CAF50);
      statusIcon = Icons.check_circle_outline;
    }

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
                  color: const Color(0xFF3F51B5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  color: Color(0xFF3F51B5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '오늘의 질문',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
