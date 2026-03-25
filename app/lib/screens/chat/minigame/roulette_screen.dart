import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

enum _RoulettePhase { setup, spinning, result }

class _RouletteScreenState extends State<RouletteScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = [
    TextEditingController(text: '옵션 1'),
    TextEditingController(text: '옵션 2'),
  ];

  late AnimationController _animController;
  Animation<double>? _animation;

  _RoulettePhase _phase = _RoulettePhase.setup;
  int _resultIndex = 0;
  List<String> _spinOptions = []; // spin 시점의 옵션 스냅샷

  static const _colors = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF03A9F4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  void _addOption() {
    if (_controllers.length >= 8) return;
    setState(() {
      _controllers
          .add(TextEditingController(text: '옵션 ${_controllers.length + 1}'));
    });
  }

  void _removeOption(int index) {
    if (_controllers.length <= 2) return;
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  List<String> _getOptions() {
    return _controllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _confirmAndSpin() {
    final options = _getOptions();
    if (options.length < 2) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('룰렛 돌리기'),
        content: const Text('결과가 바로 채팅방에 전송됩니다.\n돌리시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _spin();
            },
            child: const Text('돌리기'),
          ),
        ],
      ),
    );
  }

  void _spin() {
    _spinOptions = _getOptions();
    if (_spinOptions.length < 2) return;

    final rng = Random();
    _resultIndex = rng.nextInt(_spinOptions.length);

    final sectorAngle = 2 * pi / _spinOptions.length;
    // 화살표는 12시 방향(= -pi/2). 섹터 i 중심을 거기에 맞춤.
    final targetAngle =
        (-pi / 2 - (_resultIndex * sectorAngle + sectorAngle / 2)) +
            6 * 2 * pi; // 6바퀴 + 정확한 위치

    _animation = Tween<double>(begin: 0, end: targetAngle).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    setState(() => _phase = _RoulettePhase.spinning);
    _animController.reset();
    _animController.forward().then((_) {
      if (mounted) {
        setState(() => _phase = _RoulettePhase.result);
        _sendResult();
      }
    });
  }

  void _sendResult() {
    final result = _spinOptions[_resultIndex];
    final payload = jsonEncode({
      'options': _spinOptions,
      'result': result,
    });
    Navigator.pop(context, '__GAME_ROULETTE__:$payload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('룰렛돌리기')),
      body: _phase == _RoulettePhase.setup ? _buildSetup() : _buildWheel(),
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
                '옵션을 입력하세요 (2~8개)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...List.generate(_controllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controllers[i],
                          decoration: InputDecoration(
                            hintText: '옵션 ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (_controllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red, size: 22),
                          onPressed: () => _removeOption(i),
                        ),
                    ],
                  ),
                );
              }),
              if (_controllers.length < 8)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add),
                  label: const Text('옵션 추가'),
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
                onPressed: _getOptions().length >= 2 ? _confirmAndSpin : null,
                child: const Text('돌리기!'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheel() {
    final options = _spinOptions;
    final result = options[_resultIndex];

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arrow
                  const Icon(Icons.arrow_drop_down,
                      size: 40, color: AppTheme.primaryColor),
                  // Wheel
                  AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _WheelPainter(
                            options: options,
                            colors: _colors,
                            rotation: _animation?.value ?? 0,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_phase == _RoulettePhase.result) ...[
                    const Text('결과는...',
                        style: TextStyle(
                            fontSize: 14, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      result,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> options;
  final List<Color> colors;
  final double rotation;

  _WheelPainter({
    required this.options,
    required this.colors,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sectorAngle = 2 * pi / options.length;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (int i = 0; i < options.length; i++) {
      final startAngle = i * sectorAngle;
      final paint = Paint()..color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectorAngle,
        true,
        paint,
      );

      // Draw border between sectors
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sectorAngle,
        true,
        borderPaint,
      );

      // Draw text
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sectorAngle / 2);
      final textPainter = TextPainter(
        text: TextSpan(
          text: options[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius * 0.6);
      textPainter.paint(
        canvas,
        Offset(radius * 0.3, -textPainter.height / 2),
      );
      canvas.restore();
    }

    canvas.restore();

    // Center circle
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

