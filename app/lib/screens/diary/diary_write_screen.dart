import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/mood_emojis.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
import '../../models/diary_entry.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/cute/mood_face.dart';
import '../../widgets/cute/motion.dart';

/// 일기 쓰기/고치기. 교환일기는 바로 함께 보이고, 개인일기는 공개 시점을 고를 수 있다.
class DiaryWriteScreen extends ConsumerStatefulWidget {
  final DiaryKind kind;
  final DiaryEntry? existing;
  const DiaryWriteScreen({super.key, required this.kind, this.existing});

  @override
  ConsumerState<DiaryWriteScreen> createState() => _DiaryWriteScreenState();
}

class _DiaryWriteScreenState extends ConsumerState<DiaryWriteScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  late DateTime _date = widget.existing?.entryDate ?? DateTime.now();
  late String? _mood = widget.existing?.mood;
  bool _saving = false;

  bool get _isPrivate => widget.kind == DiaryKind.private;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final content = _text.text.trim();
    if (content.isEmpty) {
      showTopSnackBar(context, '내용을 써 주세요', isError: true);
      return;
    }
    setState(() => _saving = true);
    final error = await ref
        .read(diaryProvider.notifier)
        .save(
          id: widget.existing?.id,
          kind: widget.kind,
          content: content,
          entryDate: _date,
          mood: _mood,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      showTopSnackBar(context, error, isError: true);
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 일기를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await ref
        .read(diaryProvider.notifier)
        .delete(widget.existing!);
    if (!mounted) return;
    if (error != null) {
      showTopSnackBar(context, error, isError: true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy.MM.dd (E)', 'ko');
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPrivate ? '내 일기' : '교환일기'),
        actions: [
          if (widget.existing != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '저장 중' : '저장',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Bouncy(
            onTap: _pickDate,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  fmt.format(_date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '오늘 기분은?',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final key in moodLabels.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Bouncy(
                      onTap: () =>
                          setState(() => _mood = _mood == key ? null : key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _mood == key
                              ? AppTheme.primarySoft
                              : Colors.transparent,
                          border: Border.all(
                            color: _mood == key
                                ? AppTheme.ink
                                : Colors.transparent,
                            width: AppTheme.outlineWidth,
                          ),
                        ),
                        child: MoodFace(moodKey: key, size: 48),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 줄 공책 느낌의 종이
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEF),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.ink,
                width: AppTheme.outlineWidth,
              ),
              boxShadow: AppTheme.cartoonShadow,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _text,
              maxLength: 5000,
              minLines: 10,
              maxLines: null,
              style: const TextStyle(fontSize: 16, height: 1.9),
              decoration: InputDecoration(
                hintText: _isPrivate
                    ? '오늘 하루, 마음속 이야기를 적어 보세요'
                    : '둘이 함께 쓰는 공책이에요. 하고 싶은 말을 적어 보세요',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          if (_isPrivate) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: 6),
                Text(
                  '나만 볼 수 있어요',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
