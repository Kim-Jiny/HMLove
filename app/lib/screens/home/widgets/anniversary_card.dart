import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';

// Next Anniversary Card
class AnniversaryCard extends StatelessWidget {
  final DateTime? startDate;
  final VoidCallback? onTap;

  const AnniversaryCard({super.key, this.startDate, this.onTap});

  Map<String, dynamic>? _getNextAnniversary() {
    if (startDate == null) return null;

    final today = DateUtils.dateOnly(DateTime.now());
    final start = DateUtils.dateOnly(startDate!);
    final milestones = [
      50,
      100,
      200,
      300,
      365,
      500,
      700,
      730,
      1000,
      1095,
      1461,
    ];

    for (final days in milestones) {
      final date = start.add(Duration(days: days - 1));
      if (date.isAfter(today)) {
        final daysLeft = date.difference(today).inDays;
        return {'name': '$days일', 'date': date, 'daysLeft': daysLeft};
      }
    }

    // Annual anniversary
    int year = today.year - start.year;
    if (DateTime(today.year, start.month, start.day).isBefore(today)) {
      year++;
    }
    final nextAnniv = DateTime(start.year + year, start.month, start.day);
    return {
      'name': '$year주년',
      'date': nextAnniv,
      'daysLeft': nextAnniv.difference(today).inDays,
    };
  }

  @override
  Widget build(BuildContext context) {
    final anniversary = _getNextAnniversary();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                      DateFormat(
                        'M월 d일',
                      ).format(anniversary['date'] as DateTime),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
