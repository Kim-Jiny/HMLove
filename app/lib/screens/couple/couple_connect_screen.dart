import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/couple_provider.dart';
import '../../providers/session_reset.dart';

class CoupleConnectScreen extends ConsumerStatefulWidget {
  const CoupleConnectScreen({super.key});

  @override
  ConsumerState<CoupleConnectScreen> createState() =>
      _CoupleConnectScreenState();
}

class _CoupleConnectScreenState extends ConsumerState<CoupleConnectScreen> {
  final _inviteCodeController = TextEditingController();
  final _partnerNameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  bool _showCreateView = true;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inviteCodeController.dispose();
    _partnerNameController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      // checkAuthStatus가 isCoupleComplete=true로 업데이트하면
      // GoRouter redirect가 자동으로 /home으로 이동시킴
      await ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '사귀기 시작한 날짜를 선택하세요',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _handleLeaveCouple() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('커플 해제'),
        content: const Text('생성된 커플을 해제하시겠습니까?\n초대 코드도 무효화됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ref.read(coupleProvider.notifier).leaveCouple();
    if (!mounted) return;

    if (success) {
      // 커플 해제 시 이전 커플의 피드·사진·캘린더 등 잔존 데이터 초기화
      resetFeatureProviders(ref);
      showTopSnackBar(context, '커플이 해제되었습니다');
    }
  }

  Future<void> _handleCreateCouple() async {
    // 성공하면 authProvider 의 coupleId 가 채워져 router 가 /home 으로 보낸다.
    // 초대 코드는 홈의 "상대방 초대하기" 또는 더보기에서 확인할 수 있다.
    await ref.read(coupleProvider.notifier).createCouple(startDate: _startDate);
  }

  Future<void> _handleStartWithoutPartner() async {
    // 성공하면 authProvider 의 isSolo 가 true 가 되어 router 가 /home 으로 보낸다.
    await ref
        .read(coupleProvider.notifier)
        .startWithoutPartner(
          startDate: _startDate,
          partnerName: _partnerNameController.text,
        );
  }

  Future<void> _handleJoinCouple() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;

    await ref.read(coupleProvider.notifier).joinCouple(inviteCode: code);

    if (!mounted) return;

    // joinCouple 내부에서 authProvider를 업데이트하므로
    // GoRouter redirect가 자동으로 /home으로 이동시킴
    // 실패 시에만 별도 처리 없음 (에러는 coupleState.error로 표시)
  }

  bool _pollInitialized = false;

  void _syncPolling(String? inviteCode) {
    if (inviteCode != null) {
      if (_pollTimer == null || !_pollTimer!.isActive) {
        _startPolling();
      }
    } else {
      _stopPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = ref.watch(coupleProvider);

    ref.listen<CoupleState>(coupleProvider, (prev, next) {
      _syncPolling(next.generatedInviteCode);
    });

    if (!_pollInitialized) {
      _pollInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPolling(coupleState.generatedInviteCode);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('커플 연결'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppTheme.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 44,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '사랑하는 사람과\n연결하세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '상대방이 아직 앱을 설치하지 않았어도\n먼저 시작해서 기록을 남길 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Tab toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showCreateView = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _showCreateView
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '커플 만들기',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _showCreateView
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _showCreateView = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_showCreateView
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '초대 코드 입력',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !_showCreateView
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // If couple already created, show invite code
              if (coupleState.generatedInviteCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.primaryColor,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '커플이 생성되었어요!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '상대방에게 아래 초대 코드를 보내주세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              coupleState.generatedInviteCode!,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: coupleState.generatedInviteCode!,
                                  ),
                                );
                                showTopSnackBar(context, '초대 코드가 복사되었습니다');
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '상대방이 연결하면 자동으로 시작됩니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: coupleState.isLoading ? null : _handleLeaveCouple,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('커플 해제하고 다시 만들기'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                  ),
                ),
              ] else if (_showCreateView) ...[
                // Create couple view
                const Text(
                  '우리가 사귀기 시작한 날',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderColor),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('yyyy년 M월 d일').format(_startDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: coupleState.isLoading
                        ? null
                        : _handleCreateCouple,
                    child: coupleState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('커플 만들기'),
                  ),
                ),
              ] else ...[
                // Join couple view
                const Text(
                  '초대 코드',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inviteCodeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [_UpperCaseTextFormatter()],
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '코드를 입력하세요',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      letterSpacing: 1,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: coupleState.isLoading ? null : _handleJoinCouple,
                    child: coupleState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('연결하기'),
                  ),
                ),
              ],

              // 상대 없이 먼저 시작 — 어느 탭에서든 보인다. (커플 만들기 탭이면 상대 애칭도 입력)
              if (coupleState.generatedInviteCode == null &&
                  ref.watch(currentUserProvider)?.coupleId == null) ...[
                const SizedBox(height: 16),
                if (_showCreateView) ...[
                  TextField(
                    controller: _partnerNameController,
                    maxLength: 20,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '상대방 이름 또는 애칭 (선택)',
                      hintText: '예: 자기, 지수',
                      counterText: '',
                      prefixIcon: Icon(Icons.favorite_border_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '또는',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: coupleState.isLoading
                        ? null
                        : _handleStartWithoutPartner,
                    child: const Text('상대방 없이 먼저 시작하기'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '일기·편지·일정을 먼저 남겨두고,\n더보기에서 언제든 상대방을 초대할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],

              if (coupleState.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  coupleState.error!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // coupleId는 있는데 초대코드 화면이 아닌 경우 (해제 버튼 노출)
              if (coupleState.generatedInviteCode == null &&
                  ref.watch(currentUserProvider)?.coupleId != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('메인으로 들어가기'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '이미 생성한 커플이 있습니다.\n해제 후 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: coupleState.isLoading ? null : _handleLeaveCouple,
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('기존 커플 해제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
