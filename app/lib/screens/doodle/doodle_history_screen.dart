import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/doodle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/doodle_provider.dart';

class DoodleHistoryScreen extends ConsumerStatefulWidget {
  const DoodleHistoryScreen({super.key});

  @override
  ConsumerState<DoodleHistoryScreen> createState() =>
      _DoodleHistoryScreenState();
}

class _DoodleHistoryScreenState extends ConsumerState<DoodleHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(doodleProvider.notifier).fetchHistory();
      ref.read(doodleProvider.notifier).fetchLatestReceived();
    });
  }

  Future<void> _openCanvas() async {
    final result = await context.push<bool>('/doodle/canvas');
    if (result == true && mounted) {
      ref.read(doodleProvider.notifier).fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doodleProvider);
    final me = ref.watch(currentUserProvider);
    final myId = me?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('그림 보내기')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: _openCanvas,
        icon: const Icon(Icons.brush_rounded),
        label: const Text('그림 그리기'),
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          await Future.wait([
            ref.read(doodleProvider.notifier).fetchHistory(),
            ref.read(doodleProvider.notifier).fetchLatestReceived(),
          ]);
        },
        child: state.isLoading && state.doodles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.doodles.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      _EmptyState(),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: state.doodles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      final d = state.doodles[i];
                      final isMine = d.senderId == myId;
                      return _DoodleTile(
                        doodle: d,
                        isMine: isMine,
                        onDelete: isMine
                            ? () => _confirmDelete(d)
                            : null,
                      );
                    },
                  ),
      ),
    );
  }

  Future<void> _confirmDelete(Doodle d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그림 삭제'),
        content: const Text('보낸 그림을 삭제하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(doodleProvider.notifier).deleteDoodle(d.id);
  }
}

class _DoodleTile extends StatelessWidget {
  final Doodle doodle;
  final bool isMine;
  final VoidCallback? onDelete;

  const _DoodleTile({
    required this.doodle,
    required this.isMine,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('yyyy.MM.dd HH:mm').format(doodle.createdAt.toLocal());
    final subTitle = isMine
        ? '${doodle.receiverNickname.isEmpty ? "상대방" : doodle.receiverNickname}에게 보냄'
        : '${doodle.senderNickname.isEmpty ? "상대방" : doodle.senderNickname}이(가) 보냄';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1E6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: doodle.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFFF8F1EC),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFF8F1EC),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isMine
                            ? AppTheme.primaryColor
                            : const Color(0xFF2196F3))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isMine ? '보냄' : '받음',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMine
                          ? AppTheme.primaryColor
                          : const Color(0xFF2196F3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.textHint,
                      size: 20,
                    ),
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.brush_rounded,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '아직 주고받은 그림이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '오른쪽 아래 버튼으로 그림을 그려\n상대방의 위젯으로 보내보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
