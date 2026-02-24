import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/letter_provider.dart';

class LetterWriteScreen extends ConsumerStatefulWidget {
  final dynamic letter; // Optional letter data for edit mode

  const LetterWriteScreen({super.key, this.letter});

  @override
  ConsumerState<LetterWriteScreen> createState() => _LetterWriteScreenState();
}

class _LetterWriteScreenState extends ConsumerState<LetterWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  DateTime? _deliveryDate;
  bool _isSaving = false;
  bool _isPreview = false;

  bool get _isEditMode => widget.letter != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: _isEditMode ? widget.letter.title ?? '' : '',
    );
    _contentController = TextEditingController(
      text: _isEditMode ? widget.letter.content ?? '' : '',
    );
    _deliveryDate =
        _isEditMode ? widget.letter.deliveryDate : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primaryColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목을 입력해주세요'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditMode) {
        await ref.read(letterProvider.notifier).updateLetter(
              id: widget.letter.id,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: _deliveryDate,
              status: 'DRAFT',
            );
      } else {
        await ref.read(letterProvider.notifier).createLetter(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: _deliveryDate,
              status: 'DRAFT',
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('임시저장되었습니다'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장에 실패했습니다: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _schedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deliveryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전달 날짜를 선택해주세요'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditMode) {
        await ref.read(letterProvider.notifier).updateLetter(
              id: widget.letter.id,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: _deliveryDate,
              status: 'SCHEDULED',
            );
      } else {
        await ref.read(letterProvider.notifier).createLetter(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: _deliveryDate,
              status: 'SCHEDULED',
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateFormat('M월 d일').format(_deliveryDate!)}에 전달될 예정이에요',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장에 실패했습니다: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreview) {
      return _buildPreview();
    }
    return _buildEditor();
  }

  Widget _buildEditor() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '편지 수정' : '편지 쓰기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview_outlined),
            onPressed: () {
              if (_titleController.text.trim().isEmpty &&
                  _contentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('내용을 입력한 후 미리보기할 수 있어요'),
                  ),
                );
                return;
              }
              setState(() => _isPreview = true);
            },
            tooltip: '미리보기',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFFFF5F7),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Letter paper card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE8DDD0),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '편지 제목',
                          hintStyle: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '제목을 입력해주세요';
                          }
                          return null;
                        },
                      ),

                      const Divider(
                        color: Color(0xFFE8DDD0),
                        height: 24,
                      ),

                      // Content
                      TextFormField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 12,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 2.0,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: '마음을 담아 편지를 써보세요...',
                          hintStyle: TextStyle(
                            color: AppTheme.textHint,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '내용을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Delivery date
                const Text(
                  '전달 날짜',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '선택한 날짜에 상대방에게 편지가 전달됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDeliveryDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_send_outlined,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _deliveryDate != null
                              ? DateFormat('yyyy년 M월 d일')
                                  .format(_deliveryDate!)
                              : '날짜를 선택해주세요',
                          style: TextStyle(
                            fontSize: 15,
                            color: _deliveryDate != null
                                ? AppTheme.textPrimary
                                : AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _saveDraft,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('임시저장'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _schedule,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined, size: 18),
                        label: const Text('편지 보내기'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('미리보기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _isPreview = false);
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8F0),
              Color(0xFFFFF5F7),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFE8DDD0),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  _titleController.text.isNotEmpty
                      ? _titleController.text
                      : '제목 없음',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_deliveryDate != null)
                  Text(
                    DateFormat('yyyy년 M월 d일').format(_deliveryDate!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                const Divider(
                  color: Color(0xFFE8DDD0),
                  height: 32,
                ),
                // Content
                Text(
                  _contentController.text.isNotEmpty
                      ? _contentController.text
                      : '내용 없음',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 2.0,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
