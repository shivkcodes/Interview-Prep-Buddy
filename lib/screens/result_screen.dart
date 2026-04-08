import 'package:flutter/material.dart';
import '../models/attempt_model.dart';

class ResultScreen extends StatelessWidget {
  final AttemptModel attempt;

  const ResultScreen({
    super.key,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analysis Result"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  attempt.question,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text("Your Answer:\n${attempt.answer}"),
                const SizedBox(height: 20),
                Text("Word Count: ${attempt.wordCount}"),
                Text(
                  "Matched Keywords: ${attempt.matchedKeywords} / ${attempt.totalKeywords}",
                ),
                Text("Score: ${attempt.score.toStringAsFixed(1)} / 100"),
                Text("Weak Area: ${attempt.weakArea}"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
