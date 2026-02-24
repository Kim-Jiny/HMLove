class Feed {
  final String id;
  final String coupleId;
  final String authorId;
  final String content;
  final String? imageUrl;
  final String type; // DIARY, PHOTO, MILESTONE
  final DateTime createdAt;
  final FeedAuthor? author;

  const Feed({required this.id, required this.coupleId, required this.authorId, required this.content, this.imageUrl, this.type = 'DIARY', required this.createdAt, this.author});

  factory Feed.fromJson(Map<String, dynamic> json) => Feed(
    id: json['id'], coupleId: json['coupleId'], authorId: json['authorId'],
    content: json['content'], imageUrl: json['imageUrl'], type: json['type'] ?? 'DIARY',
    createdAt: DateTime.parse(json['createdAt']),
    author: json['author'] != null ? FeedAuthor.fromJson(json['author']) : null,
  );
}

class FeedAuthor {
  final String id;
  final String nickname;
  final String? profileImage;
  const FeedAuthor({required this.id, required this.nickname, this.profileImage});
  factory FeedAuthor.fromJson(Map<String, dynamic> json) => FeedAuthor(
    id: json['id'], nickname: json['nickname'], profileImage: json['profileImage'],
  );
}
