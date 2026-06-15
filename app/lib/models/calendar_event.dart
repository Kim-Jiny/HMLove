class CalendarEvent {
  final String id;
  final String coupleId;
  final String authorId;
  final String title;
  final String? description;
  final DateTime date;
  final bool isAnniversary;
  final String repeatType; // NONE, YEARLY, MONTHLY
  final String? color;
  final DateTime createdAt;

  const CalendarEvent({required this.id, required this.coupleId, required this.authorId, required this.title, this.description, required this.date, this.isAnniversary = false, this.repeatType = 'NONE', this.color, required this.createdAt});

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String? ?? '', coupleId: json['coupleId'] as String? ?? '', authorId: json['authorId'] as String? ?? '',
    title: json['title'] as String? ?? '', description: json['description'],
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(), isAnniversary: json['isAnniversary'] ?? false,
    repeatType: json['repeatType'] ?? 'NONE', color: json['color'],
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
