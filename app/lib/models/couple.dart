import 'user.dart';

class Couple {
  final String id;
  final String inviteCode;
  final DateTime startDate;

  /// 상대가 연결되기 전에 미리 적어둔 이름/애칭.
  final String? pendingPartnerName;
  final List<User> users;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Couple({
    required this.id,
    required this.inviteCode,
    required this.startDate,
    this.pendingPartnerName,
    this.users = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Couple.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List<dynamic>?;
    return Couple(
      id: json['id'] as String,
      inviteCode: json['inviteCode'] as String,
      startDate: DateTime.parse(json['startDate'] as String).toLocal(),
      pendingPartnerName: json['pendingPartnerName'] as String?,
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
      'pendingPartnerName': pendingPartnerName,
      'users': users.map((u) => u.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Returns the number of days since the couple started dating.
  int get daysTogether {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.difference(start).inDays + 1;
  }

  /// Returns the partner user given the current user's ID.
  User? getPartner(String currentUserId) {
    for (final user in users) {
      if (user.id != currentUserId) return user;
    }
    return null;
  }

  /// 화면에 보여줄 상대 이름: 연결된 상대의 닉네임 > 미리 적어둔 애칭 > [fallback].
  String partnerDisplayName(String currentUserId, {String fallback = '상대방'}) {
    // 내 id 를 아직 모르면(로그인 직후 등) users 에서 '상대'를 고르지 않는다.
    // 그러면 첫 번째 멤버인 내 이름이 상대 이름으로 잡힌다.
    final partner = currentUserId.isEmpty ? null : getPartner(currentUserId);
    return partner?.nickname ?? pendingPartnerName ?? fallback;
  }

  Couple copyWith({
    String? id,
    String? inviteCode,
    DateTime? startDate,
    String? pendingPartnerName,
    List<User>? users,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Couple(
      id: id ?? this.id,
      inviteCode: inviteCode ?? this.inviteCode,
      startDate: startDate ?? this.startDate,
      pendingPartnerName: pendingPartnerName ?? this.pendingPartnerName,
      users: users ?? this.users,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
