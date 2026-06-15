import 'package:flutter/material.dart';

import '../../../core/mood_emojis.dart';
import '../../../core/theme.dart';

// Mood Card
class MoodCard extends StatelessWidget {
  final String? myMoodEmoji;
  final String? partnerMoodEmoji;
  final String myName;
  final String partnerName;
  final VoidCallback onTap;

  const MoodCard({
    super.key,
    this.myMoodEmoji,
    this.partnerMoodEmoji,
    required this.myName,
    required this.partnerName,
    required this.onTap,
  });

  String _getMoodDisplay(String? emoji) {
    return moodEmojis[emoji] ?? '😶';
  }

  String _getMoodText(String? emoji) {
    return moodLabels[emoji] ?? '설정 안 됨';
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
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint),
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
