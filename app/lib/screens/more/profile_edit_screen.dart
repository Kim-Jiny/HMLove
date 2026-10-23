import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/server_date.dart';
import '../../core/top_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../widgets/cute/loader.dart';
import '../../widgets/cute/motion.dart';
import '../../widgets/cute/profile_avatar.dart';
import '../../widgets/soft_ui.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nicknameController;
  DateTime? _birthDate;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _birthDate = user?.birthDate;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SourceTile(
                icon: Icons.camera_alt_rounded,
                label: '카메라로 찍기',
                color: AppTheme.primaryColor,
                background: AppTheme.primarySoft,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: '앨범에서 선택',
                color: AppTheme.lavender,
                background: AppTheme.lavenderSoft,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final dio = ApiClient.createDio();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
      });
      final response = await dio.post('/auth/profile/image', data: formData);
      final userData = response.data['user'] as Map<String, dynamic>;
      final updatedUser = User.fromJson(userData);
      ref
          .read(authProvider.notifier)
          .updateUser(
            ref
                .read(currentUserProvider)!
                .copyWith(profileImage: updatedUser.profileImage),
          );
      if (mounted) {
        showTopSnackBar(context, '프로필 사진이 변경되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '이미지 업로드에 실패했습니다.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: '생년월일을 선택하세요',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      showTopSnackBar(context, '닉네임을 입력해주세요.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dio = ApiClient.createDio();
      final response = await dio.patch(
        '/auth/profile',
        data: {
          'nickname': nickname,
          if (_birthDate != null) 'birthDate': toServerDateOnly(_birthDate!),
        },
      );

      final userData = response.data['user'] as Map<String, dynamic>;
      final updatedUser = User.fromJson(userData);
      final currentUser = ref.read(currentUserProvider)!;
      ref
          .read(authProvider.notifier)
          .updateUser(
            currentUser.copyWith(
              nickname: updatedUser.nickname,
              birthDate: updatedUser.birthDate,
            ),
          );

      if (mounted) {
        showTopSnackBar(context, '프로필이 수정되었습니다.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '프로필 수정에 실패했습니다.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const CuteLoader(size: 12)
                : const Text(
                    '저장',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          children: staggered([
            // Profile Image
            Center(
              child: Bouncy(
                onTap: _isUploadingImage ? null : _pickProfileImage,
                pressedScale: 0.92,
                child: Stack(
                  children: [
                    ProfileAvatar(
                      imageUrl: user?.profileImage,
                      seed: user?.id ?? user?.nickname ?? '',
                      size: 112,
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          child: const Center(child: CuteLoader(size: 14)),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.ink,
                            width: AppTheme.outlineWidth,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '사진이 없으면 귀여운 기본 얼굴이 보여요',
              style: TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
            const SizedBox(height: 28),

            // Nickname
            TextField(
              controller: _nicknameController,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: '닉네임',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),

            // Email (read-only)
            TextFormField(
              initialValue: user?.email ?? '',
              readOnly: true,
              style: const TextStyle(color: AppTheme.textSecondary),
              decoration: const InputDecoration(
                labelText: '이메일',
                helperText: '이메일은 변경할 수 없어요',
                prefixIcon: Icon(Icons.email_outlined),
                fillColor: AppTheme.backgroundColor,
              ),
            ),
            const SizedBox(height: 16),

            // Birth Date
            Bouncy(
              onTap: _pickBirthDate,
              pressedScale: 0.98,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '생년월일',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                child: Text(
                  _birthDate != null
                      ? DateFormat('yyyy년 M월 d일').format(_birthDate!)
                      : '선택하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: _birthDate != null ? null : AppTheme.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '생일은 오늘의 운세와 기념일에 쓰여요',
                  style: TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.cardDecoration(),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              color: color,
              background: background,
              size: 42,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
