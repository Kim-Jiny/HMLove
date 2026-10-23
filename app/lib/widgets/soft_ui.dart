import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'cute/motion.dart';

/// 파스텔 틴트 배경 위에 아이콘을 올린 둥근 배지. 카드/리스트의 리딩 아이콘용.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 48,
  });

  /// 자주 쓰는 파스텔 조합.
  const IconBadge.rose(IconData icon, {Key? key, double size = 48})
    : this(
        key: key,
        icon: icon,
        color: AppTheme.primaryColor,
        background: AppTheme.primarySoft,
        size: size,
      );
  const IconBadge.lavender(IconData icon, {Key? key, double size = 48})
    : this(
        key: key,
        icon: icon,
        color: AppTheme.lavender,
        background: AppTheme.lavenderSoft,
        size: size,
      );
  const IconBadge.mint(IconData icon, {Key? key, double size = 48})
    : this(
        key: key,
        icon: icon,
        color: AppTheme.mint,
        background: AppTheme.mintSoft,
        size: size,
      );
  const IconBadge.peach(IconData icon, {Key? key, double size = 48})
    : this(
        key: key,
        icon: icon,
        color: AppTheme.peach,
        background: AppTheme.peachSoft,
        size: size,
      );
  const IconBadge.sky(IconData icon, {Key? key, double size = 48})
    : this(
        key: key,
        icon: icon,
        color: AppTheme.sky,
        background: AppTheme.skySoft,
        size: size,
      );
  const IconBadge.butter(IconData icon, {Key? key, double size = 48})
    : this(
        key: key,
        icon: icon,
        color: AppTheme.butter,
        background: AppTheme.butterSoft,
        size: size,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: AppTheme.ink, width: 1.4),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// 탭 가능한 카드 한 줄: [아이콘 배지] 제목 / 부제 ... 트레일링.
/// 홈의 미니 카드들이 같은 모양이라 공통화.
class SoftTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SoftTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Bouncy(
        onTap: onTap,
        pressedScale: 0.96,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      subtitle!,
                    ],
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textHint,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 기존 `Card(+InkWell)` 위젯에 카툰 그림자와 눌림 반응을 입힌다.
/// 카드의 탭 처리는 그대로 두고 그림자·여백·눌림 스케일만 담당한다.
class CartoonShadow extends StatelessWidget {
  final Widget child;
  const CartoonShadow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: PressScale(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd + 4),
            boxShadow: AppTheme.cartoonShadow,
          ),
          // 안쪽 Card 의 기본 마진은 이 위젯이 대신 가진다.
          child: Theme(
            data: theme.copyWith(
              cardTheme: theme.cardTheme.copyWith(margin: EdgeInsets.zero),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 앱 전체 카드의 기본형: 윤곽선 + 찍힌 그림자. `Card` 대신 쓴다.
/// [margin] 은 그림자 바깥 여백(기본 16/6)이라 Card 의 margin 과 같은 감각으로 쓰면 된다.
class CartoonCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry margin;
  final Clip clipBehavior;

  const CartoonCard({
    super.key,
    required this.child,
    this.color,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd + 4),
          boxShadow: AppTheme.cartoonShadow,
        ),
        child: Theme(
          data: theme.copyWith(
            cardTheme: theme.cardTheme.copyWith(margin: EdgeInsets.zero),
          ),
          child: Card(color: color, clipBehavior: clipBehavior, child: child),
        ),
      ),
    );
  }
}
