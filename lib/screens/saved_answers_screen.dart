import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SavedAnswersScreen extends StatelessWidget {
  const SavedAnswersScreen({super.key});

  double calculateScore({
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

    final double lengthScore =
        wordCount >= 30 ? 40.0 : (wordCount / 30) * 40.0;

    final double keywordScore = keywords.isEmpty
        ? 0.0
        : (matchedKeywords / keywords.length) * 60.0;

    return (lengthScore + keywordScore).toDouble();
  }

  String calculateWeakArea({
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

    final score = calculateScore(answer: answer, keywords: keywords);

    if (wordCount < 10) {
      return "Answer bahut short hai";
    } else if (matchedKeywords < 2) {
      return "Relevant keywords kam hain";
    } else if (score < 60) {
      return "Clarity improve karo";
    } else {
      return "Good performance";
    }
  }

  Future<void> deleteAnswer({
    required BuildContext context,
    required String docId,
  }) async {
    await FirebaseFirestore.instance
        .collection('saved_answers')
        .doc(docId)
        .delete();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved answer deleted')),
    );
  }

  Future<void> editAnswer({
    required BuildContext context,
    required String docId,
    required String oldAnswer,
    required List<String> keywords,
  }) async {
    final controller = TextEditingController(text: oldAnswer);

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Saved Answer'),
              content: TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Update your answer',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final newAnswer = controller.text.trim();

                          if (newAnswer.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Answer empty nahi ho sakta'),
                              ),
                            );
                            return;
                          }

                          final normalizedAnswer = newAnswer.toLowerCase();

                          final wordCount = normalizedAnswer
                              .split(RegExp(r'\s+'))
                              .where((word) => word.isNotEmpty)
                              .length;

                          int matchedKeywords = 0;
                          for (final keyword in keywords) {
                            if (normalizedAnswer
                                .contains(keyword.toLowerCase())) {
                              matchedKeywords++;
                            }
                          }

                          final double lengthScore = wordCount >= 30
                              ? 40.0
                              : (wordCount / 30) * 40.0;

                          final double keywordScore = keywords.isEmpty
                              ? 0.0
                              : (matchedKeywords / keywords.length) * 60.0;

                          final double finalScore =
                              (lengthScore + keywordScore).toDouble();

                          String weakArea;
                          if (wordCount < 10) {
                            weakArea = "Answer bahut short hai";
                          } else if (matchedKeywords < 2) {
                            weakArea = "Relevant keywords kam hain";
                          } else if (finalScore < 60) {
                            weakArea = "Clarity improve karo";
                          } else {
                            weakArea = "Good performance";
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          await FirebaseFirestore.instance
                              .collection('saved_answers')
                              .doc(docId)
                              .update({
                            'answer': newAnswer,
                            'wordCount': wordCount,
                            'matchedKeywords': matchedKeywords,
                            'totalKeywords': keywords.length,
                            'score': finalScore,
                            'weakArea': weakArea,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (!context.mounted) return;

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved answer updated'),
                            ),
                          );
                        },
                  child: Text(saving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Saved Answers",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              "Yahan aap apne saved answers dekh, edit aur delete kar sakte ho",
              style: TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('saved_answers')
                    .where('userId', isEqualTo: user?.uid)
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Saved answers load nahi hue: ${snapshot.error}'),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Abhi tak koi saved answer nahi hai.\nMock screen me answer submit karo.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final question = data['question'] ?? '';
                      final answer = data['answer'] ?? '';
                      final score = data['score'] ?? 0;
                      final weakArea = data['weakArea'] ?? '';
                      final type = data['type'] ?? 'General';
                      final speechConfidence = (data['speechConfidence'] ?? 0).toDouble();
                      final keywords = List<String>.from(data['keywords'] ?? []);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1C2434),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Type: $type',
                              style: const TextStyle(color: Color(0xFF667085)),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              answer,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            Text(
                              'Score: ${score.toString()} | Weak Area: $weakArea',
                              style: const TextStyle(
                                color: Color(0xFF2346A0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Voice Accuracy: ${(speechConfidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      editAnswer(
                                        context: context,
                                        docId: doc.id,
                                        oldAnswer: answer,
                                        keywords: keywords,
                                      );
                                    },
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Edit'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      deleteAnswer(
                                        context: context,
                                        docId: doc.id,
                                      );
                                    },
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
