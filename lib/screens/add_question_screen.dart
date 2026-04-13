import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../ai_backend_service.dart';

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
  bool loadingKeywordSuggestions = false;
  List<String> suggestedKeywords = [];
  String keywordReason = '';
  Timer? debounce;

  Future<void> fetchKeywordSuggestions(String question) async {
    final trimmed = question.trim();
    if (trimmed.length < 15) {
      if (mounted) {
        setState(() {
          suggestedKeywords = [];
          keywordReason = '';
          loadingKeywordSuggestions = false;
        });
      }
      return;
    }

    setState(() {
      loadingKeywordSuggestions = true;
    });

    try {
      final result = await AIBackendService.suggestKeywords(
        question: trimmed,
        type: selectedType,
      );

      if (!mounted) return;

      setState(() {
        suggestedKeywords = List<String>.from(
          result['suggested_keywords'] ?? [],
        );
        keywordReason = (result['reason'] ?? '').toString();
        loadingKeywordSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingKeywordSuggestions = false;
        suggestedKeywords = [];
        keywordReason = 'AI keyword suggestions abhi available nahi hain.';
      });
    }
  }

  void onQuestionChanged(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 1200), () {
      fetchKeywordSuggestions(value);
    });
  }

  Future<String?> saveQuestion({bool openMockAfterSave = false}) async {
    final question = questionController.text.trim();
    final keywordsText = keywordsController.text.trim();

    if (question.isEmpty || keywordsText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question aur keywords dono required hain'),
        ),
      );
      return null;
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

      final currentUser = FirebaseAuth.instance.currentUser;

      final docRef = await FirebaseFirestore.instance
          .collection('questions')
          .add({
            'question': question,
            'type': selectedType,
            'keywords': keywords,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': currentUser?.email ?? 'user',
            'createdByUid': currentUser?.uid ?? '',
            'isPinned': false,
            'aiSuggestedKeywords': suggestedKeywords,
            'aiKeywordReason': keywordReason,
          });

      if (!mounted) return null;

      if (openMockAfterSave) {
        Navigator.pop(context, {'openMock': true, 'questionId': docRef.id});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question added successfully')),
        );
        Navigator.pop(context, {'openMock': false, 'questionId': docRef.id});
      }

      return docRef.id;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Question save nahi hua: $e')));
      return null;
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
    debounce?.cancel();
    questionController.dispose();
    keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Question')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF18357E),
                  Color(0xFF2346A0),
                  Color(0xFF4D7BFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a New Question',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Question save karo ya directly mock practice me jump karo.',
                  style: TextStyle(color: Color(0xFFDDE7FF), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (loadingKeywordSuggestions)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),

          if (suggestedKeywords.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3EAF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Suggested Keywords',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2346A0),
                    ),
                  ),
                  if (keywordReason.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      keywordReason,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestedKeywords.map((keyword) {
                      return GestureDetector(
                        onTap: () {
                          final existing = keywordsController.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList();

                          if (!existing.contains(keyword)) {
                            existing.add(keyword);
                            setState(() {
                              keywordsController.text = existing.join(', ');
                              keywordsController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: keywordsController.text.length,
                                    ),
                                  );
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF1FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFC9D9FF)),
                          ),
                          child: Text(
                            keyword,
                            style: const TextStyle(
                              color: Color(0xFF2346A0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: questionController,
            maxLines: 3,
            onChanged: onQuestionChanged,
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

              if (questionController.text.trim().isNotEmpty) {
                fetchKeywordSuggestions(questionController.text);
              }
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
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : () => saveQuestion(),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving...' : 'Save Question'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2346A0),
                      backgroundColor: const Color(0xFFEAF1FF),
                      side: const BorderSide(color: Color(0xFFC9D9FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () => saveQuestion(openMockAfterSave: true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Save & Practice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
