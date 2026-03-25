import 'package:flutter/material.dart';

enum MiniGameType { roulette, ladder }

class MinigameSelectSheet extends StatelessWidget {
  const MinigameSelectSheet({super.key});

  static Future<MiniGameType?> show(BuildContext context) {
    return showModalBottomSheet<MiniGameType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const MinigameSelectSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '미니게임',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.casino, color: Color(0xFF9C27B0)),
            ),
            title: const Text('룰렛돌리기'),
            subtitle: const Text('옵션을 넣고 랜덤으로 결정!',
                style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, MiniGameType.roulette),
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shuffle, color: Color(0xFF1565C0)),
            ),
            title: const Text('사다리타기'),
            subtitle: const Text('참가자와 목표를 매칭!',
                style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(context, MiniGameType.ladder),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
