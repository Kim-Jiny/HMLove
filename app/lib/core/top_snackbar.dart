import 'package:flutter/material.dart';
import 'theme.dart';

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
              color: isError ? AppTheme.errorColor : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.ink,
                width: AppTheme.outlineWidth,
              ),
              boxShadow: AppTheme.cartoonShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isError ? Colors.white : AppTheme.mintSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.ink, width: 1.2),
                  ),
                  child: Icon(
                    isError ? Icons.priority_high_rounded : Icons.check_rounded,
                    color: isError
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isError ? Colors.white : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
