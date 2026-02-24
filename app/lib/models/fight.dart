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
    id: json['id'], coupleId: json['coupleId'], authorId: json['authorId'],
    date: DateTime.parse(json['date']), reason: json['reason'],
    resolution: json['resolution'], reflection: json['reflection'],
    isResolved: json['isResolved'] ?? false, createdAt: DateTime.parse(json['createdAt']),
  );
}
