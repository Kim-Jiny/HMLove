class Letter {
  final String id;
  final String coupleId;
  final String writerId;
  final String receiverId;
  final String title;
  final String content;
  final DateTime deliveryDate;
  final String status; // DRAFT, SCHEDULED, DELIVERED
  final bool isRead;
  final DateTime createdAt;

  const Letter({required this.id, required this.coupleId, required this.writerId, required this.receiverId, required this.title, required this.content, required this.deliveryDate, this.status = 'DRAFT', this.isRead = false, required this.createdAt});

  factory Letter.fromJson(Map<String, dynamic> json) => Letter(
    id: json['id'], coupleId: json['coupleId'], writerId: json['writerId'],
    receiverId: json['receiverId'], title: json['title'], content: json['content'] ?? '',
    deliveryDate: DateTime.parse(json['deliveryDate']),
    status: json['status'] ?? 'DRAFT', isRead: json['isRead'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );

  bool get isDelivered => status == 'DELIVERED';
  bool get canEdit => status != 'DELIVERED';
}
