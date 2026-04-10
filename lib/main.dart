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
import 'screens/saved_answers_screen.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'screens/profile_screen.dart';
import 'screens/peer_detail_screen.dart';

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

class AppGate extends StatefulWidget {
  final String? pendingJoinCode;

  const AppGate({super.key, this.pendingJoinCode});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool hasShownInstallMessage = false;

  @override
  void initState() {
    super.initState();
    checkFirstLaunchMessage();
  }

  Future<void> checkFirstLaunchMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenInstallMessage =
        prefs.getBool('has_seen_peer_install_message') ?? false;

    if (!hasSeenInstallMessage) {
      await prefs.setBool('has_seen_peer_install_message', true);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Peer Connection'),
              content: const Text(
                'Tap the link again to connect with your peer.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      });
    }

    if (mounted) {
      setState(() {
        hasShownInstallMessage = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasShownInstallMessage) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
          return LoginScreen(pendingJoinCode: widget.pendingJoinCode);
        }

        if (widget.pendingJoinCode != null &&
            widget.pendingJoinCode!.isNotEmpty) {
          return JoinPeerScreen(code: widget.pendingJoinCode!);
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
      selectedIndex = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

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
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            final userName = currentUser?.displayName ?? 'User';
            final userEmail = currentUser?.email ?? '';
            final userPhoto = currentUser?.photoURL;
            final initial = userName.isNotEmpty
                ? userName.trim().substring(0, 1).toUpperCase()
                : 'U';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFE8EEFF),
                      backgroundImage:
                          userPhoto != null ? NetworkImage(userPhoto) : null,
                      child: userPhoto == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2346A0),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C2434),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Open Profile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE4583E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFDCE7FF),
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE8EEFF),
          backgroundImage: currentUser?.photoURL != null
              ? NetworkImage(currentUser!.photoURL!)
              : null,
          child: currentUser?.photoURL == null
              ? Text(
                  (currentUser?.displayName?.isNotEmpty ?? false)
                      ? currentUser!.displayName!
                          .trim()
                          .substring(0, 1)
                          .toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2346A0),
                  ),
                )
              : null,
        ),
      ),
    ),
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
          const SavedAnswersScreen(),
          const PerformanceScreen(),
          const PeerPracticeScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Prep Buddy'),
            actions: [
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            final userName = currentUser?.displayName ?? 'User';
            final userEmail = currentUser?.email ?? '';
            final userPhoto = currentUser?.photoURL;
            final initial = userName.isNotEmpty
                ? userName.trim().substring(0, 1).toUpperCase()
                : 'U';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 18),
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFE8EEFF),
                      backgroundImage:
                          userPhoto != null ? NetworkImage(userPhoto) : null,
                      child: userPhoto == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2346A0),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C2434),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Open Profile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context)
                              .pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE4583E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFDCE7FF),
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE8EEFF),
          backgroundImage: currentUser?.photoURL != null
              ? NetworkImage(currentUser!.photoURL!)
              : null,
          child: currentUser?.photoURL == null
              ? Text(
                  (currentUser?.displayName?.isNotEmpty ?? false)
                      ? currentUser!.displayName!
                          .trim()
                          .substring(0, 1)
                          .toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2346A0),
                  ),
                )
              : null,
        ),
      ),
    ),
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
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: "Saved",
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

  final SpeechToText speechToText = SpeechToText();
  bool speechEnabled = false;
  bool isListening = false;
  double speechConfidence = 0.0;
  String speechStatus = 'Mic ready';

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  Future<void> initSpeech() async {
    speechEnabled = await speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() {
          speechStatus = status;
          isListening = speechToText.isListening;
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          speechStatus = error.errorMsg;
          isListening = false;
        });
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  void startListening() async {
    if (!speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition available nahi hai')),
      );
      return;
    }

    await speechToText.listen(
      partialResults: true,
      onResult: onSpeechResult,
    );

    if (!mounted) return;

    setState(() {
      isListening = true;
      speechStatus = 'Listening...';
    });
  }

  void stopListening() async {
    await speechToText.stop();

    if (!mounted) return;

    setState(() {
      isListening = false;
      speechStatus = 'Stopped';
    });
  }

  void onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      answerController.text = result.recognizedWords;
      answerController.selection = TextSelection.fromPosition(
        TextPosition(offset: answerController.text.length),
      );

      if (result.hasConfidenceRating && result.confidence > 0) {
        speechConfidence = result.confidence;
      }
    });
  }

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

  Future<void> saveAnswerToFirestore({
    required Map<String, dynamic> selectedQuestion,
    required Attempt attempt,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('saved_answers').add({
      'userId': user?.uid,
      'userEmail': user?.email,
      'question': selectedQuestion['question'],
      'type': selectedQuestion['type'],
      'keywords': List<String>.from(selectedQuestion['keywords']),
      'answer': attempt.answer,
      'score': attempt.score,
      'wordCount': attempt.wordCount,
      'matchedKeywords': attempt.matchedKeywords,
      'totalKeywords': attempt.totalKeywords,
      'weakArea': attempt.weakArea,
      'speechConfidence': speechConfidence,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitAnswer() async {
    if (widget.questions.isEmpty) return;

    final answer = answerController.text.trim();
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please type or speak your answer first.")),
      );
      return;
    }

    final selected = widget.questions[selectedQuestionIndex];
    final attempt = analyzeAnswer(
      question: selected["question"],
      answer: answer,
      keywords: List<String>.from(selected["keywords"]),
    );

    await saveAnswerToFirestore(
      selectedQuestion: selected,
      attempt: attempt,
    );

    widget.onSubmitAttempt(attempt);

    answerController.clear();

    if (!mounted) return;

    setState(() {
      speechConfidence = 0.0;
      speechStatus = 'Mic ready';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Answer analyzed and saved successfully")),
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
    speechToText.stop();
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
            "Question choose karo, answer type karo ya mic se bolo",
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
              hintText: "Type your answer here or use mic...",
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isListening ? stopListening : startListening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isListening ? Colors.red : const Color(0xFF2346A0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(isListening ? Icons.stop : Icons.mic),
                  label: Text(isListening ? "Stop Mic" : "Start Mic"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mic Status: $speechStatus",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Voice Accuracy: ${(speechConfidence * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
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
                "Analyze & Save Answer",
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
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
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
              child: Text(
                'Performance data load nahi hui: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
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

          final savedAnswers = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'question': data['question'] ?? '',
              'answer': data['answer'] ?? '',
              'type': data['type'] ?? 'General',
              'score': (data['score'] ?? 0).toDouble(),
              'wordCount': data['wordCount'] ?? 0,
              'matchedKeywords': data['matchedKeywords'] ?? 0,
              'totalKeywords': data['totalKeywords'] ?? 0,
              'weakArea': data['weakArea'] ?? 'No data',
              'speechConfidence': (data['speechConfidence'] ?? 0).toDouble(),
            };
          }).toList();

          final totalAttempts = savedAnswers.length;

          final totalScore = savedAnswers.fold<double>(
            0,
            (sum, item) => sum + (item['score'] as double),
          );

          final averageScore = totalScore / totalAttempts;

          final bestScore = savedAnswers
              .map((e) => e['score'] as double)
              .reduce((a, b) => a > b ? a : b);

          final weakAreaCount = <String, int>{};
          for (final item in savedAnswers) {
            final weakArea = item['weakArea'] as String;
            if (weakArea != 'Good performance') {
              weakAreaCount[weakArea] = (weakAreaCount[weakArea] ?? 0) + 1;
            }
          }

          String topWeakArea = 'None';
          int maxCount = 0;
          weakAreaCount.forEach((key, value) {
            if (value > maxCount) {
              maxCount = value;
              topWeakArea = key;
            }
          });

          return _PerformanceContent(
            savedAnswers: savedAnswers,
            totalAttempts: totalAttempts,
            averageScore: averageScore,
            bestScore: bestScore,
            topWeakArea: topWeakArea,
          );
        },
      ),
    );
  }
}

class _PerformanceContent extends StatefulWidget {
  final List<Map<String, dynamic>> savedAnswers;
  final int totalAttempts;
  final double averageScore;
  final double bestScore;
  final String topWeakArea;

  const _PerformanceContent({
    required this.savedAnswers,
    required this.totalAttempts,
    required this.averageScore,
    required this.bestScore,
    required this.topWeakArea,
  });

  @override
  State<_PerformanceContent> createState() => _PerformanceContentState();
}

class _PerformanceContentState extends State<_PerformanceContent> {
  int selectedAnswerIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (selectedAnswerIndex >= widget.savedAnswers.length) {
      selectedAnswerIndex = 0;
    }

    final selected = widget.savedAnswers[selectedAnswerIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const Text(
          "Performance Analysis",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          "Top par overall report aur neeche selected question ki individual report",
          style: TextStyle(color: Color(0xFF667085)),
        ),
        const SizedBox(height: 18),
        const Text(
          "Overall Performance",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2434),
          ),
        ),
        const SizedBox(height: 14),
        InfoCard(
          title: "Total Saved Answers",
          value: "${widget.totalAttempts}",
          color: const Color(0xFF335CFF),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: "Average Score",
          value: "${widget.averageScore.toStringAsFixed(1)}%",
          color: const Color(0xFFFF8A3D),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: "Best Score",
          value: "${widget.bestScore.toStringAsFixed(1)}%",
          color: const Color(0xFF15A37D),
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: "Top Weak Area",
          value: widget.topWeakArea,
          color: const Color(0xFFE4583E),
        ),
        const SizedBox(height: 24),
        const Text(
          "Individual Question Report",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C2434),
          ),
        ),
        const SizedBox(height: 14),
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
            value: selectedAnswerIndex,
            decoration: const InputDecoration(
              labelText: "Select Saved Answer",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            items: List.generate(
              widget.savedAnswers.length,
              (index) => DropdownMenuItem(
                value: index,
                child: Text(widget.savedAnswers[index]['question']),
              ),
            ),
            onChanged: (value) {
              setState(() {
                selectedAnswerIndex = value!;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected['question'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C2434),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Type: ${selected['type']}",
                style: const TextStyle(color: Color(0xFF667085)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Your Answer",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selected['answer'],
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              InfoCard(
                title: "Score",
                value: "${(selected['score'] as double).toStringAsFixed(1)}%",
                color: const Color(0xFF2346A0),
              ),
              const SizedBox(height: 12),
              InfoCard(
                title: "Word Count",
                value: "${selected['wordCount']}",
                color: const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              InfoCard(
                title: "Keyword Match",
                value:
                    "${selected['matchedKeywords']}/${selected['totalKeywords']}",
                color: const Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              InfoCard(
                title: "Weak Area",
                value: selected['weakArea'],
                color: const Color(0xFFF97316),
              ),
              const SizedBox(height: 12),
              InfoCard(
                title: "Voice Accuracy",
                value: "${((selected['speechConfidence'] as double) * 100).toStringAsFixed(1)}%",
                color: const Color(0xFF06B6D4),
              ),
            ],
          ),
        ),
      ],
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
  bool loading = true;
  String? currentUserId;
  String currentUserName = '';

  @override
  void initState() {
    super.initState();
    initUser();
  }

  Future<void> initUser() async {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      currentUserId = user?.uid;
      currentUserName = user?.displayName ?? user?.email ?? 'User';
      loading = false;
    });
  }

  String generateCode() {
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    return millis.substring(millis.length - 6);
  }

  Future<void> addPerson() async {
    if (currentUserId == null) return;

    final code = generateCode();

    await FirebaseFirestore.instance.collection('peer_invites').doc(code).set({
      'code': code,
      'ownerId': currentUserId,
      'ownerName': currentUserName,
      'joinedUserId': null,
      'joinedName': null,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final link = 'https://interview-prep-buddy-1e370.web.app/join?code=$code';

    await Share.share(
      'Prep Buddy me connect hone ke liye is link ko open karo:\n$link',
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
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data!.docs;

              final connectedDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'joined' &&
                    (
                      data['ownerId'] == currentUserId ||
                      data['joinedUserId'] == currentUserId
                    );
              }).toList();

              if (connectedDocs.isEmpty) {
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
                children: connectedDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final bool amOwner = data['ownerId'] == currentUserId;

                  final String peerName = amOwner
                      ? (data['joinedName'] ?? 'Unknown Peer')
                      : (data['ownerName'] ?? 'Unknown Peer');

                  final String peerRole = amOwner
                      ? 'Connected Peer'
                      : 'Peer Who Invited You';

                  final String peerUserId = amOwner
    ? (data['joinedUserId'] ?? '')
    : (data['ownerId'] ?? '');

return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('profiles')
      .doc(peerUserId)
      .get(),
  builder: (context, profileSnapshot) {
    final profileData =
        profileSnapshot.data?.data() as Map<String, dynamic>?;

    final peerPhotoUrl = profileData?['photoUrl'] ?? '';
    final peerLocalPhotoPath = profileData?['localPhotoPath'] ?? '';

    return GestureDetector(
      onTap: () {
        if (peerUserId.toString().isEmpty) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PeerDetailScreen(
              peerUserId: peerUserId,
              peerName: peerName,
            ),
          ),
        );
      },
      child: Container(
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
            CircleAvatar(
              radius: 24,
              backgroundImage: peerPhotoUrl.toString().isNotEmpty
                  ? NetworkImage(peerPhotoUrl)
                  : null,
              child: peerPhotoUrl.toString().isEmpty
                  ? Text(
                      peerName.isNotEmpty
                          ? peerName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peerRole,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  },
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
