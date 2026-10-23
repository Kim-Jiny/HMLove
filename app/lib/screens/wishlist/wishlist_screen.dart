import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/cute/motion.dart';
import '../../widgets/cute/sticker.dart';
import '../../core/top_snackbar.dart';
import '../../models/wish_item.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/cute/loader.dart';
import '../../widgets/cute/mood_face.dart';
import '../../widgets/soft_ui.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(wishlistProvider.notifier).fetchItems();
    });
  }

  void _showAddSheet() {
    // 보고있는 탭의 카테고리를 기본값으로. 전체(filterCategory == null)면 기타.
    final initialCategory =
        ref.read(wishlistProvider).filterCategory ?? WishCategory.OTHER;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddWishSheet(
        initialCategory: initialCategory,
        onAdd: (title, memo, category) async {
          final success = await ref
              .read(wishlistProvider.notifier)
              .addItem(title: title, memo: memo, category: category);
          if (mounted) {
            showTopSnackBar(
              context,
              success ? '위시가 추가되었습니다!' : '추가에 실패했습니다.',
              isError: !success,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(wishlistProvider);
    final items = state.filteredItems;

    return Scaffold(
      appBar: AppBar(title: const Text('위시리스트')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 카테고리 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: '전체',
                  isSelected: state.filterCategory == null,
                  onTap: () =>
                      ref.read(wishlistProvider.notifier).setFilter(null),
                ),
                const SizedBox(width: 8),
                ...WishCategory.values.map(
                  (cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: cat.label,
                      leading: Sticker(stickerFor(cat), size: 18),
                      isSelected: state.filterCategory == cat,
                      onTap: () =>
                          ref.read(wishlistProvider.notifier).setFilter(cat),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 리스트
          Expanded(
            child: state.error != null && items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MoodFace(moodKey: 'sad', size: 72, pop: true),
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              ref.read(wishlistProvider.notifier).fetchItems(),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : state.isLoading && items.isEmpty
                ? const Center(child: CuteLoader())
                : items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Sticker(StickerKind.heart, size: 72),
                        const SizedBox(height: 12),
                        Text(
                          '아직 위시가 없어요\n함께 하고 싶은 것들을 추가해보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.primaryColor,
                    onRefresh: () =>
                        ref.read(wishlistProvider.notifier).fetchItems(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _WishCard(
                          item: item,
                          onFavoriteToggle: () async {
                            final success = await ref
                                .read(wishlistProvider.notifier)
                                .toggleFavorite(item.id);
                            if (!context.mounted) return;
                            if (!success) {
                              showTopSnackBar(
                                context,
                                '즐겨찾기 변경에 실패했습니다.',
                                isError: true,
                              );
                            }
                          },
                          onToggle: () async {
                            final success = await ref
                                .read(wishlistProvider.notifier)
                                .toggleItem(item.id);
                            if (!context.mounted) return;
                            if (!success) {
                              showTopSnackBar(
                                context,
                                '상태 변경에 실패했습니다.',
                                isError: true,
                              );
                            }
                          },
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('위시 삭제'),
                                content: const Text('이 위시를 삭제하시겠어요?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      '삭제',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final success = await ref
                                  .read(wishlistProvider.notifier)
                                  .deleteItem(item.id);
                              if (!context.mounted) return;
                              showTopSnackBar(
                                context,
                                success ? '위시가 삭제되었습니다.' : '삭제에 실패했습니다.',
                                isError: !success,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Widget? leading;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.leading,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.ink, width: 1.3),
          boxShadow: isSelected ? AppTheme.cartoonShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  final WishItem item;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _WishCard({
    required this.item,
    required this.onFavoriteToggle,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CartoonCard(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 완료 체크박스
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isCompleted
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: item.isCompleted
                        ? AppTheme.primaryColor
                        : AppTheme.ink,
                    width: 1.5,
                  ),
                ),
                child: item.isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 14),
              // 카테고리 아이콘 + 제목
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Sticker(stickerFor(item.category), size: 18),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.category.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isCompleted
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (item.memo != null && item.memo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.memo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      item.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 22,
                      color: item.isFavorite
                          ? AppTheme.peach
                          : AppTheme.textHint,
                    ),
                    tooltip: item.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                    onPressed: onFavoriteToggle,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppTheme.textHint,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddWishSheet extends StatefulWidget {
  final WishCategory initialCategory;
  final Future<void> Function(String title, String? memo, WishCategory category)
  onAdd;

  const _AddWishSheet({required this.initialCategory, required this.onAdd});

  @override
  State<_AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends State<_AddWishSheet> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  late WishCategory _category = widget.initialCategory;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '위시 추가',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 카테고리 선택
          Wrap(
            spacing: 8,
            children: WishCategory.values.map((cat) {
              final selected = _category == cat;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Sticker(stickerFor(cat), size: 16),
                    const SizedBox(width: 4),
                    Text(cat.label),
                  ],
                ),
                selected: selected,
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                ),
                onSelected: (v) => setState(() => _category = cat),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // 제목
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: '어떤 걸 하고 싶나요?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          // 메모
          TextField(
            controller: _memoController,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '메모 (선택)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) return;
                      setState(() => _isSubmitting = true);
                      await widget.onAdd(
                        title,
                        _memoController.text.trim().isEmpty
                            ? null
                            : _memoController.text.trim(),
                        _category,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('추가하기'),
            ),
          ),
        ],
      ),
    );
  }
}
