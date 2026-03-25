import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class GameResultBubble extends StatelessWidget {
  final String content;
  final bool isMe;

  const GameResultBubble({
    super.key,
    required this.content,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (content.startsWith('__GAME_ROULETTE__:')) {
      final json = content.substring('__GAME_ROULETTE__:'.length);
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return _RouletteBubble(data: data, isMe: isMe);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    if (content.startsWith('__GAME_LADDER__:')) {
      final json = content.substring('__GAME_LADDER__:'.length);
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return _LadderBubble(data: data, isMe: isMe);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }

  static bool isGameMessage(String content) {
    return content.startsWith('__GAME_ROULETTE__:') ||
        content.startsWith('__GAME_LADDER__:');
  }
}

class _RouletteBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;

  const _RouletteBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final options = (data['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final result = data['result'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? '';

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.casino, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  '룰렛 결과',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Options
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: options.map((opt) {
                final isWinner = opt == result;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWinner
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: isWinner
                        ? Border.all(color: AppTheme.primaryColor, width: 1)
                        : null,
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12,
                      color: isWinner
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                      fontWeight:
                          isWinner ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Result
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    result,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sender
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              '$senderName님이 돌린 룰렛',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LadderBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;

  const _LadderBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final players =
        (data['players'] as List<dynamic>?)?.cast<String>() ?? [];
    final resultMap =
        (data['result'] as Map<String, dynamic>?)?.cast<String, String>() ??
            {};
    final senderName = data['senderName'] as String? ?? '';

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.shuffle, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  '사다리타기 결과',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Result mapping
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Column(
              children: players.map((player) {
                final goal = resultMap[player] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          player,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: AppTheme.textHint),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            goal,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // Sender
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              '$senderName님이 만든 사다리',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
