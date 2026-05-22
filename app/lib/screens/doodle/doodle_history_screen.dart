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

class _DoodleHistoryScreenState extends ConsumerState<DoodleHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      if (!mounted) return;
      ref.read(doodleProvider.notifier).fetchHistory();
      ref.read(doodleProvider.notifier).fetchLatestReceived();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openCanvas() async {
    final result = await context.push<bool>('/doodle/canvas');
    if (result == true && mounted) {
      ref.read(doodleProvider.notifier).fetchHistory();
    }
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

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(doodleProvider.notifier).fetchHistory(),
      ref.read(doodleProvider.notifier).fetchLatestReceived(),
    ]);
  }

  void _openViewer(Doodle d) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _DoodleViewer(doodle: d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doodleProvider);
    final me = ref.watch(currentUserProvider);
    final myId = me?.id ?? '';

    final received =
        state.doodles.where((d) => d.senderId != myId).toList();
    final sent = state.doodles.where((d) => d.senderId == myId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('그림 보내기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(text: '받은 그림 ${received.length}'),
            Tab(text: '보낸 그림 ${sent.length}'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: _openCanvas,
        tooltip: '그림 그리기',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DoodleGrid(
            doodles: received,
            isLoading: state.isLoading,
            kind: _DoodleListKind.received,
            onRefresh: _refresh,
            onTap: _openViewer,
            onLongPress: null, // 받은 그림은 삭제 불가
          ),
          _DoodleGrid(
            doodles: sent,
            isLoading: state.isLoading,
            kind: _DoodleListKind.sent,
            onRefresh: _refresh,
            onTap: _openViewer,
            onLongPress: _confirmDelete,
          ),
        ],
      ),
    );
  }
}

enum _DoodleListKind { received, sent }

class _DoodleGrid extends StatelessWidget {
  final List<Doodle> doodles;
  final bool isLoading;
  final _DoodleListKind kind;
  final Future<void> Function() onRefresh;
  final void Function(Doodle) onTap;
  final void Function(Doodle)? onLongPress;

  const _DoodleGrid({
    required this.doodles,
    required this.isLoading,
    required this.kind,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: isLoading && doodles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : doodles.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    _EmptyState(kind: kind),
                  ],
                )
              : GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: doodles.length,
                  itemBuilder: (context, i) {
                    final d = doodles[i];
                    return _DoodleGridTile(
                      doodle: d,
                      onTap: () => onTap(d),
                      onLongPress: onLongPress == null
                          ? null
                          : () => onLongPress!(d),
                    );
                  },
                ),
    );
  }
}

class _DoodleGridTile extends StatelessWidget {
  final Doodle doodle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DoodleGridTile({
    required this.doodle,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('M/d HH:mm').format(doodle.createdAt.toLocal());

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: doodle.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: const Color(0xFFF8F1EC),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: const Color(0xFFF8F1EC),
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppTheme.textHint,
                  size: 20,
                ),
              ),
            ),
            // 하단 그라데이션 + 날짜 — 작게
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
                child: Text(
                  dateText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

class _DoodleViewer extends StatelessWidget {
  final Doodle doodle;

  const _DoodleViewer({required this.doodle});

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('yyyy.MM.dd HH:mm').format(doodle.createdAt.toLocal());
    final sender = doodle.senderNickname.isEmpty ? '상대방' : doodle.senderNickname;
    final receiver =
        doodle.receiverNickname.isEmpty ? '상대방' : doodle.receiverNickname;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: doodle.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: const Color(0xFF1F1F1F),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFF1F1F1F),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$sender → $receiver',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _DoodleListKind kind;

  const _EmptyState({required this.kind});

  @override
  Widget build(BuildContext context) {
    final isReceived = kind == _DoodleListKind.received;
    final title = isReceived ? '아직 받은 그림이 없어요' : '아직 보낸 그림이 없어요';
    final subtitle = isReceived
        ? '상대방이 그림을 보내면 여기에 쌓여요'
        : '오른쪽 아래 + 버튼으로\n상대방에게 그림을 보내보세요!';

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
            child: Icon(
              isReceived ? Icons.inbox_rounded : Icons.brush_rounded,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
