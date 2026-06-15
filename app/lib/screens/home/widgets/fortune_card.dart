import 'package:flutter/material.dart';

import '../../../core/theme.dart';

// Today's Fortune Card
class FortuneCard extends StatelessWidget {
  final int? luckyScore;
  final String? coupleLuck;
  final bool isLoading;
  final bool? exists;
  final VoidCallback onTap;

  const FortuneCard({
    super.key,
    this.luckyScore,
    this.coupleLuck,
    this.isLoading = false,
    this.exists,
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
                child: const Icon(Icons.auto_awesome, color: Color(0xFFFF9800)),
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
                    else if (exists == false)
                      const Text(
                        '광고를 보고 오늘의 운세를 확인하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9C27B0),
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
              const Icon(Icons.chevron_right, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
