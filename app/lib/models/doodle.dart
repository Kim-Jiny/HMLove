class Doodle {
  final String id;
  final String coupleId;
  final String senderId;
  final String senderNickname;
  final String receiverId;
  final String receiverNickname;
  final String imageUrl;
  final DateTime createdAt;

  const Doodle({
    required this.id,
    required this.coupleId,
    required this.senderId,
    required this.senderNickname,
    required this.receiverId,
    required this.receiverNickname,
    required this.imageUrl,
    required this.createdAt,
  });

  factory Doodle.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    final receiver = json['receiver'] as Map<String, dynamic>?;
    return Doodle(
      id: json['id'] as String? ?? '',
      coupleId: json['coupleId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? sender?['id'] as String? ?? '',
      senderNickname: sender?['nickname'] as String? ?? '',
      receiverId:
          json['receiverId'] as String? ?? receiver?['id'] as String? ?? '',
      receiverNickname: receiver?['nickname'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
