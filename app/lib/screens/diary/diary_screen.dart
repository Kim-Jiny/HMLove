import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/mood_emojis.dart';
import '../../core/theme.dart';
import '../../models/diary_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/cute/loader.dart';
import '../../widgets/cute/mood_face.dart';
import '../../widgets/cute/motion.dart';
import '../../widgets/cute/sticker.dart';
import '../../widgets/soft_ui.dart';
import 'diary_write_screen.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  static const _scopes = [DiaryScope.shared, DiaryScope.mine];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      for (final s in _scopes) {
        ref.read(diaryProvider.notifier).fetch(s);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _write([DiaryEntry? existing]) {
    final kind =
        existing?.kind ??
        (_tabs.index == 1 ? DiaryKind.private : DiaryKind.shared);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryWriteScreen(kind: kind, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diaryProvider);
    final myId = ref.watch(currentUserProvider)?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('일기'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primaryColor,
          indicatorColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: '교환일기'),
            Tab(text: '내 일기'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _write(),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          '쓰기',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final scope in _scopes)
            _DiaryList(
              scope: scope,
              entries: state.of(scope),
              loading: state.loading.contains(scope),
              error: state.error,
              myId: myId,
              onTap: (e) => e.authorId == myId ? _write(e) : null,
            ),
        ],
      ),
    );
  }
}

class _DiaryList extends ConsumerWidget {
  final DiaryScope scope;
  final List<DiaryEntry> entries;
  final bool loading;
  final String? error;
  final String? myId;
  final void Function(DiaryEntry) onTap;

  const _DiaryList({
    required this.scope,
    required this.entries,
    required this.loading,
    required this.error,
    required this.myId,
    required this.onTap,
  });

  String get _emptyText => switch (scope) {
    DiaryScope.shared => '아직 교환일기가 비어 있어요\n먼저 한 장 써 볼까요?\n순서 상관없이 언제든 쓸 수 있어요',
    DiaryScope.mine => '나만 볼 수 있는 일기장이에요\n오늘 하루를 편하게 적어 보세요',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading && entries.isEmpty) return const Center(child: CuteLoader());
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () => ref.read(diaryProvider.notifier).fetch(scope),
      child: entries.isEmpty
          ? ListView(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                Column(
                  children: [
                    const Sticker(StickerKind.heart, size: 64),
                    const SizedBox(height: 14),
                    Text(
                      error != null
                          ? '불러오지 못했어요\n아래로 당겨 다시 시도해 주세요'
                          : _emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              itemCount: entries.length,
              itemBuilder: (_, i) => FadeSlideIn(
                index: i.clamp(0, 6),
                child: _DiaryCard(
                  entry: entries[i],
                  mine: entries[i].authorId == myId,
                  showAuthor: scope != DiaryScope.mine,
                  onTap: () => onTap(entries[i]),
                ),
              ),
            ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final bool mine;
  final bool showAuthor;
  final VoidCallback onTap;
  const _DiaryCard({
    required this.entry,
    required this.mine,
    required this.showAuthor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: mine ? onTap : null,
      pressedScale: 0.98,
      child: CartoonCard(
        color: const Color(0xFFFFFBEF),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.mood != null) ...[
                    MoodFace(moodKey: entry.mood, size: 34),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'yyyy.MM.dd (E)',
                            'ko',
                          ).format(entry.entryDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (showAuthor || entry.mood != null)
                          Text(
                            [
                              if (showAuthor) entry.authorName,
                              if (entry.mood != null)
                                moodLabels[entry.mood] ?? '',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.content,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
