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
        'isCompleted': isCompleted,
        'completedBy': completedBy,
        'completedAt': completedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  WishItem copyWith({
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
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
