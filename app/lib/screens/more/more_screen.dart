import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/session_reset.dart';
import '../../providers/inquiry_provider.dart';
import '../../providers/letter_provider.dart';
import '../couple/invite_code_dialog.dart';
import '../../widgets/cute/profile_avatar.dart';
import '../../widgets/soft_ui.dart';
import '../../widgets/cute/sticker.dart';
import '../../widgets/cute/mood_face.dart';
import '../../widgets/cute/motion.dart';
import 'inquiry_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_edit_screen.dart';
import 'social_link_screen.dart';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version}+${info.buildNumber}';
});

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 미확인 문의 수 갱신 (빌드마다가 아닌 1회만)
    Future.microtask(() {
      ref.read(unreadInquiryCountProvider.notifier).fetch();
    });
  }

  Future<void> _editPartnerName(BuildContext context, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('상대방 이름/애칭'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(hintText: '예: 자기, 지수'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (name == null || !context.mounted) return;
      final ok = await ref
          .read(coupleProvider.notifier)
          .updatePartnerName(name);
      if (context.mounted) {
        showTopSnackBar(context, ok ? '저장되었습니다' : '저장에 실패했습니다', isError: !ok);
      }
    } finally {
      controller.dispose();
    }
  }

  void _showAppInfo(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';
    if (!context.mounted) return;
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: '버전', value: version),
            const SizedBox(height: 8),
            const _InfoRow(label: '개발', value: '지니'),
            const SizedBox(height: 16),
            const Text(
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
            _DeleteItem('위시리스트 · 질문 기록'),
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
    final controller = TextEditingController();
    final bool? step2;
    try {
      step2 = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '최종 확인',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
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
    } finally {
      controller.dispose();
    }

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
      memberCount =
          (res.data as Map<String, dynamic>)['memberCount'] as int? ?? 2;
    } catch (_) {}

    final isLastMember = memberCount <= 1;
    final isSolo = ref.read(currentUserProvider)?.isSolo ?? false;

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
          isSolo
              ? '아직 상대방이 연결되지 않았어요.\n해제하면 그동안 남긴 모든 기록이 삭제됩니다.'
              : isLastMember
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
            child: Text('다음', style: TextStyle(color: Colors.red.shade400)),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
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
              _DeleteItem('위시리스트'),
              _DeleteItem('질문 기록'),
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
      final controller = TextEditingController();
      final bool? step3;
      try {
        step3 = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setState) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  '최종 확인',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
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
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('커플 해제'),
                  ),
                ],
              ),
            );
          },
        );
      } finally {
        controller.dispose();
      }

      if (step3 != true || !context.mounted) return;
    }

    // 실제 해제 실행
    final success = await ref.read(coupleProvider.notifier).leaveCouple();
    if (context.mounted) {
      if (success) {
        // 커플 해제 시 이전 커플의 피드·사진·캘린더 등 잔존 데이터 초기화
        resetFeatureProviders(ref);
        context.go('/couple-connect');
      } else {
        showTopSnackBar(context, '커플 해제에 실패했습니다', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final coupleState = ref.watch(coupleProvider);
    final unreadLetters = ref.watch(unreadLettersCountProvider);
    final unreadInquiries = ref.watch(unreadInquiryCountProvider);
    final partner = coupleState.couple?.getPartner(user?.id ?? '');
    final isSolo = ref.watch(isSoloProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            CartoonShadow(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFEEF3), Color(0xFFF3F0FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          imageUrl: user?.profileImage,
                          seed: user?.id ?? user?.nickname ?? '',
                          size: 68,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nickname ?? '사용자',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _RelationChip(
                                partnerName: coupleState.couple
                                    ?.partnerDisplayName(
                                      user?.id ?? '',
                                      fallback: '',
                                    ),
                                connected: partner != null,
                                daysTogether: ref.watch(daysSinceStartProvider),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 상대방 없을 때 초대 코드
            if (partner == null && coupleState.couple != null) ...[
              CartoonCard(
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
                        child: const Icon(
                          Icons.person_add,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '상대방을 초대하세요',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSolo
                                  ? '초대 코드로 연결하면 먼저 남긴 기록을 함께 봐요'
                                  : '초대 코드를 공유하여 다시 연결하세요',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (isSolo) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _editPartnerName(
                                  context,
                                  coupleState.couple?.pendingPartnerName,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '상대 이름: ${coupleState.couple?.pendingPartnerName ?? '미설정'}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.edit_rounded,
                                      size: 13,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => showInviteCodeDialog(
                          context,
                          coupleState.couple!.inviteCode,
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          '코드 보기',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 기능 그리드
            const _SectionTitle(title: '우리의 기능'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              children: [
                _GridTile(
                  label: '기념일',
                  background: AppTheme.primarySoft,
                  icon: const Icon(
                    Icons.celebration_rounded,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                  onTap: () => context.push('/anniversary'),
                ),
                _GridTile(
                  label: '편지함',
                  background: AppTheme.lavenderSoft,
                  badge: unreadLetters,
                  icon: const Sticker(StickerKind.gift, size: 34),
                  onTap: () => context.push('/letter'),
                ),
                _GridTile(
                  label: '위시리스트',
                  background: AppTheme.peachSoft,
                  icon: const Sticker(StickerKind.heart, size: 32),
                  onTap: () => context.push('/wishlist'),
                ),
                _GridTile(
                  label: '오늘의 질문',
                  background: AppTheme.skySoft,
                  icon: const Icon(
                    Icons.quiz_rounded,
                    color: AppTheme.sky,
                    size: 30,
                  ),
                  onTap: () => context.push('/question'),
                ),
                _GridTile(
                  label: '오늘의 운세',
                  background: AppTheme.butterSoft,
                  icon: const Sticker(StickerKind.sparkle, size: 34),
                  onTap: () => context.push('/fortune'),
                ),
                _GridTile(
                  label: '다툼 기록',
                  background: AppTheme.mintSoft,
                  icon: const MoodFace(moodKey: 'angry', size: 38),
                  onTap: () => context.push('/fight'),
                ),
                _GridTile(
                  label: '포토맵',
                  background: AppTheme.primarySoft,
                  icon: const Sticker(StickerKind.pin, size: 32),
                  onTap: () => context.push('/photo-map'),
                ),
                if (!isSolo)
                  _GridTile(
                    label: '그림 보내기',
                    background: AppTheme.mintSoft,
                    icon: const Icon(
                      Icons.brush_rounded,
                      color: AppTheme.mint,
                      size: 30,
                    ),
                    onTap: () => context.push('/doodle'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Banner Ad
            BannerAdWidget(adUnitId: AppConstants.adMobMoreBanner),
            const SizedBox(height: 16),

            // Settings
            const _SectionTitle(title: '설정'),
            CartoonCard(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.notifications_outlined,
                    title: '알림 설정',
                    subtitle: '알림을 관리하세요',
                    color: AppTheme.sky,
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
                    color: AppTheme.mint,
                    badge: unreadInquiries,
                    onTap: () => _openInquiry(context),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.shield_outlined,
                    title: '개인정보처리방침',
                    subtitle: '개인정보 보호 정책 확인',
                    color: AppTheme.sky,
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
                    subtitle: ref.watch(_appVersionProvider).value ?? '',
                    color: const Color(0xFF607D8B),
                    onTap: () => _showAppInfo(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account
            const _SectionTitle(title: '계정'),
            CartoonCard(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.link,
                    title: '계정 연동',
                    subtitle: '구글·애플·카카오 계정 연결',
                    color: AppTheme.lavender,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SocialLinkScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.heart_broken_outlined,
                    title: '커플 해제',
                    subtitle: '커플 연결을 해제합니다',
                    color: AppTheme.errorColor,
                    onTap: () => _showLeaveCouple(context, ref),
                  ),
                  const Divider(height: 1, indent: 72),
                  _MenuTile(
                    icon: Icons.person_off_outlined,
                    title: '회원탈퇴',
                    subtitle: '계정과 모든 데이터를 삭제합니다',
                    color: AppTheme.textSecondary,
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
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
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
              Icons.chevron_right_rounded,
              color: AppTheme.textHint,
              size: 22,
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

/// 프로필 카드의 연애 상태 칩: "OO · D+123" 또는 "연결 대기 중".
class _RelationChip extends StatelessWidget {
  final String? partnerName;
  final bool connected;
  final int? daysTogether;

  const _RelationChip({
    required this.partnerName,
    required this.connected,
    required this.daysTogether,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = partnerName != null && partnerName!.isNotEmpty;
    final label = connected
        ? '${hasName ? partnerName : '우리'} · D+${daysTogether ?? '-'}'
        : hasName
        ? '$partnerName 연결 대기 중'
        : '상대방 연결 대기 중';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.ink, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            connected ? Icons.favorite_rounded : Icons.hourglass_top_rounded,
            size: 13,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 더보기 그리드 한 칸: 스티커 아이콘 + 이름.
class _GridTile extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color background;
  final int badge;
  final VoidCallback onTap;

  const _GridTile({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        decoration: AppTheme.cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 9 ? '9+' : '$badge'),
              backgroundColor: AppTheme.primaryColor,
              child: Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
