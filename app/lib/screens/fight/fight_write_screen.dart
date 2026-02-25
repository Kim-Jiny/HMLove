import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../providers/fight_provider.dart';

class FightWriteScreen extends ConsumerStatefulWidget {
  final Fight? fight; // Optional fight data for edit mode

  const FightWriteScreen({super.key, this.fight});

  @override
  ConsumerState<FightWriteScreen> createState() => _FightWriteScreenState();
}

class _FightWriteScreenState extends ConsumerState<FightWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  late final TextEditingController _resolutionController;
  late final TextEditingController _reflectionController;
  late DateTime _selectedDate;
  bool _isResolved = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.fight != null;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: _isEditMode ? widget.fight!.reason : '',
    );
    _resolutionController = TextEditingController(
      text: _isEditMode ? widget.fight!.resolution ?? '' : '',
    );
    _reflectionController = TextEditingController(
      text: _isEditMode ? widget.fight!.reflection ?? '' : '',
    );
    _selectedDate = _isEditMode ? widget.fight!.date : DateTime.now();
    _isResolved = _isEditMode ? widget.fight!.isResolved : false;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _resolutionController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await ref.read(fightProvider.notifier).updateFight(
              id: widget.fight!.id,
              date: _selectedDate,
              reason: _reasonController.text.trim(),
              resolution: _resolutionController.text.trim().isEmpty
                  ? null
                  : _resolutionController.text.trim(),
              reflection: _reflectionController.text.trim().isEmpty
                  ? null
                  : _reflectionController.text.trim(),
              isResolved: _isResolved,
            );
      } else {
        await ref.read(fightProvider.notifier).createFight(
              date: _selectedDate,
              reason: _reasonController.text.trim(),
              resolution: _resolutionController.text.trim().isEmpty
                  ? null
                  : _resolutionController.text.trim(),
              reflection: _reflectionController.text.trim().isEmpty
                  ? null
                  : _reflectionController.text.trim(),
              isResolved: _isResolved,
            );
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '저장에 실패했습니다: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '수정하기' : '다툼 기록하기'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker
              const _FieldLabel(label: '날짜'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
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
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('yyyy년 M월 d일 (E)', 'ko')
                            .format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reason
              const _FieldLabel(label: '다툼 이유'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '어떤 일로 다투었나요?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '다툼 이유를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Resolution
              const _FieldLabel(label: '해결 방법', optional: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _resolutionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '어떻게 해결했나요? (또는 해결 방법을 적어보세요)',
                ),
              ),
              const SizedBox(height: 24),

              // Reflection
              const _FieldLabel(label: '반성 / 느낀 점', optional: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reflectionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '이 다툼을 통해 느낀 점이 있나요?',
                ),
              ),
              const SizedBox(height: 24),

              // Resolved toggle
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isResolved
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isResolved
                              ? Icons.check_circle
                              : Icons.pending_outlined,
                          color: _isResolved
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '해결 여부',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _isResolved ? '해결되었어요' : '아직 해결하지 못했어요',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isResolved,
                        onChanged: (value) {
                          setState(() => _isResolved = value);
                        },
                        activeColor: AppTheme.successColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _FieldLabel({
    required this.label,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 4),
          const Text(
            '(선택)',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ],
    );
  }
}
