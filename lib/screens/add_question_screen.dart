import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key});

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final TextEditingController questionController = TextEditingController();
  final TextEditingController keywordsController = TextEditingController();

  String selectedType = 'HR';
  bool saving = false;

  Future<void> saveQuestion() async {
    final question = questionController.text.trim();
    final keywordsText = keywordsController.text.trim();

    if (question.isEmpty || keywordsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question aur keywords dono required hain')),
      );
      return;
    }

    final keywords = keywordsText
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      setState(() {
        saving = true;
      });

      await FirebaseFirestore.instance.collection('questions').add({
        'question': question,
        'type': selectedType,
        'keywords': keywords,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'user',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question added successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Question save nahi hua: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    questionController.dispose();
    keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Question'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: questionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Question',
              hintText: 'Example: Tell me about yourself',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedType,
            decoration: InputDecoration(
              labelText: 'Question Type',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'HR', child: Text('HR')),
              DropdownMenuItem(value: 'Technical', child: Text('Technical')),
            ],
            onChanged: (value) {
              setState(() {
                selectedType = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: keywordsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Keywords',
              hintText: 'student, skills, project, goal',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keywords comma se separate karo',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: saving ? null : saveQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2346A0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(saving ? 'Saving...' : 'Save Question'),
            ),
          ),
        ],
      ),
    );
  }
}
