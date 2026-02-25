class User {
  final String id;
  final String email;
  final String nickname;
  final DateTime? birthDate;
  final String? profileImage;
  final String? mood;
  final String? coupleId;
  final bool isCoupleComplete;
  final bool hasExistingCoupleData;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.nickname,
    this.birthDate,
    this.profileImage,
    this.mood,
    this.coupleId,
    this.isCoupleComplete = false,
    this.hasExistingCoupleData = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      profileImage: json['profileImage'] as String?,
      mood: json['mood'] as String?,
      coupleId: json['coupleId'] as String?,
      isCoupleComplete: json['isCoupleComplete'] as bool? ?? false,
      hasExistingCoupleData: json['hasExistingCoupleData'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'birthDate': birthDate?.toIso8601String(),
      'profileImage': profileImage,
      'mood': mood,
      'coupleId': coupleId,
      'isCoupleComplete': isCoupleComplete,
      'hasExistingCoupleData': hasExistingCoupleData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? nickname,
    DateTime? birthDate,
    String? profileImage,
    String? mood,
    Object? coupleId = _sentinel,
    bool? isCoupleComplete,
    bool? hasExistingCoupleData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      birthDate: birthDate ?? this.birthDate,
      profileImage: profileImage ?? this.profileImage,
      mood: mood ?? this.mood,
      coupleId: coupleId == _sentinel ? this.coupleId : coupleId as String?,
      isCoupleComplete: isCoupleComplete ?? this.isCoupleComplete,
      hasExistingCoupleData: hasExistingCoupleData ?? this.hasExistingCoupleData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const _sentinel = Object();
}
