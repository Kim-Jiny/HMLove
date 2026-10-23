/// 일기 종류. 교환일기는 둘이 같은 공책에 쓰고, 개인일기는 쓴 사람만 본다.
enum DiaryKind {
  shared('SHARED'),
  private('PRIVATE');

  final String value;
  const DiaryKind(this.value);

  static DiaryKind fromValue(String? v) =>
      v == 'PRIVATE' ? DiaryKind.private : DiaryKind.shared;
}

/// 목록 탭. 서버의 scope 파라미터와 같다.
enum DiaryScope {
  shared('shared'),
  mine('mine');

  final String value;
  const DiaryScope(this.value);
}

class DiaryEntry {
  final String id;
  final String authorId;
  final String authorName;
  final DiaryKind kind;
  final DateTime entryDate;
  final String? mood;
  final String content;

  const DiaryEntry({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.kind,
    required this.entryDate,
    required this.mood,
    required this.content,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return DiaryEntry(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorName: author?['nickname'] as String? ?? '',
      kind: DiaryKind.fromValue(json['kind'] as String?),
      entryDate: DateTime.parse(json['entryDate'] as String).toLocal(),
      mood: json['mood'] as String?,
      content: json['content'] as String,
    );
  }
}
