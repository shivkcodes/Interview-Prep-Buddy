import 'package:flutter/material.dart';
import '../models/attempt_model.dart';
import 'result_screen.dart';

class HistoryScreen extends StatelessWidget {
  final List<AttemptModel> attempts;

  const HistoryScreen({
    super.key,
    required this.attempts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attempt History"),
      ),
      body: attempts.isEmpty
          ? const Center(
              child: Text("Abhi tak koi attempt nahi hua."),
            )
          : ListView.builder(
              itemCount: attempts.length,
              itemBuilder: (context, index) {
                final attempt = attempts[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(attempt.question),
                    subtitle: Text(
                      "Score: ${attempt.score.toStringAsFixed(1)} | Weak Area: ${attempt.weakArea}",
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(attempt: attempt),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
