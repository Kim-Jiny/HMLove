import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../providers/couple_provider.dart';

class LadderScreen extends ConsumerStatefulWidget {
  const LadderScreen({super.key});

  @override
  ConsumerState<LadderScreen> createState() => _LadderScreenState();
}

enum _LadderPhase { setup, running, result }

class _LadderScreenState extends ConsumerState<LadderScreen>
    with SingleTickerProviderStateMixin {
  List<TextEditingController> _playerControllers = [];
  List<TextEditingController> _goalControllers = [];

  late AnimationController _animController;
  _LadderPhase _phase = _LadderPhase.setup;

  // Ladder data
  List<String> _players = [];
  List<String> _goals = [];
  List<List<int>> _rungs = []; // rungs[row] = list of col indices with a rung to the right
  Map<String, String> _resultMap = {};

  // Paths for animation: paths[playerIndex] = list of Offsets
  List<List<Offset>> _paths = [];
  int _playerCount = 2;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _initControllers();
  }

  void _initControllers() {
    final currentUserId = ApiClient.getUserId() ?? '';
    final couple = ref.read(coupleProvider).couple;
    final myName = couple?.users
            .where((u) => u.id == currentUserId)
            .firstOrNull
            ?.nickname ??
        '';
    final partnerName = couple?.getPartner(currentUserId)?.nickname ?? '';

    _playerControllers = [
      TextEditingController(text: myName),
      TextEditingController(text: partnerName),
    ];
    _goalControllers = [
      TextEditingController(text: ''),
      TextEditingController(text: ''),
    ];
  }

  @override
  void dispose() {
    for (final c in _playerControllers) {
      c.dispose();
    }
    for (final c in _goalControllers) {
      c.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  void _addPlayer() {
    if (_playerCount >= 8) return;
    setState(() {
      _playerControllers.add(TextEditingController());
      _goalControllers.add(TextEditingController());
      _playerCount++;
    });
  }

  void _removePlayer(int index) {
    if (_playerCount <= 2) return;
    setState(() {
      _playerControllers[index].dispose();
      _playerControllers.removeAt(index);
      _goalControllers[index].dispose();
      _goalControllers.removeAt(index);
      _playerCount--;
    });
  }

  bool _canStart() {
    final players = _playerControllers.map((c) => c.text.trim()).toList();
    final goals = _goalControllers.map((c) => c.text.trim()).toList();
    return players.every((s) => s.isNotEmpty) &&
        goals.every((s) => s.isNotEmpty);
  }

  void _confirmAndStart() {
    if (!_canStart()) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사다리타기'),
        content: const Text('결과가 바로 채팅방에 전송됩니다.\n시작하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _start();
            },
            child: const Text('시작'),
          ),
        ],
      ),
    );
  }

  void _start() {
    if (!_canStart()) return;

    _players = _playerControllers.map((c) => c.text.trim()).toList();
    _goals = _goalControllers.map((c) => c.text.trim()).toList();

    _generateLadder();
    _computePaths();

    setState(() => _phase = _LadderPhase.running);
    _animController.reset();
    _animController.forward().then((_) {
      if (mounted) {
        setState(() => _phase = _LadderPhase.result);
        _sendResult();
      }
    });
  }

  void _generateLadder() {
    final rng = Random();
    final numCols = _players.length;
    final numRows = 6 + rng.nextInt(3); // 6-8 rows of rungs
    _rungs = [];

    for (int row = 0; row < numRows; row++) {
      final rowRungs = <int>[];
      for (int col = 0; col < numCols - 1; col++) {
        // Don't put adjacent rungs on same row
        if (rowRungs.isNotEmpty && rowRungs.last == col - 1) continue;
        if (rng.nextDouble() < 0.45) {
          rowRungs.add(col);
        }
      }
      _rungs.add(rowRungs);
    }

    // Ensure every column has at least one rung
    for (int col = 0; col < numCols - 1; col++) {
      final hasRung = _rungs.any((row) => row.contains(col));
      if (!hasRung) {
        final row = rng.nextInt(_rungs.length);
        _rungs[row].add(col);
        _rungs[row].sort();
      }
    }
  }

  void _computePaths() {
    final numCols = _players.length;
    final numRows = _rungs.length;
    _paths = [];
    _resultMap = {};

    for (int startCol = 0; startCol < numCols; startCol++) {
      int col = startCol;
      final path = <Offset>[Offset(col.toDouble(), -1)]; // start above

      for (int row = 0; row < numRows; row++) {
        path.add(Offset(col.toDouble(), row.toDouble()));

        // Check if there's a rung to the right at this row
        if (_rungs[row].contains(col)) {
          col++;
          path.add(Offset(col.toDouble(), row.toDouble()));
        }
        // Check if there's a rung to the left
        else if (col > 0 && _rungs[row].contains(col - 1)) {
          col--;
          path.add(Offset(col.toDouble(), row.toDouble()));
        }
      }

      path.add(Offset(col.toDouble(), numRows.toDouble())); // end below
      _paths.add(path);
      _resultMap[_players[startCol]] = _goals[col];
    }
  }

  void _sendResult() {
    final payload = jsonEncode({
      'players': _players,
      'goals': _goals,
      'result': _resultMap,
    });
    Navigator.pop(context, '__GAME_LADDER__:$payload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사다리타기')),
      body: _phase == _LadderPhase.setup ? _buildSetup() : _buildLadder(),
    );
  }

  Widget _buildSetup() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '참가자와 목표를 입력하세요 (2~8명)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...List.generate(_playerCount, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _ladderColors[i % _ladderColors.length],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _playerControllers[i],
                          decoration: InputDecoration(
                            hintText: '참가자 ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _goalControllers[i],
                          decoration: InputDecoration(
                            hintText: '목표 ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_playerCount > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 22),
                          onPressed: () => _removePlayer(i),
                        ),
                    ],
                  ),
                );
              }),
              if (_playerCount < 8)
                TextButton.icon(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.add),
                  label: const Text('참가자 추가'),
                ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canStart() ? _confirmAndStart : null,
                child: const Text('시작!'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const _ladderColors = [
    Color(0xFFE91E63),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF607D8B),
  ];

  Widget _buildLadder() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _LadderPainter(
                    players: _players,
                    goals: _goals,
                    rungs: _rungs,
                    paths: _paths,
                    progress: _animController.value,
                    colors: _ladderColors,
                    showResult: _phase == _LadderPhase.result,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
        ),
        if (_phase == _LadderPhase.result)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: _resultMap.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${e.key}  →  ${e.value}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LadderPainter extends CustomPainter {
  final List<String> players;
  final List<String> goals;
  final List<List<int>> rungs;
  final List<List<Offset>> paths;
  final double progress;
  final List<Color> colors;
  final bool showResult;

  _LadderPainter({
    required this.players,
    required this.goals,
    required this.rungs,
    required this.paths,
    required this.progress,
    required this.colors,
    required this.showResult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final numCols = players.length;
    final numRows = rungs.length;

    final topPadding = 36.0;
    final bottomPadding = 36.0;
    final leftPadding = 20.0;
    final rightPadding = 20.0;

    final drawWidth = size.width - leftPadding - rightPadding;
    final drawHeight = size.height - topPadding - bottomPadding;

    final colSpacing = numCols > 1 ? drawWidth / (numCols - 1) : drawWidth;
    final rowSpacing = numRows > 0 ? drawHeight / (numRows + 1) : drawHeight;

    Offset gridToCanvas(double col, double row) {
      return Offset(
        leftPadding + col * colSpacing,
        topPadding + (row + 1) * rowSpacing,
      );
    }

    // Draw vertical lines
    final vertPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int col = 0; col < numCols; col++) {
      final top = Offset(leftPadding + col * colSpacing, topPadding);
      final bottom =
          Offset(leftPadding + col * colSpacing, size.height - bottomPadding);
      canvas.drawLine(top, bottom, vertPaint);
    }

    // Draw horizontal rungs
    final rungPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int row = 0; row < numRows; row++) {
      for (final col in rungs[row]) {
        final left = gridToCanvas(col.toDouble(), row.toDouble());
        final right = gridToCanvas((col + 1).toDouble(), row.toDouble());
        canvas.drawLine(left, right, rungPaint);
      }
    }

    // Draw player names (top)
    for (int i = 0; i < numCols; i++) {
      final x = leftPadding + i * colSpacing;
      _drawText(canvas, players[i], Offset(x, topPadding - 10),
          colors[i % colors.length],
          fontSize: 13, above: true);
    }

    // Draw goals (bottom)
    for (int i = 0; i < numCols; i++) {
      final x = leftPadding + i * colSpacing;
      _drawText(
          canvas, goals[i], Offset(x, size.height - bottomPadding + 10),
          Colors.grey.shade700,
          fontSize: 12, above: false);
    }

    // Draw animated paths
    for (int p = 0; p < paths.length; p++) {
      final path = paths[p];
      final color = colors[p % colors.length];
      final pathPaint = Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Convert path points to canvas coordinates
      final canvasPoints = path.map((pt) {
        return gridToCanvas(pt.dx, pt.dy);
      }).toList();

      // Calculate total path length
      double totalLen = 0;
      for (int i = 1; i < canvasPoints.length; i++) {
        totalLen += (canvasPoints[i] - canvasPoints[i - 1]).distance;
      }

      final drawLen = totalLen * progress;
      double accumulated = 0;
      final drawPath = Path();
      drawPath.moveTo(canvasPoints[0].dx, canvasPoints[0].dy);

      for (int i = 1; i < canvasPoints.length; i++) {
        final segLen = (canvasPoints[i] - canvasPoints[i - 1]).distance;
        if (accumulated + segLen <= drawLen) {
          drawPath.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
          accumulated += segLen;
        } else {
          final remain = drawLen - accumulated;
          final frac = remain / segLen;
          final mid = Offset.lerp(canvasPoints[i - 1], canvasPoints[i], frac)!;
          drawPath.lineTo(mid.dx, mid.dy);

          // Draw dot at current position
          canvas.drawCircle(mid, 5, Paint()..color = color);
          break;
        }
      }

      canvas.drawPath(drawPath, pathPaint);

      // If complete, draw dot at end
      if (progress >= 1.0) {
        canvas.drawCircle(canvasPoints.last, 5, Paint()..color = color);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color,
      {double fontSize = 13, bool above = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);

    tp.paint(
      canvas,
      Offset(
        position.dx - tp.width / 2,
        above ? position.dy - tp.height : position.dy,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _LadderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.showResult != showResult;
  }
}
