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
    id: json['id'], coupleId: json['coupleId'], senderId: json['senderId'],
    content: json['content'], imageUrl: json['imageUrl'],
    isRead: json['isRead'] ?? false, createdAt: DateTime.parse(json['createdAt']),
    sender: json['sender'] != null ? MessageSender.fromJson(json['sender']) : null,
  );
}

class MessageSender {
  final String id;
  final String nickname;
  final String? profileImage;
  const MessageSender({required this.id, required this.nickname, this.profileImage});
  factory MessageSender.fromJson(Map<String, dynamic> json) => MessageSender(
    id: json['id'], nickname: json['nickname'], profileImage: json['profileImage'],
  );
}
