import 'dart:async';

import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// 알림 타입별 아이콘/색상 매핑
const _typeConfig = <String, ({IconData icon, Color color})>{
  'chat': (icon: Icons.chat_bubble, color: Color(0xFF2196F3)),
  'feed': (icon: Icons.photo, color: Color(0xFF4CAF50)),
  'feed_like': (icon: Icons.favorite, color: Color(0xFFE91E63)),
  'feed_comment': (icon: Icons.comment, color: Color(0xFF4CAF50)),
  'calendar': (icon: Icons.calendar_today, color: Color(0xFFFF9800)),
  'anniversary': (icon: Icons.cake, color: Color(0xFFE91E63)),
  'letter': (icon: Icons.mail, color: Color(0xFF9C27B0)),
  'mood': (icon: Icons.emoji_emotions, color: Color(0xFFFF5722)),
  'fight': (icon: Icons.thunderstorm, color: Color(0xFF607D8B)),
};

OverlayEntry? _currentEntry;
AnimationController? _currentController;
Timer? _dismissTimer;

/// 카톡 스타일 인앱 알림 배너 표시
void showInAppNotification({
  required String title,
  required String body,
  required String type,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 3),
}) {
  try {
    // 이전 배너 즉시 제거
    _dismiss(immediate: true);

    // NavigatorState에서 직접 overlay 가져오기 (Overlay.of보다 안정적)
    final navigatorState = rootNavigatorKey.currentState;
    if (navigatorState == null) {
      debugPrint('[InApp] No navigator state');
      return;
    }

    final overlay = navigatorState.overlay;
    if (overlay == null) {
      debugPrint('[InApp] No overlay found');
      return;
    }

    final controller = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 300),
    );
    _currentController = controller;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final config = _typeConfig[type] ??
        (icon: Icons.notifications, color: AppTheme.primaryColor);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final offset = (animation.value - 1) * 80;
              return Transform.translate(
                offset: Offset(0, offset),
                child: Opacity(
                  opacity: animation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                _dismiss();
                onTap?.call();
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -5) {
                  _dismiss();
                }
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.only(
                    top: topPadding + 8,
                    left: 12,
                    right: 12,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(config.icon, color: config.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              body,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '지금',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
    controller.forward();

    _dismissTimer = Timer(duration, () => _dismiss());

    debugPrint('[InApp] Banner shown — title: $title, type: $type');
  } catch (e) {
    debugPrint('[InApp] Error showing banner: $e');
  }
}

void _dismiss({bool immediate = false}) {
  _dismissTimer?.cancel();
  _dismissTimer = null;

  final entry = _currentEntry;
  final controller = _currentController;
  if (entry == null || controller == null) return;

  _currentEntry = null;
  _currentController = null;

  if (immediate || !controller.isAnimating && controller.status != AnimationStatus.completed) {
    try {
      entry.remove();
    } catch (_) {}
    controller.dispose();
    return;
  }

  controller.reverse().then((_) {
    try {
      entry.remove();
    } catch (_) {}
    controller.dispose();
  });
}
