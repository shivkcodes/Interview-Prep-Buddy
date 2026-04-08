class AttemptModel {
  final String question;
  final String answer;
  final int wordCount;
  final int matchedKeywords;
  final int totalKeywords;
  final double score;
  final String weakArea;
  final DateTime createdAt;

  AttemptModel({
    required this.question,
    required this.answer,
    required this.wordCount,
    required this.matchedKeywords,
    required this.totalKeywords,
    required this.score,
    required this.weakArea,
    required this.createdAt,
  });
}
