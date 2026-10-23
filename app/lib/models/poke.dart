/// "콕" 종류. [key] 는 서버의 KINDS 와 같아야 한다.
enum PokeKind {
  miss('miss', '보고싶어', 'missing'),
  love('love', '사랑해', 'love'),
  cheer('cheer', '힘내', 'excited'),
  thanks('thanks', '고마워', 'grateful'),
  sorry('sorry', '미안해', 'sad'),
  goodnight('goodnight', '잘 자', 'tired');

  final String key;
  final String label;

  /// 그림으로 보여줄 기분 얼굴 키(MoodFace).
  final String moodKey;

  const PokeKind(this.key, this.label, this.moodKey);

  static PokeKind fromKey(String? key) => PokeKind.values.firstWhere(
        (k) => k.key == key,
        orElse: () => PokeKind.miss,
      );
}
