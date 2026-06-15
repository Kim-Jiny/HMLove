import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../providers/wishlist_provider.dart';

class WishlistPreviewCard extends StatelessWidget {
  final WishlistState state;
  final VoidCallback onTap;

  const WishlistPreviewCard({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = state.items.length;
    final favoriteItems = state.items.where((item) => item.isFavorite).toList();
    final previewFavorites = favoriteItems.take(3).toList();

    final String subtitle;
    if (state.isLoading && state.items.isEmpty) {
      subtitle = '불러오는 중...';
    } else if (state.error != null && state.items.isEmpty) {
      subtitle = '위시리스트를 불러오지 못했어요';
    } else if (totalCount == 0) {
      subtitle = '아직 위시리스트가 없어요';
    } else {
      subtitle = '$totalCount개의 위시리스트가 있어요';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF1E6DF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFE07A5F),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '위시리스트',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textHint,
                  ),
                ],
              ),
              if (previewFavorites.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCFA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF2E4DB)),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < previewFavorites.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 14,
                            thickness: 0.6,
                            color: Colors.grey.shade200,
                          ),
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              size: 13,
                              color: Color(0xFFE07A5F),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                previewFavorites[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: previewFavorites[i].isCompleted
                                      ? AppTheme.textHint
                                      : AppTheme.textPrimary,
                                  decoration: previewFavorites[i].isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (favoriteItems.length > previewFavorites.length) ...[
                        Divider(
                          height: 14,
                          thickness: 0.6,
                          color: Colors.grey.shade200,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+ ${favoriteItems.length - previewFavorites.length}개 더',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE07A5F),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
