import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../providers/mission_provider.dart';

// Mission Card
class MissionCard extends StatelessWidget {
  final Mission? daily;
  final Mission? weekly;
  final bool isLoading;
  final void Function(String id) onComplete;
  final void Function(String id) onCancel;

  const MissionCard({
    super.key,
    this.daily,
    this.weekly,
    this.isLoading = false,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '커플 미션',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading && daily == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              _MissionRow(
                label: '오늘의 미션',
                mission: daily,
                onComplete: onComplete,
                onCancel: onCancel,
              ),
              const SizedBox(height: 10),
              _MissionRow(
                label: '주간 미션',
                mission: weekly,
                onComplete: onComplete,
                onCancel: onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final String label;
  final Mission? mission;
  final void Function(String id) onComplete;
  final void Function(String id) onCancel;

  const _MissionRow({
    required this.label,
    this.mission,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (mission == null) {
      return Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
          ),
          const Spacer(),
          const Text(
            '불러오는 중...',
            style: TextStyle(fontSize: 12, color: AppTheme.textHint),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mission!.isCompleted
            ? const Color(0xFFF1F8E9)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: mission!.isCompleted
            ? Border.all(color: const Color(0xFF81C784), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Text(mission!.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: mission!.type == 'DAILY'
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : const Color(0xFF2196F3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: mission!.type == 'DAILY'
                              ? AppTheme.primaryColor
                              : const Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    if (mission!.isCompleted) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  mission!.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: mission!.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: mission!.isCompleted
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mission!.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!mission!.isCompleted)
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: () => onComplete(mission!.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '완료',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => onCancel(mission!.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '성공!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
