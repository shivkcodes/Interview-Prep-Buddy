import '../models/attempt_model.dart';

class AnswerAnalyzer {
  static AttemptModel analyze({
    required String question,
    required String answer,
    required List<String> keywords,
  }) {
    final normalizedAnswer = answer.trim().toLowerCase();

    final wordCount = normalizedAnswer
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    int matchedKeywords = 0;
    for (final keyword in keywords) {
      if (normalizedAnswer.contains(keyword.toLowerCase())) {
        matchedKeywords++;
      }
    }

    double lengthScore = 0;
    if (wordCount >= 30) {
      lengthScore = 40;
    } else {
      lengthScore = (wordCount / 30) * 40;
    }

    final keywordScore = (matchedKeywords / keywords.length) * 60;
    final finalScore = lengthScore + keywordScore;

    String weakArea;
    if (wordCount < 10) {
      weakArea = "Answer bahut short hai";
    } else if (matchedKeywords < 2) {
      weakArea = "Relevant keywords aur concepts add karo";
    } else if (finalScore < 60) {
      weakArea = "Answer me structure aur clarity improve karo";
    } else {
      weakArea = "Good performance";
    }

    return AttemptModel(
      question: question,
      answer: answer,
      wordCount: wordCount,
      matchedKeywords: matchedKeywords,
      totalKeywords: keywords.length,
      score: finalScore,
      weakArea: weakArea,
      createdAt: DateTime.now(),
    );
  }
}
