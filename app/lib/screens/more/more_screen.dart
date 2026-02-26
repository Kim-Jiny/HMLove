import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/inquiry_provider.dart';
import '../../providers/letter_provider.dart';
import 'inquiry_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_edit_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  void _showInviteCode(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.primaryColor, size: 24),
            SizedBox(width: 8),
            Text('초대 코드', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '아래 코드를 상대방에게 공유하세요.\n상대방이 코드를 입력하면 자동으로 연결됩니다.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      showTopSnackBar(ctx, '초대 코드가 복사되었습니다');
                    },
                    icon: const Icon(Icons.copy,
                        color: AppTheme.primaryColor, size: 20),
                    tooltip: '복사',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

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
            _InfoRow(label: '개발', value: '우리연애 팀'),
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

  void _openInquiry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InquiryScreen()),
    );
  }

  Future<void> _showDeleteAccount(BuildContext context, WidgetRef ref) async {
    // 1단계: 기본 확인
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('회원탈퇴'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 탈퇴하시겠습니까?\n\n탈퇴 시 다음 데이터가 모두 삭제됩니다:',
              style: TextStyle(height: 1.5),
            ),
            SizedBox(height: 12),
            _DeleteItem('프로필 정보'),
            _DeleteItem('채팅 메시지'),
            _DeleteItem('피드 및 댓글'),
            _DeleteItem('캘린더 일정'),
            _DeleteItem('사진'),
            _DeleteItem('편지'),
            _DeleteItem('기분 · 다툼 · 운세 기록'),
            SizedBox(height: 12),
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('다음', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (step1 != true || !context.mounted) return;

    // 2단계: "탈퇴" 입력 확인
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              '최종 확인',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '확인을 위해 아래에 "탈퇴"를 입력해주세요.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '탈퇴',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: controller.text.trim() == '탈퇴'
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('회원탈퇴'),
              ),
            ],
          ),
        );
      },
    );

    if (step2 != true || !context.mounted) return;

    // 실제 탈퇴 실행
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/auth/account');
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
        showTopSnackBar(context, '회원탈퇴가 완료되었습니다');
      }
    } catch (e) {
      if (context.mounted) {
        showTopSnackBar(context, '회원탈퇴에 실패했습니다', isError: true);
      }
    }
  }

  Future<void> _showLeaveCouple(BuildContext context, WidgetRef ref) async {
    // 서버에서 현재 커플 멤버 수 확인
    int memberCount = 2;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/couple/members');
      memberCount = (res.data as Map<String, dynamic>)['memberCount'] as int? ?? 2;
    } catch (_) {}

    final isLastMember = memberCount <= 1;

    if (!context.mounted) return;

    // 1단계: 기본 확인
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.heart_broken, color: Colors.red.shade400, size: 24),
            const SizedBox(width: 8),
            const Text('커플 해제'),
          ],
        ),
        content: Text(
          isLastMember
              ? '상대방이 이미 커플을 해제한 상태입니다.\n커플 해제 시 모든 데이터가 삭제됩니다.'
              : '커플 연결을 해제하시겠습니까?\n상대방은 해제 전까지 데이터를 볼 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '다음',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );

    if (step1 != true || !context.mounted) return;

    if (isLastMember) {
      // 2단계: 데이터 삭제 경고 (마지막 멤버일 때만)
      final step2 = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 8),
              Text('데이터 삭제 경고', style: TextStyle(color: Colors.red.shade700)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '다음 데이터가 모두 영구적으로 삭제됩니다:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              _DeleteItem('채팅 메시지'),
              _DeleteItem('피드 및 댓글'),
              _DeleteItem('캘린더 일정'),
              _DeleteItem('사진 및 포토맵'),
              _DeleteItem('편지'),
              _DeleteItem('기분 기록'),
              _DeleteItem('다툼 기록'),
              _DeleteItem('운세 기록'),
              SizedBox(height: 12),
              Text(
                '이 작업은 되돌릴 수 없습니다.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                '그래도 해제',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      );

      if (step2 != true || !context.mounted) return;

      // 3단계: 최종 확인 - "해제" 입력
      final step3 = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                '최종 확인',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '정말로 커플을 해제하고 모든 데이터를 삭제하시겠습니까?\n\n확인을 위해 아래에 "해제"를 입력해주세요.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '해제',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: controller.text.trim() == '해제'
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('커플 해제'),
                ),
              ],
            ),
          );
        },
      );

      if (step3 != true || !context.mounted) return;
    }

    // 실제 해제 실행
    final success = await ref.read(coupleProvider.notifier).leaveCouple();
    if (context.mounted) {
      if (success) {
        context.go('/couple-connect');
      } else {
        showTopSnackBar(context, '커플 해제에 실패했습니다', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final coupleState = ref.watch(coupleProvider);
    final unreadLetters = ref.watch(unreadLettersCountProvider);
    final unreadInquiries = ref.watch(unreadInquiryCountProvider);
    final partner = coupleState.couple?.getPartner(user?.id ?? '');

    // 화면 진입 시 미확인 문의 수 갱신
    ref.read(unreadInquiryCountProvider.notifier).fetch();

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

            // 상대방 없을 때 초대 코드
            if (partner == null && coupleState.couple != null) ...[
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add,
                            color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '상대방을 초대하세요',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '초대 코드를 공유하여 다시 연결하세요',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _showInviteCode(
                            context, coupleState.couple!.inviteCode),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text('코드 보기', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

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
                    badge: unreadLetters,
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
                    icon: Icons.help_outline,
                    title: '문의하기',
                    subtitle: '버그 신고 및 건의사항',
                    color: const Color(0xFF4CAF50),
                    badge: unreadInquiries,
                    onTap: () => _openInquiry(context),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.shield_outlined,
                    title: '개인정보처리방침',
                    subtitle: '개인정보 보호 정책 확인',
                    color: const Color(0xFF1976D2),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
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
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.person_off_outlined,
                    title: '회원탈퇴',
                    subtitle: '계정과 모든 데이터를 삭제합니다',
                    color: const Color(0xFF757575),
                    onTap: () => _showDeleteAccount(context, ref),
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
  final int badge;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                if (badge > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
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

// Delete confirmation item
class _DeleteItem extends StatelessWidget {
  final String text;
  const _DeleteItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.close, size: 14, color: Colors.red.shade300),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
