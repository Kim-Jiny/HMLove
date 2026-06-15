class QuestionAnswer {
  final String id;
  final String userId;
  final String answer;
  final DateTime createdAt;

  const QuestionAnswer({
    required this.id,
    required this.userId,
    required this.answer,
    required this.createdAt,
  });

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) {
    return QuestionAnswer(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class DailyQuestion {
  final String id;
  final int questionIdx;
  final String questionText;
  final String date;
  final QuestionAnswer? myAnswer;
  final QuestionAnswer? partnerAnswer;
  final bool partnerAnswered; // 파트너가 답변했지만 공개 전
  final bool bothAnswered;
  final bool canReveal;

  const DailyQuestion({
    required this.id,
    required this.questionIdx,
    required this.questionText,
    required this.date,
    this.myAnswer,
    this.partnerAnswer,
    this.partnerAnswered = false,
    required this.bothAnswered,
    required this.canReveal,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) {
    // 파트너 답변 파싱: { answered: true } 이면 답변했지만 미공개
    QuestionAnswer? partnerAnswer;
    bool partnerAnswered = false;
    final partnerRaw = json['partnerAnswer'];
    if (partnerRaw is Map<String, dynamic>) {
      if (partnerRaw.containsKey('answer')) {
        partnerAnswer = QuestionAnswer.fromJson(partnerRaw);
      } else if (partnerRaw['answered'] == true) {
        partnerAnswered = true;
      }
    }

    return DailyQuestion(
      id: json['id'] as String? ?? '',
      questionIdx: (json['questionIdx'] as num?)?.toInt() ?? 0,
      questionText: json['questionText'] as String? ?? '',
      date: json['date'] as String? ?? '',
      myAnswer: json['myAnswer'] is Map<String, dynamic>
          ? QuestionAnswer.fromJson(json['myAnswer'] as Map<String, dynamic>)
          : null,
      partnerAnswer: partnerAnswer,
      partnerAnswered: partnerAnswered,
      bothAnswered: json['bothAnswered'] as bool? ?? false,
      canReveal: json['canReveal'] as bool? ?? false,
    );
  }
}

class QuestionHistoryItem {
  final String id;
  final int questionIdx;
  final String questionText;
  final String date;
  final QuestionAnswer? myAnswer;
  final QuestionAnswer? partnerAnswer;
  final bool partnerAnswered; // 파트너가 답변했지만 미공개
  final bool bothAnswered;

  const QuestionHistoryItem({
    required this.id,
    required this.questionIdx,
    required this.questionText,
    required this.date,
    this.myAnswer,
    this.partnerAnswer,
    this.partnerAnswered = false,
    required this.bothAnswered,
  });

  factory QuestionHistoryItem.fromJson(Map<String, dynamic> json) {
    QuestionAnswer? partnerAnswer;
    bool partnerAnswered = false;
    final partnerRaw = json['partnerAnswer'];
    if (partnerRaw is Map<String, dynamic>) {
      if (partnerRaw.containsKey('answer')) {
        partnerAnswer = QuestionAnswer.fromJson(partnerRaw);
      } else if (partnerRaw['answered'] == true) {
        partnerAnswered = true;
      }
    }

    return QuestionHistoryItem(
      id: json['id'] as String? ?? '',
      questionIdx: (json['questionIdx'] as num?)?.toInt() ?? 0,
      questionText: json['questionText'] as String? ?? '',
      date: json['date'] as String? ?? '',
      myAnswer: json['myAnswer'] is Map<String, dynamic>
          ? QuestionAnswer.fromJson(json['myAnswer'] as Map<String, dynamic>)
          : null,
      partnerAnswer: partnerAnswer,
      partnerAnswered: partnerAnswered,
      bothAnswered: json['bothAnswered'] as bool? ?? false,
    );
  }
}
