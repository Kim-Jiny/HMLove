import 'package:flutter/material.dart';

/// Shows a top snackbar notification below the status bar.
void showTopSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  final controller = AnimationController(
    vsync: overlay,
    duration: const Duration(milliseconds: 300),
  );

  final animation = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  entry = OverlayEntry(
    builder: (context) {
      final topPadding = MediaQuery.of(context).padding.top;
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Positioned(
          top: topPadding + 8 + (animation.value - 1) * 60,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF323232),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  controller.forward();

  Future.delayed(duration, () {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  });
}
