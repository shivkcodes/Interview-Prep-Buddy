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
import 'app_settings.dart';
import 'screens/profile_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppSettings.load();
  runApp(const InterviewPrepBuddyApp());
}

class InterviewPrepBuddyApp extends StatelessWidget {
  const InterviewPrepBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeModeNotifier,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: AppSettings.textScaleNotifier,
          builder: (context, textScale, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Prep Buddy',
              themeMode: themeMode,
              theme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFFF4F7FB),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2346A0),
                  brightness: Brightness.light,
                ),
                fontFamily: 'Arial',
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF0F172A),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF7EA1FF),
                  brightness: Brightness.dark,
                ),
                fontFamily: 'Arial',
              ),
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: child!,
                );
              },
              onGenerateRoute: (settings) {
                final name = settings.name ?? '/';
                final uri = Uri.parse(name);

                final isJoinRoute =
                    uri.path == '/join' ||
                    (uri.scheme == 'interviewprepbuddy' &&
                        uri.host == 'join');

                final code =
                    isJoinRoute ? (uri.queryParameters['code'] ?? '') : null;

                return MaterialPageRoute(
                  builder: (_) => AppGate(pendingJoinCode: code),
                );
              },
            );
          },
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

return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('profiles')
      .doc(user.uid)
      .get(),
  builder: (context, profileSnapshot) {
    if (profileSnapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileData =
        profileSnapshot.data?.data() as Map<String, dynamic>?;

    final onboardingCompleted =
        profileData?['onboardingCompleted'] == true;

    if (!onboardingCompleted) {
      return ProfileSetupScreen(
        pendingJoinCode: widget.pendingJoinCode,
      );
    }

    if (widget.pendingJoinCode != null &&
        widget.pendingJoinCode!.isNotEmpty) {
      return JoinPeerScreen(code: widget.pendingJoinCode!);
    }

    return const MainScreen();
  },
);
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
  final double voiceAccuracy;

  Attempt({
    required this.question,
    required this.answer,
    required this.score,
    required this.wordCount,
    required this.matchedKeywords,
    required this.totalKeywords,
    required this.weakArea,
    required this.voiceAccuracy,
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
  int titleAnimationTick = 0;

  void addAttempt(Attempt attempt) {
    setState(() {
      attempts.insert(0, attempt);
      selectedIndex = 4;
    });
  }

  void triggerTitleAnimation() {
  setState(() {
    titleAnimationTick++;
  });
}

Widget buildAnimatedTitle() {
  return GestureDetector(
    onTap: triggerTitleAnimation,
    child: TweenAnimationBuilder<double>(
      key: ValueKey(titleAnimationTick),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (context, value, child) {
        final wave = sin(value * pi);

        return Transform.rotate(
          angle: wave * 0.06,
          child: Transform.scale(
            scale: 1 + (wave * 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2346A0), Color(0xFF4D7BFF)],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2346A0).withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: wave * 0.5,
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Prep Buddy',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
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
              title: buildAnimatedTitle(),
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
          HomeScreen(
  attempts: attempts,
  onOpenTab: (index) {
    setState(() {
      selectedIndex = index;
    });
  },
),
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
            title: buildAnimatedTitle(),
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
  final void Function(int) onOpenTab;

  const HomeScreen({
    super.key,
    required this.attempts,
    required this.onOpenTab,
  });

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

  double getAverageVoiceAccuracy() {
    if (attempts.isEmpty) return 0;
    final total = attempts.fold<double>(
      0,
      (sum, item) => sum + item.voiceAccuracy,
    );
    return total / attempts.length;
  }

  @override
  Widget build(BuildContext context) {
    final avgScore = getAverageScore();
    final avgVoice = getAverageVoiceAccuracy();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF18357E), Color(0xFF2346A0), Color(0xFF4D7BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2346A0).withOpacity(0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Interview Prep Buddy",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Practice smarter, track your speaking confidence, improve weak areas, and grow with real peer-based interview preparation.",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFDDE7FF),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _heroChip("Mock Practice"),
                    _heroChip("Voice Input"),
                    _heroChip("Saved Answers"),
                    _heroChip("Peer Connect"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Performance Snapshot",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap any card to jump into the relevant section.",
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: "Attempts",
                  value: "${attempts.length}",
                  colors: const [Color(0xFF4255C4), Color(0xFF5F74E6)],
                  icon: Icons.flag_rounded,
                  onTap: () => onOpenTab(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Confidence",
                  value: "${avgScore.toStringAsFixed(0)}%",
                  colors: const [Color(0xFF0F9D94), Color(0xFF14B8A6)],
                  icon: Icons.psychology_alt_rounded,
                  onTap: () => onOpenTab(4),
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
                  icon: Icons.warning_amber_rounded,
                  onTap: () => onOpenTab(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: "Avg Words",
                  value: getAverageWords(),
                  colors: const [Color(0xFF9229B8), Color(0xFFB245D1)],
                  icon: Icons.notes_rounded,
                  onTap: () => onOpenTab(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatCard(
            title: "Voice Accuracy",
            value: "${avgVoice.toStringAsFixed(1)}%",
            colors: const [Color(0xFF0D8ABC), Color(0xFF35B6E8)],
            icon: Icons.graphic_eq_rounded,
            onTap: () => onOpenTab(4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Why This Dashboard Matters",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "This home page is your quick overview. You can jump directly into practice, check your analysis, review saved work, or continue peer collaboration from here.",
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Core Features",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Each feature is designed to support a different part of your interview preparation journey.",
            style: TextStyle(color: Color(0xFF667085), height: 1.5),
          ),
          const SizedBox(height: 14),
          FeatureTile(
            title: "Question Bank",
            subtitle:
                "Explore interview questions in one place and prepare systematically with structured practice.",
            icon: Icons.menu_book_rounded,
            iconBg: const Color(0xFFE3EEFF),
            iconColor: const Color(0xFF2B5EC9),
            onTap: () => onOpenTab(1),
          ),
          const SizedBox(height: 12),
          FeatureTile(
            title: "Mock Interview",
            subtitle:
                "Practice answers by typing or speaking and build more natural, interview-ready responses.",
            icon: Icons.mic_rounded,
            iconBg: const Color(0xFFFFE7E2),
            iconColor: const Color(0xFFE05A37),
            onTap: () => onOpenTab(2),
          ),
          const SizedBox(height: 12),
          FeatureTile(
            title: "Saved Answers",
            subtitle:
                "Keep your best answers in one place so you can review, edit, and refine them later.",
            icon: Icons.bookmark_rounded,
            iconBg: const Color(0xFFE8F1FF),
            iconColor: const Color(0xFF2346A0),
            onTap: () => onOpenTab(3),
          ),
          const SizedBox(height: 12),
          FeatureTile(
            title: "Performance Analysis",
            subtitle:
                "Track score, weak areas, keyword match, and voice accuracy to improve over time.",
            icon: Icons.bar_chart_rounded,
            iconBg: const Color(0xFFE4F8F4),
            iconColor: const Color(0xFF14967F),
            onTap: () => onOpenTab(4),
          ),
          const SizedBox(height: 12),
          FeatureTile(
            title: "Peer Practice",
            subtitle:
                "Connect with friends, view their progress, and continue preparation through chat and peer support.",
            icon: Icons.people_alt_rounded,
            iconBg: const Color(0xFFFFF2DF),
            iconColor: const Color(0xFFE39A1A),
            onTap: () => onOpenTab(5),
          ),
          const SizedBox(height: 24),
          const Text(
            "How To Use Prep Buddy",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 14),
          _infoStep(
            number: "1",
            title: "Start with questions",
            subtitle:
                "Go through the question bank and understand the kind of answers companies expect.",
          ),
          const SizedBox(height: 12),
          _infoStep(
            number: "2",
            title: "Practice your answers",
            subtitle:
                "Use mock interview mode to answer by text or voice and improve speaking confidence.",
          ),
          const SizedBox(height: 12),
          _infoStep(
            number: "3",
            title: "Review your growth",
            subtitle:
                "Open analysis and saved answers to understand progress and revisit weak points.",
          ),
          const SizedBox(height: 12),
          _infoStep(
            number: "4",
            title: "Practice with peers",
            subtitle:
                "Connect with another user, compare progress, and continue preparation together.",
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoStep({
    required String number,
    required String title,
    required String subtitle,
  }) {
    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE8EEFF),
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF2346A0),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C2434),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    height: 1.5,
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

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.colors,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
  final VoidCallback? onTap;

  const FeatureTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF98A2B3),
            ),
          ],
        ),
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
      voiceAccuracy: speechConfidence * 100,
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
  String currentUserPhotoUrl = '';
  SharedPreferences? peerPrefs;

  @override
  void initState() {
    super.initState();
    initUser();
    loadPeerPrefs();
  }

  Future<void> initUser() async {
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      currentUserId = user?.uid;
      currentUserName = user?.displayName ?? user?.email ?? 'User';
      currentUserPhotoUrl = user?.photoURL ?? '';
      loading = false;
    });
  }

  Future<void> loadPeerPrefs() async {
  peerPrefs = await SharedPreferences.getInstance();
  if (mounted) {
    setState(() {});
  }
}

String getDisplayPeerName(String peerUserId, String fallbackName) {
  final alias = peerPrefs?.getString('peer_alias_$peerUserId') ?? '';
  final trimmedAlias = alias.trim();
  return trimmedAlias.isEmpty ? fallbackName : trimmedAlias;
}

Future<void> renamePeerLocally({
  required String peerUserId,
  required String originalName,
}) async {
  final controller = TextEditingController(
    text: getDisplayPeerName(peerUserId, originalName),
  );

  final newName = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Rename Peer'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Peer Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (newName == null) return;

  if (newName.isEmpty || newName == originalName) {
    await peerPrefs?.remove('peer_alias_$peerUserId');
  } else {
    await peerPrefs?.setString('peer_alias_$peerUserId', newName);
  }

  if (mounted) {
    setState(() {});
  }
}

Future<void> deletePeer({
  required String inviteDocId,
  required String peerUserId,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete Peer'),
        content: const Text(
          'Agar aap is peer ko delete karte ho to dono devices se ye connection remove ho jayega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (shouldDelete != true) return;

  await FirebaseFirestore.instance
      .collection('peer_invites')
      .doc(inviteDocId)
      .update({
    'status': 'removed',
    'removedBy': currentUserId,
    'removedAt': FieldValue.serverTimestamp(),
  });

  await peerPrefs?.remove('peer_alias_$peerUserId');

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Peer removed successfully')),
  );
}

  String buildChatId(String userA, String userB) {
  final users = [userA, userB]..sort();
  return '${users[0]}_${users[1]}';
}

String formatLastMessageTime(Timestamp? timestamp) {
  if (timestamp == null) return '';
  final date = timestamp.toDate();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
      'ownerPhotoUrl': currentUserPhotoUrl,
      'joinedUserId': null,
      'joinedName': null,
      'joinedPhotoUrl': null,
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

final String invitePhotoUrl = amOwner
    ? (data['joinedPhotoUrl'] ?? '')
    : (data['ownerPhotoUrl'] ?? '');

final String displayPeerName = getDisplayPeerName(
  peerUserId,
  peerName,
);

return FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('profiles')
      .doc(peerUserId)
      .get(),
  builder: (context, profileSnapshot) {
    final profileData =
        profileSnapshot.data?.data() as Map<String, dynamic>?;

    final peerPhotoUrl =
        (profileData?['photoUrl'] ?? invitePhotoUrl).toString();

    final chatId = buildChatId(currentUserId ?? '', peerUserId);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peer_chats')
          .doc(chatId)
          .snapshots(),
      builder: (context, chatSnapshot) {
        final chatData =
            chatSnapshot.data?.data() as Map<String, dynamic>?;

        final lastMessage =
            (chatData?['lastMessage'] ?? '').toString().trim();

        final lastMessageAt =
            chatData?['lastMessageAt'] as Timestamp?;

        final previewText = lastMessage.isEmpty
            ? 'Tap to view profile and start chatting'
            : lastMessage;

        return GestureDetector(
          onTap: () {
            if (peerUserId.toString().isEmpty) return;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PeerDetailScreen(
                  peerUserId: peerUserId,
                  peerName: displayPeerName,
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
                  backgroundImage: peerPhotoUrl.isNotEmpty
                      ? NetworkImage(peerPhotoUrl)
                      : null,
                  child: peerPhotoUrl.isEmpty
                      ? Text(
                          displayPeerName.isNotEmpty
                            ? displayPeerName[0].toUpperCase()
                            : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
  children: [
    Expanded(
      child: Text(
        displayPeerName,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    if (lastMessageAt != null)
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          formatLastMessageTime(lastMessageAt),
          style: const TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'rename') {
          renamePeerLocally(
            peerUserId: peerUserId,
            originalName: peerName,
          );
        } else if (value == 'delete') {
          deletePeer(
            inviteDocId: doc.id,
            peerUserId: peerUserId,
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'rename',
          child: Text('Rename'),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete'),
        ),
      ],
    ),
  ],
),
                      const SizedBox(height: 4),
                      Text(
                        peerRole,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: lastMessage.isEmpty
                              ? const Color(0xFF98A2B3)
                              : const Color(0xFF2346A0),
                          fontSize: 13.5,
                          fontWeight: lastMessage.isEmpty
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        );
      },
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