import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/join_peer_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/add_question_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const InterviewPrepBuddyApp());
}

class InterviewPrepBuddyApp extends StatelessWidget {
  const InterviewPrepBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prep Buddy',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2346A0),
          brightness: Brightness.light,
        ),
        fontFamily: 'Arial',
      ),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        final uri = Uri.parse(name);

        final isJoinRoute =
            uri.path == '/join' ||
            (uri.scheme == 'interviewprepbuddy' && uri.host == 'join');

        final code = isJoinRoute ? (uri.queryParameters['code'] ?? '') : null;

        return MaterialPageRoute(
          builder: (_) => AppGate(pendingJoinCode: code),
        );
      },
    );
  }
}

class AppGate extends StatelessWidget {
  final String? pendingJoinCode;

  const AppGate({super.key, this.pendingJoinCode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return LoginScreen(pendingJoinCode: pendingJoinCode);
        }

        if (pendingJoinCode != null && pendingJoinCode!.isNotEmpty) {
          return JoinPeerScreen(code: pendingJoinCode!);
        }

        return const MainScreen();
      },
    );
  }
}

class Attempt {
  final String question;
  final String answer;
  final double score;
  final int wordCount;
  final int matchedKeywords;
  final int totalKeywords;
  final String weakArea;

  Attempt({
    required this.question,
    required this.answer,
    required this.score,
    required this.wordCount,
    required this.matchedKeywords,
    required this.totalKeywords,
    required this.weakArea,
  });
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final List<Attempt> attempts = [];

  void addAttempt(Attempt attempt) {
    setState(() {
      attempts.insert(0, attempt);
      selectedIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('questions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Prep Buddy'),
              actions: [
                IconButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: Center(
              child: Text('Questions load karne me error aaya: ${snapshot.error}'),
            ),
          );
        }

        final questions = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            "id": doc.id,
            "question": data["question"] ?? "",
            "type": data["type"] ?? "General",
            "keywords": List<String>.from(data["keywords"] ?? []),
          };
        }).toList();

        final screens = [
          HomeScreen(attempts: attempts),
          QuestionBankScreen(questions: questions),
          MockInterviewScreen(
            questions: questions,
            onSubmitAttempt: addAttempt,
          ),
          PerformanceScreen(attempts: attempts),
          const PeerPracticeScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Prep Buddy'),
            actions: [
              IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: screens[selectedIndex],
          bottomNavigationBar: NavigationBar(
            height: 72,
            selectedIndex: selectedIndex,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFDCE7FF),
            onDestinationSelected: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: "Home",
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: "Questions",
              ),
              NavigationDestination(
                icon: Icon(Icons.mic_none_outlined),
                selectedIcon: Icon(Icons.mic),
                label: "Mock",
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: "Analysis",
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: "Peers",
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  final List<Attempt> attempts;

  const HomeScreen({super.key, required this.attempts});

  double getAverageScore() {
    if (attempts.isEmpty) return 0;
    final total = attempts.fold<double>(0, (sum, item) => sum + item.score);
    return total / attempts.length;
  }

  int getWeakAreaCount() {
    return attempts.where((a) => a.weakArea != "Good performance").length;
  }

  String getAverageWords() {
    if (attempts.isEmpty) return "0";
    final total = attempts.fold<int>(0, (sum, item) => sum + item.wordCount);
    return (total / attempts.length).toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final avgScore = getAverageScore();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2346A0), Color(0xFF3B6CE1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Interview Prep Buddy",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Practice interviews, improve confidence, and track your actual performance.",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFDDE7FF),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: "Attempts",
                  value: "${attempts.length}",
                  colors: const [Color(0xFF4255C4), Color(0xFF5F74E6)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Confidence",
                  value: "${avgScore.toStringAsFixed(0)}%",
                  colors: const [Color(0xFF0F9D94), Color(0xFF14B8A6)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: "Weak Areas",
                  value: "${getWeakAreaCount()}",
                  colors: const [Color(0xFFFF6A3D), Color(0xFFFF8C42)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Avg Words",
                  value: getAverageWords(),
                  colors: const [Color(0xFF9229B8), Color(0xFFB245D1)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "Core Features",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 14),
          const FeatureTile(
            title: "Question Bank",
            subtitle: "HR aur Technical questions ko structured way me practice karo",
            icon: Icons.menu_book_rounded,
            iconBg: Color(0xFFE3EEFF),
            iconColor: Color(0xFF2B5EC9),
          ),
          const SizedBox(height: 12),
          const FeatureTile(
            title: "Mock Interview",
            subtitle: "Question select karke answer submit karo aur feedback lo",
            icon: Icons.mic_rounded,
            iconBg: Color(0xFFFFE7E2),
            iconColor: Color(0xFFE05A37),
          ),
          const SizedBox(height: 12),
          const FeatureTile(
            title: "Performance Analysis",
            subtitle: "Real attempts ke basis par score aur weak areas dekho",
            icon: Icons.bar_chart_rounded,
            iconBg: Color(0xFFE4F8F4),
            iconColor: Color(0xFF14967F),
          ),
          const SizedBox(height: 12),
          const FeatureTile(
            title: "Peer Practice",
            subtitle: "Friends ke saath interview practice connect mode me karo",
            icon: Icons.people_alt_rounded,
            iconBg: Color(0xFFFFF2DF),
            iconColor: Color(0xFFE39A1A),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final List<Color> colors;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 126,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const FeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF667085),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionBankScreen extends StatelessWidget {
  final List<Map<String, dynamic>> questions;

  const QuestionBankScreen({super.key, required this.questions});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Question Bank",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Firestore se synced HR aur Technical questions",
                        style: TextStyle(color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddQuestionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: questions.isEmpty
                  ? const Center(
                      child: Text('Abhi koi question available nahi hai.'),
                    )
                  : ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        final item = questions[index];
                        final isHr = item["type"] == "HR";

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
                          child: Row(
                            children: [
                              Container(
                                height: 52,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: isHr
                                      ? const Color(0xFFE7F0FF)
                                      : const Color(0xFFE8F7EC),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isHr
                                      ? Icons.person_outline
                                      : Icons.memory_rounded,
                                  color: isHr
                                      ? const Color(0xFF2F67D8)
                                      : const Color(0xFF2E9D57),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item["question"],
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1C2434),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item["type"],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

class MockInterviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Function(Attempt) onSubmitAttempt;

  const MockInterviewScreen({
    super.key,
    required this.questions,
    required this.onSubmitAttempt,
  });

  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen> {
  int selectedQuestionIndex = 0;
  final TextEditingController answerController = TextEditingController();

  Attempt analyzeAnswer({
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

    final double lengthScore =
    wordCount >= 30 ? 40.0 : (wordCount / 30) * 40.0;
    final double keywordScore = keywords.isEmpty
      ? 0.0
      : (matchedKeywords / keywords.length) * 60.0;
    final double finalScore = (lengthScore + keywordScore).toDouble();

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

    return Attempt(
      question: question,
      answer: answer,
      score: finalScore,
      wordCount: wordCount,
      matchedKeywords: matchedKeywords,
      totalKeywords: keywords.length,
      weakArea: weakArea,
    );
  }

  void submitAnswer() {
    if (widget.questions.isEmpty) return;

    final answer = answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please type your answer first.")),
      );
      return;
    }

    final selected = widget.questions[selectedQuestionIndex];
    final attempt = analyzeAnswer(
      question: selected["question"],
      answer: answer,
      keywords: List<String>.from(selected["keywords"]),
    );

    widget.onSubmitAttempt(attempt);
    answerController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Answer analyzed successfully")),
    );
  }

  @override
  void didUpdateWidget(covariant MockInterviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.questions.isNotEmpty &&
        selectedQuestionIndex >= widget.questions.length) {
      selectedQuestionIndex = 0;
    }
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const SafeArea(
        child: Center(
          child: Text(
            'Abhi koi question available nahi hai.\nPehle Question Bank me jaake question add karo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selected = widget.questions[selectedQuestionIndex];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text(
            "Mock Interview",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            "Question choose karo aur apna real answer submit karo",
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
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
            child: DropdownButtonFormField<int>(
              value: selectedQuestionIndex,
              decoration: const InputDecoration(
                labelText: "Select Question",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              items: List.generate(
                widget.questions.length,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text(widget.questions[index]["question"]),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  selectedQuestionIndex = value!;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected["type"] ?? "General",
                  style: const TextStyle(
                    color: Color(0xFFDCE7FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  selected["question"],
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: answerController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: "Type your answer here...",
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: submitAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2346A0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                "Submit Answer",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PerformanceScreen extends StatelessWidget {
  final List<Attempt> attempts;

  const PerformanceScreen({super.key, required this.attempts});

  double getAverageScore() {
    if (attempts.isEmpty) return 0;
    final total = attempts.fold<double>(0, (sum, item) => sum + item.score);
    return total / attempts.length;
  }

  String getTopWeakArea() {
    if (attempts.isEmpty) return "No data";
    final filtered = attempts.where((a) => a.weakArea != "Good performance").toList();
    if (filtered.isEmpty) return "None";

    final counts = <String, int>{};
    for (final item in filtered) {
      counts[item.weakArea] = (counts[item.weakArea] ?? 0) + 1;
    }

    String top = filtered.first.weakArea;
    int maxCount = 0;

    counts.forEach((key, value) {
      if (value > maxCount) {
        maxCount = value;
        top = key;
      }
    });

    return top;
  }

  @override
  Widget build(BuildContext context) {
    final bestScore = attempts.isEmpty
        ? 0.0
        : attempts.map((e) => e.score).reduce((a, b) => a > b ? a : b);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text(
            "Performance Analysis",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            "Real attempts ke basis par aapki performance summary",
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          InfoCard(title: "Total Attempts", value: "${attempts.length}", color: const Color(0xFF335CFF)),
          const SizedBox(height: 12),
          InfoCard(title: "Average Score", value: "${getAverageScore().toStringAsFixed(1)}%", color: const Color(0xFFFF8A3D)),
          const SizedBox(height: 12),
          InfoCard(title: "Best Score", value: "${bestScore.toStringAsFixed(1)}%", color: const Color(0xFF15A37D)),
          const SizedBox(height: 12),
          InfoCard(title: "Top Weak Area", value: getTopWeakArea(), color: const Color(0xFFE4583E)),
          const SizedBox(height: 18),
          if (attempts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                "Abhi tak koi attempt nahi hua. Mock Interview screen me jaakar answer submit karo.",
                style: TextStyle(fontSize: 15),
              ),
            ),
          if (attempts.isNotEmpty)
            ...attempts.map(
              (attempt) => Container(
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
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    attempt.question,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "Words: ${attempt.wordCount} | Keywords: ${attempt.matchedKeywords}/${attempt.totalKeywords}",
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                  ),
                  trailing: Text(
                    "${attempt.score.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2346A0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(Icons.analytics_rounded, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class PeerPracticeScreen extends StatefulWidget {
  const PeerPracticeScreen({super.key});

  @override
  State<PeerPracticeScreen> createState() => _PeerPracticeScreenState();
}

class _PeerPracticeScreenState extends State<PeerPracticeScreen> {
  String? ownerId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    initOwner();
  }

  Future<void> initOwner() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedOwnerId = prefs.getString('owner_id');

    if (savedOwnerId == null) {
      savedOwnerId = 'owner_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('owner_id', savedOwnerId);
    }

    setState(() {
      ownerId = savedOwnerId;
      loading = false;
    });
  }

  String generateCode() {
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    return millis.substring(millis.length - 6);
  }

  Future<void> addPerson() async {
    if (ownerId == null) return;

    final code = generateCode();

    await FirebaseFirestore.instance.collection('peer_invites').doc(code).set({
      'code': code,
      'ownerId': ownerId,
      'joinedName': null,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final link = 'https://interview-prep-buddy-1e370.web.app/join?code=$code';

    await Share.share(
      'Interview Prep Buddy me connect hone ke liye is link ko open karo:\n$link',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text(
            "Practice With Others",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add Person par click karo aur invite link share karo.",
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: addPerson,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("Add Person"),
            ),
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('peer_invites')
                .where('ownerId', isEqualTo: ownerId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data!.docs;

              final joinedDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'joined' && data['joinedName'] != null;
              }).toList();

              if (joinedDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Abhi koi peer connected nahi hai.",
                  ),
                );
              }

              return Column(
                children: joinedDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

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
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          child: Icon(Icons.person),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            data['joinedName'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
