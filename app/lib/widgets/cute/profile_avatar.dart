import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'mood_face.dart';

/// 프로필 사진. 사진이 없으면 계정마다 고정된 귀여운 얼굴을 보여준다.
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;

  /// 기본 얼굴을 고르는 시드(보통 사용자 id 또는 닉네임).
  final String seed;
  final double size;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.seed,
    this.size = 64,
  });

  static const _moods = [
    'happy',
    'love',
    'excited',
    'grateful',
    'proud',
    'peaceful',
  ];

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    final mood = _moods[hash % _moods.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primarySoft,
        border: Border.all(color: AppTheme.ink, width: AppTheme.outlineWidth),
        boxShadow: AppTheme.cartoonShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => MoodFace(moodKey: mood, size: size),
            )
          : Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: MoodFace(moodKey: mood, size: size),
            ),
    );
  }
}
