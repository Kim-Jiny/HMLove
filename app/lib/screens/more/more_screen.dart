import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import 'notification_settings_screen.dart';
import 'profile_edit_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('우리연애', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: '버전', value: '1.0.0'),
            SizedBox(height: 8),
            _InfoRow(label: '개발', value: 'HMLove Team'),
            SizedBox(height: 16),
            Text(
              '커플을 위한 올인원 앱\n함께하는 모든 순간을 기록하세요.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showLeaveCouple(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('커플 해제'),
        content: const Text(
          '정말 커플을 해제하시겠습니까?\n모든 공유 데이터가 사라질 수 있습니다.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await ref.read(coupleProvider.notifier).leaveCouple();
              if (success && context.mounted) {
                context.go('/couple-connect');
              }
            },
            child: const Text(
              '해제',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final coupleState = ref.watch(coupleProvider);
    final partner = coupleState.couple?.getPartner(user?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('더보기'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            AppTheme.primaryLight.withValues(alpha: 0.3),
                        backgroundImage: user?.profileImage != null
                            ? NetworkImage(user!.profileImage!)
                            : null,
                        child: user?.profileImage == null
                            ? Text(
                                user?.nickname.isNotEmpty == true
                                    ? user!.nickname[0]
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.nickname ?? '사용자',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (partner != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.favorite,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    partner.nickname,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Couple Features
            const _SectionTitle(title: '커플 기능'),
            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.celebration_outlined,
                    title: '기념일',
                    subtitle: '기념일을 확인하고 추가하세요',
                    color: const Color(0xFFE91E63),
                    onTap: () => context.push('/anniversary'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.map_outlined,
                    title: '포토 맵',
                    subtitle: '사진으로 채우는 우리의 지도',
                    color: const Color(0xFF4CAF50),
                    onTap: () => context.push('/photo-map'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.local_fire_department_outlined,
                    title: '다툼 기록',
                    subtitle: '다툼을 기록하고 함께 성장해요',
                    color: const Color(0xFFFF5722),
                    onTap: () => context.push('/fight'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.mail_outline,
                    title: '편지함',
                    subtitle: '주고받은 편지를 모아보세요',
                    color: const Color(0xFFFF9800),
                    onTap: () => context.push('/letter'),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.auto_awesome,
                    title: '오늘의 운세',
                    subtitle: '커플 운세를 확인하세요',
                    color: const Color(0xFF9C27B0),
                    onTap: () => context.push('/fortune'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Settings
            const _SectionTitle(title: '설정'),
            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.notifications_outlined,
                    title: '알림 설정',
                    subtitle: '알림을 관리하세요',
                    color: const Color(0xFF2196F3),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.info_outline,
                    title: '앱 정보',
                    subtitle: 'v1.0.0',
                    color: const Color(0xFF607D8B),
                    onTap: () => _showAppInfo(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account
            const _SectionTitle(title: '계정'),
            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.heart_broken_outlined,
                    title: '커플 해제',
                    subtitle: '커플 연결을 해제합니다',
                    color: const Color(0xFFE53935),
                    onTap: () => _showLeaveCouple(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('로그아웃'),
                      content: const Text('정말 로그아웃하시겠습니까?'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            '로그아웃',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
                icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                label: const Text(
                  '로그아웃',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// Section Title
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Info Row for App Info Dialog
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Menu Tile Widget
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
