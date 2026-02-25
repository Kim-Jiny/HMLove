import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/letter_provider.dart';

class LetterWriteScreen extends ConsumerStatefulWidget {
  final Letter? letter; // Optional letter data for edit mode

  const LetterWriteScreen({super.key, this.letter});

  @override
  ConsumerState<LetterWriteScreen> createState() => _LetterWriteScreenState();
}

class _LetterWriteScreenState extends ConsumerState<LetterWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  DateTime? _deliveryDate;
  TimeOfDay? _deliveryTime;
  bool _isSaving = false;
  bool _isPreview = false;

  bool get _isEditMode => widget.letter != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: _isEditMode ? widget.letter!.title : '',
    );
    _contentController = TextEditingController(
      text: _isEditMode ? widget.letter!.content ?? '' : '',
    );
    if (_isEditMode) {
      final d = widget.letter!.deliveryDate.toLocal();
      _deliveryDate = DateTime(d.year, d.month, d.day);
      _deliveryTime = TimeOfDay(hour: d.hour, minute: d.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 날짜 + 시간을 합쳐서 UTC DateTime 으로 반환
  DateTime? _combinedDeliveryUtc() {
    if (_deliveryDate == null) return null;
    final time = _deliveryTime ?? const TimeOfDay(hour: 9, minute: 0);
    final local = DateTime(
      _deliveryDate!.year,
      _deliveryDate!.month,
      _deliveryDate!.day,
      time.hour,
      time.minute,
    );
    return local.toUtc();
  }

  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
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
        // 시간을 아직 안 정했으면 기본 오전 9시
        _deliveryTime ??= const TimeOfDay(hour: 9, minute: 0);
      });
    }
  }

  Future<void> _pickDeliveryTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deliveryTime ?? const TimeOfDay(hour: 9, minute: 0),
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
        _deliveryTime = picked;
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_titleController.text.trim().isEmpty) {
      showTopSnackBar(context, '제목을 입력해주세요', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditMode) {
        await ref.read(letterProvider.notifier).updateLetter(
              id: widget.letter!.id,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: _combinedDeliveryUtc(),
            );
      } else {
        await ref.read(letterProvider.notifier).createLetter(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: _combinedDeliveryUtc(),
            );
      }

      if (mounted) {
        showTopSnackBar(context, '임시저장되었습니다');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '저장에 실패했습니다: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _schedule() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deliveryDate == null) {
      showTopSnackBar(context, '전달 날짜를 선택해주세요', isError: true);
      return;
    }

    final deliveryUtc = _combinedDeliveryUtc()!;
    if (deliveryUtc.isBefore(DateTime.now().toUtc())) {
      showTopSnackBar(context, '현재 시각 이후로 설정해주세요', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditMode) {
        await ref.read(letterProvider.notifier).updateLetter(
              id: widget.letter!.id,
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: deliveryUtc,
            );
      } else {
        await ref.read(letterProvider.notifier).createLetter(
              title: _titleController.text.trim(),
              content: _contentController.text.trim(),
              deliveryDate: deliveryUtc,
            );
      }

      if (mounted) {
        final time = _deliveryTime ?? const TimeOfDay(hour: 9, minute: 0);
        showTopSnackBar(
          context,
          '${DateFormat('M월 d일').format(_deliveryDate!)} ${time.hour}시 ${time.minute.toString().padLeft(2, '0')}분에 전달될 예정이에요',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '저장에 실패했습니다: $e', isError: true);
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
                showTopSnackBar(context, '내용을 입력한 후 미리보기할 수 있어요');
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

                // Delivery date & time
                const Text(
                  '전달 일시',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '선택한 날짜와 시간에 상대방에게 편지가 전달됩니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 날짜 선택
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickDeliveryDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE0E0E0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _deliveryDate != null
                                    ? DateFormat('yyyy년 M월 d일')
                                        .format(_deliveryDate!)
                                    : '날짜 선택',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _deliveryDate != null
                                      ? AppTheme.textPrimary
                                      : AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 시간 선택
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _deliveryDate != null
                            ? _pickDeliveryTime
                            : () {
                                showTopSnackBar(
                                    context, '날짜를 먼저 선택해주세요');
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFE0E0E0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_outlined,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _deliveryTime != null
                                    ? '${_deliveryTime!.hour.toString().padLeft(2, '0')}:${_deliveryTime!.minute.toString().padLeft(2, '0')}'
                                    : '09:00',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _deliveryTime != null
                                      ? AppTheme.textPrimary
                                      : AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                    () {
                      final time = _deliveryTime ??
                          const TimeOfDay(hour: 9, minute: 0);
                      return '${DateFormat('yyyy년 M월 d일').format(_deliveryDate!)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    }(),
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
