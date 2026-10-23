import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/top_snackbar.dart';

/// 상대방에게 공유할 초대 코드를 보여주는 다이얼로그.
void showInviteCodeDialog(BuildContext context, String code) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.link_rounded, color: AppTheme.primaryColor, size: 24),
          SizedBox(width: 8),
          Text('초대 코드'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '아래 코드를 상대방에게 공유하세요.\n상대방이 코드를 입력하면 자동으로 연결됩니다.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showTopSnackBar(ctx, '초대 코드가 복사되었습니다');
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  tooltip: '복사',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}
