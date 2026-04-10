import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'language_setup_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String? pendingJoinCode;

  const ProfileSetupScreen({super.key, this.pendingJoinCode});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController degreeController = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadExistingData();
  }

  Future<void> loadExistingData() async {
    final user = currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('profiles')
        .doc(user.uid)
        .get();

    final data = doc.data();

    setState(() {
      nameController.text = data?['name'] ?? user.displayName ?? '';
      emailController.text = data?['email'] ?? user.email ?? '';
      phoneController.text = data?['phoneNumber'] ?? '';
      collegeController.text = data?['collegeName'] ?? '';
      degreeController.text = data?['degree'] ?? '';
      loading = false;
    });
  }

  bool get isValid {
    return nameController.text.trim().isNotEmpty &&
        phoneController.text.trim().isNotEmpty &&
        collegeController.text.trim().isNotEmpty;
  }

  Future<void> continueSetup() async {
    final user = currentUser;
    if (user == null) return;

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, phone number, and college name are required'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phoneNumber': phoneController.text.trim(),
      'collegeName': collegeController.text.trim(),
      'degree': degreeController.text.trim(),
      'photoUrl': user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageSetupScreen(
          pendingJoinCode: widget.pendingJoinCode,
        ),
      ),
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    collegeController.dispose();
    degreeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F8FF), Color(0xFFEAF1FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              const Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C2434),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Before entering the app, please complete a few important details. You do not need to fill everything right now.',
                style: TextStyle(
                  color: Color(0xFF667085),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    buildField(controller: nameController, label: 'Name *'),
                    buildField(
                      controller: emailController,
                      label: 'Email',
                      readOnly: true,
                    ),
                    buildField(
                      controller: phoneController,
                      label: 'Phone Number *',
                    ),
                    buildField(
                      controller: collegeController,
                      label: 'College Name *',
                    ),
                    buildField(
                      controller: degreeController,
                      label: 'Degree',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: saving ? null : continueSetup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2346A0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          saving ? 'Saving...' : 'Continue',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
