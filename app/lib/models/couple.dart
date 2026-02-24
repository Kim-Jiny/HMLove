import 'user.dart';

class Couple {
  final String id;
  final String inviteCode;
  final DateTime startDate;
  final List<User> users;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Couple({
    required this.id,
    required this.inviteCode,
    required this.startDate,
    this.users = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Couple.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List<dynamic>?;
    return Couple(
      id: json['id'] as String,
      inviteCode: json['inviteCode'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      users: usersList != null
          ? usersList
              .map((e) => User.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inviteCode': inviteCode,
      'startDate': startDate.toIso8601String(),
      'users': users.map((u) => u.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Returns the number of days since the couple started dating.
  int get daysTogether {
    return DateTime.now().difference(startDate).inDays + 1;
  }

  /// Returns the partner user given the current user's ID.
  User? getPartner(String currentUserId) {
    for (final user in users) {
      if (user.id != currentUserId) return user;
    }
    return null;
  }

  Couple copyWith({
    String? id,
    String? inviteCode,
    DateTime? startDate,
    List<User>? users,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Couple(
      id: id ?? this.id,
      inviteCode: inviteCode ?? this.inviteCode,
      startDate: startDate ?? this.startDate,
      users: users ?? this.users,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
