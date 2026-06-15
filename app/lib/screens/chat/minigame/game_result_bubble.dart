import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class GameResultBubble extends StatelessWidget {
  final String content;
  final bool isMe;

  /// 실제 발신자 표시 이름. payload 안의 senderName 은 발신자 클라이언트가 임의로
  /// 넣은 값이라 위조 가능하므로, 메시지 메타데이터의 신뢰 가능한 이름을 쓴다.
  final String? senderName;

  const GameResultBubble({
    super.key,
    required this.content,
    required this.isMe,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    if (content.startsWith('__GAME_ROULETTE__:')) {
      final json = content.substring('__GAME_ROULETTE__:'.length);
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return _RouletteBubble(data: data, isMe: isMe, senderName: senderName);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    if (content.startsWith('__GAME_LADDER__:')) {
      final json = content.substring('__GAME_LADDER__:'.length);
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return _LadderBubble(data: data, isMe: isMe, senderName: senderName);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }

  /// 게임 메시지로 렌더할지 판단. prefix 뿐 아니라 payload 가 실제로 유효한 JSON
  /// object 여야 한다. 그래야 사용자가 `__GAME_..:잘못된내용` 을 입력해도 빈 위젯으로
  /// 사라지지 않고 일반 텍스트로 렌더된다.
  static bool isGameMessage(String content) {
    String? json;
    if (content.startsWith('__GAME_ROULETTE__:')) {
      json = content.substring('__GAME_ROULETTE__:'.length);
    } else if (content.startsWith('__GAME_LADDER__:')) {
      json = content.substring('__GAME_LADDER__:'.length);
    }
    if (json == null) return false;
    try {
      return jsonDecode(json) is Map;
    } catch (_) {
      return false;
    }
  }
}

class _RouletteBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final String? senderName;

  const _RouletteBubble({required this.data, required this.isMe, this.senderName});

  @override
  Widget build(BuildContext context) {
    // 타입이 어긋난 payload(예: options 가 String)에서도 캐스트 throw 로 메시지
    // 목록 전체가 크래시하지 않도록 방어적으로 읽는다.
    final rawOptions = data['options'];
    final options =
        rawOptions is List ? rawOptions.whereType<String>().toList() : <String>[];
    final result = data['result'] is String ? data['result'] as String : '';
    // 신뢰 가능한 발신자명 우선, 없으면 payload 값 폴백.
    final senderName = this.senderName ??
        (data['senderName'] is String ? data['senderName'] as String : '');

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
  final String? senderName;

  const _LadderBubble({required this.data, required this.isMe, this.senderName});

  @override
  Widget build(BuildContext context) {
    // 방어적 읽기 — 타입 어긋난 payload 에서도 크래시하지 않도록.
    final rawPlayers = data['players'];
    final players =
        rawPlayers is List ? rawPlayers.whereType<String>().toList() : <String>[];
    final rawResult = data['result'];
    final resultMap = <String, String>{
      if (rawResult is Map)
        for (final e in rawResult.entries) '${e.key}': '${e.value}',
    };
    final senderName = this.senderName ??
        (data['senderName'] is String ? data['senderName'] as String : '');

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
