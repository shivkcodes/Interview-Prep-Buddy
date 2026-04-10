import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_settings.dart';

class LanguageSetupScreen extends StatefulWidget {
  final String? pendingJoinCode;

  const LanguageSetupScreen({super.key, this.pendingJoinCode});

  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends State<LanguageSetupScreen> {
  String selectedLanguage = AppSettings.languageCodeNotifier.value;
  bool saving = false;

  Future<void> completeSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      saving = true;
    });

    await AppSettings.setLanguageCode(selectedLanguage);

    await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
      'appLanguage': selectedLanguage,
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Widget languageCard({
    required String code,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = selectedLanguage == code;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedLanguage = code;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8EEFF) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2346A0)
                : const Color(0xFFE3E8F2),
            width: 1.4,
          ),
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
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2346A0)
                    : const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF2346A0),
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
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2346A0),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFEAF1FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text(
                'Choose App Language',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C2434),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your preferred language. You can change it later from settings.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              languageCard(
                code: 'en',
                title: 'English',
                subtitle: 'Use the app in a clean English-first experience.',
                icon: Icons.language_rounded,
              ),
              languageCard(
                code: 'hi',
                title: 'Hindi',
                subtitle: 'Save Hindi as your preferred app language.',
                icon: Icons.translate_rounded,
              ),
              languageCard(
                code: 'mix',
                title: 'Hinglish',
                subtitle: 'Use a mixed Hindi + English style preference.',
                icon: Icons.chat_bubble_outline_rounded,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: saving ? null : completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2346A0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    saving ? 'Saving...' : 'Enter App',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
