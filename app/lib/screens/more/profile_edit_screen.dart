import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
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
        'image': await MultipartFile.fromFile(picked.path, filename: picked.name),
      });
      final response = await dio.post('/auth/profile/image', data: formData);
      final userData = response.data['user'] as Map<String, dynamic>;
      final updatedUser = User.fromJson(userData);
      ref.read(authProvider.notifier).updateUser(
        ref.read(currentUserProvider)!.copyWith(
          profileImage: updatedUser.profileImage,
        ),
      );
      if (mounted) {
        showTopSnackBar(context, '프로필 사진이 변경되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '이미지 업로드에 실패했습니다.', isError: true);
      }
    } finally {
      setState(() => _isUploadingImage = false);
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
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppTheme.primaryColor,
              ),
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
      final response = await dio.patch('/auth/profile', data: {
        'nickname': nickname,
        if (_birthDate != null)
          'birthDate': _birthDate!.toIso8601String(),
      });

      final userData = response.data['user'] as Map<String, dynamic>;
      final updatedUser = User.fromJson(userData);
      final currentUser = ref.read(currentUserProvider)!;
      ref.read(authProvider.notifier).updateUser(
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
      setState(() => _isSaving = false);
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Image
            Center(
              child: GestureDetector(
                onTap: _isUploadingImage ? null : _pickProfileImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          AppTheme.primaryLight.withValues(alpha: 0.3),
                      backgroundImage: user?.profileImage != null
                          ? NetworkImage(user!.profileImage!)
                          : null,
                      child: _isUploadingImage
                          ? const CircularProgressIndicator(
                              color: AppTheme.primaryColor)
                          : user?.profileImage == null
                              ? Text(
                                  user?.nickname.isNotEmpty == true
                                      ? user!.nickname[0]
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Nickname
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Email (read-only)
            TextField(
              controller: TextEditingController(text: user?.email ?? ''),
              readOnly: true,
              decoration: InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 16),

            // Birth Date
            InkWell(
              onTap: _pickBirthDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '생년월일',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.cake_outlined),
                ),
                child: Text(
                  _birthDate != null
                      ? DateFormat('yyyy년 M월 d일').format(_birthDate!)
                      : '선택하세요',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        _birthDate != null ? null : AppTheme.textHint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
