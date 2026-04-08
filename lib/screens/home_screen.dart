import 'package:flutter/material.dart';
import '../models/attempt_model.dart';
import '../utils/answer_analyzer.dart';
import 'history_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController answerController = TextEditingController();

  final List<Map<String, dynamic>> questions = [
    {
      "question": "Tell me about yourself",
      "keywords": ["student", "skills", "project", "goal"],
    },
    {
      "question": "What are your strengths?",
      "keywords": ["hardworking", "teamwork", "problem solving", "communication"],
    },
    {
      "question": "Why should we hire you?",
      "keywords": ["skills", "value", "company", "contribution"],
    },
  ];

  int selectedQuestionIndex = 0;
  final List<AttemptModel> attempts = [];

  void analyzeAnswer() {
    final answer = answerController.text.trim();

    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your answer first.")),
      );
      return;
    }

    final selectedQuestion = questions[selectedQuestionIndex];

    final attempt = AnswerAnalyzer.analyze(
      question: selectedQuestion["question"],
      answer: answer,
      keywords: List<String>.from(selectedQuestion["keywords"]),
    );

    setState(() {
      attempts.insert(0, attempt);
    });

    answerController.clear();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(attempt: attempt),
      ),
    );
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = questions[selectedQuestionIndex]["question"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Interview Prep Buddy"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(attempts: attempts),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Choose Interview Question",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: selectedQuestionIndex,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                questions.length,
                (index) => DropdownMenuItem<int>(
                  value: index,
                  child: Text(questions[index]["question"]),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  selectedQuestionIndex = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              "Question: $currentQuestion",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: answerController,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: "Apna answer yahan type karo...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: analyzeAnswer,
              child: const Text("Analyze My Answer"),
            ),
          ],
        ),
      ),
    );
  }
}
