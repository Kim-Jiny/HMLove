import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/cute/motion.dart';

/// 하단 바 한 칸.
class NavEntry {
  final int branch;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badge;

  const NavEntry({
    required this.branch,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });
}

/// 카툰풍 하단 바. [entries] 를 같은 폭으로 나란히 놓는다.
class CuteNavBar extends StatelessWidget {
  final List<NavEntry> entries;
  final int selectedBranch;
  final ValueChanged<int> onSelect;

  const CuteNavBar({
    super.key,
    required this.entries,
    required this.selectedBranch,
    required this.onSelect,
  });

  static const _barHeight = 66.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: _barHeight + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.ink, width: AppTheme.outlineWidth),
        ),
      ),
      child: Row(
        children: [
          for (final e in entries)
            Expanded(
              child: _NavItem(
                entry: e,
                selected: e.branch == selectedBranch,
                onTap: () => onSelect(e.branch),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? entry.activeIcon : entry.icon,
      size: 23,
      color: selected ? AppTheme.primaryColor : AppTheme.textHint,
    );
    return Bouncy(
      onTap: onTap,
      pressedScale: 0.88,
      haptic: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 50,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTheme.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? AppTheme.ink : Colors.transparent,
                width: 1.3,
              ),
            ),
            child: AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              child: entry.badge > 0
                  ? Badge(
                      label: Text(
                        entry.badge > 99 ? '99+' : '${entry.badge}',
                        style: const TextStyle(fontSize: 9),
                      ),
                      backgroundColor: AppTheme.primaryColor,
                      child: icon,
                    )
                  : icon,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            entry.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppTheme.primaryColor : AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
