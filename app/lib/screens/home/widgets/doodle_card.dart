import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/doodle.dart';

// Doodle Card — 받은 그림 미리보기 + 그림 보내기 진입
class DoodleCard extends StatelessWidget {
  final Doodle? latest;
  final VoidCallback onTap;

  const DoodleCard({super.key, required this.latest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasLatest = latest != null;
    final subtitle = hasLatest
        ? '${latest!.senderNickname.isEmpty ? "상대방" : latest!.senderNickname}이(가) 보낸 그림이 도착했어요'
        : '그림을 그려서 상대방 위젯으로 보내보세요';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF1E6DF)),
          ),
          child: Row(
            children: [
              if (hasLatest)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.network(
                      latest!.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFFFF1EA),
                        child: const Icon(
                          Icons.brush_rounded,
                          color: Color(0xFFE07A5F),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.brush_rounded,
                    color: Color(0xFFE07A5F),
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '그림 보내기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
