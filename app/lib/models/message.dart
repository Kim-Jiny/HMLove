class Message {
  final String id;
  final String coupleId;
  final String senderId;
  final String? content;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;
  final MessageSender? sender;

  const Message({required this.id, required this.coupleId, required this.senderId, this.content, this.imageUrl, this.isRead = false, required this.createdAt, this.sender});

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String? ?? '', coupleId: json['coupleId'] as String? ?? '', senderId: json['senderId'] as String? ?? '',
    content: json['content'], imageUrl: json['imageUrl'],
    isRead: json['isRead'] ?? false, createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    sender: json['sender'] is Map<String, dynamic> ? MessageSender.fromJson(json['sender'] as Map<String, dynamic>) : null,
  );
}

class MessageSender {
  final String id;
  final String nickname;
  final String? profileImage;
  const MessageSender({required this.id, required this.nickname, this.profileImage});
  factory MessageSender.fromJson(Map<String, dynamic> json) => MessageSender(
    id: json['id'] as String? ?? '', nickname: json['nickname'] as String? ?? '', profileImage: json['profileImage'],
  );
}
