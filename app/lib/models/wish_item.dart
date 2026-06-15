// 값 이름이 그대로 서버와 직렬화된다(category.name == 'PLACE' 등). 서버 enum 과
// 일치시켜야 하므로 대문자 유지 — lowerCamelCase 로 바꾸면 직렬화가 깨진다.
// ignore_for_file: constant_identifier_names
enum WishCategory {
  PLACE,
  FOOD,
  ACTIVITY,
  OTHER;

  String get label {
    switch (this) {
      case PLACE:
        return '장소';
      case FOOD:
        return '음식';
      case ACTIVITY:
        return '활동';
      case OTHER:
        return '기타';
    }
  }

  String get emoji {
    switch (this) {
      case PLACE:
        return '📍';
      case FOOD:
        return '🍽️';
      case ACTIVITY:
        return '🎯';
      case OTHER:
        return '💫';
    }
  }
}

class WishItem {
  final String id;
  final String coupleId;
  final String authorId;
  final WishCategory category;
  final String title;
  final String? memo;
  final bool isFavorite;
  final bool isCompleted;
  final String? completedBy;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WishItem({
    required this.id,
    required this.coupleId,
    required this.authorId,
    required this.category,
    required this.title,
    this.memo,
    required this.isFavorite,
    required this.isCompleted,
    this.completedBy,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WishItem.fromJson(Map<String, dynamic> json) {
    return WishItem(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      authorId: json['authorId'] as String,
      category: WishCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => WishCategory.OTHER,
      ),
      title: json['title'] as String,
      memo: json['memo'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedBy: json['completedBy'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'coupleId': coupleId,
    'authorId': authorId,
    'category': category.name,
    'title': title,
    'memo': memo,
    'isFavorite': isFavorite,
    'isCompleted': isCompleted,
    'completedBy': completedBy,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  WishItem copyWith({
    bool? isFavorite,
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
    String? title,
    String? memo,
    WishCategory? category,
  }) {
    return WishItem(
      id: id,
      coupleId: coupleId,
      authorId: authorId,
      category: category ?? this.category,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      isFavorite: isFavorite ?? this.isFavorite,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
