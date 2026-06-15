class Fight {
  final String id;
  final String coupleId;
  final String authorId;
  final DateTime date;
  final String reason;
  final String? resolution;
  final String? reflection;
  final bool isResolved;
  final DateTime createdAt;

  const Fight({required this.id, required this.coupleId, required this.authorId, required this.date, required this.reason, this.resolution, this.reflection, this.isResolved = false, required this.createdAt});

  factory Fight.fromJson(Map<String, dynamic> json) => Fight(
    id: json['id'] as String? ?? '', coupleId: json['coupleId'] as String? ?? '', authorId: json['authorId'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(), reason: json['reason'] as String? ?? '',
    resolution: json['resolution'], reflection: json['reflection'],
    isResolved: json['isResolved'] ?? false, createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
