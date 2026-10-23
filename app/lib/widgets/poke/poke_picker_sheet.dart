import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/poke.dart';
import '../cute/mood_face.dart';
import '../cute/motion.dart';

/// 길게 눌렀을 때 뜨는 콕 스티커 선택 시트. 고른 종류를 돌려준다.
Future<PokeKind?> showPokePickerSheet(BuildContext context) {
  return showModalBottomSheet<PokeKind>(
    context: context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '어떤 마음을 보낼까요?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '고르면 바로 상대에게 콕이 가요',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final e in PokeKind.values.indexed)
                  FadeSlideIn(
                    index: e.$1 ~/ 3,
                    child: Bouncy(
                      pressedScale: 0.88,
                      onTap: () => Navigator.pop(context, e.$2),
                      child: SizedBox(
                        width: 92,
                        child: Column(
                          children: [
                            MoodFace(moodKey: e.$2.moodKey, size: 64),
                            const SizedBox(height: 8),
                            Text(
                              e.$2.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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
