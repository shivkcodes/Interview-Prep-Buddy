import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RequestHelpScreen extends StatefulWidget {
  final String mode;

  const RequestHelpScreen({super.key, required this.mode});

  @override
  State<RequestHelpScreen> createState() => _RequestHelpScreenState();
}

class _RequestHelpScreenState extends State<RequestHelpScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  bool sending = false;
  late String selectedCategory;
  @override
  void initState() {
    super.initState();
    selectedCategory = widget.mode == 'help' ? 'bug_report' : 'feature_idea';
  }

  List<DropdownMenuItem<String>> get categoryItems {
    if (widget.mode == 'help') {
      return const [
        DropdownMenuItem(value: 'bug_report', child: Text('Bug Report')),
        DropdownMenuItem(value: 'need_help', child: Text('Need Help')),
        DropdownMenuItem(
          value: 'problem_in_app',
          child: Text('Problem In App'),
        ),
        DropdownMenuItem(value: 'other_help', child: Text('Other')),
      ];
    }

    return const [
      DropdownMenuItem(
        value: 'new_question_type',
        child: Text('New Question Type'),
      ),
      DropdownMenuItem(value: 'feature_idea', child: Text('Feature Idea')),
      DropdownMenuItem(value: 'other_request', child: Text('Other Request')),
    ];
  }

  String get screenTitle {
    return widget.mode == 'help' ? 'Help' : 'Request Something';
  }

  String get screenSubtitle {
    return widget.mode == 'help'
        ? 'Agar app me koi problem aa rahi hai ya help chahiye, yahan message bhejo.'
        : 'Yahan se aap new question type ya feature idea admin ko bhej sakte ho.';
  }

  Future<void> submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    final title = titleController.text.trim();
    final message = messageController.text.trim();

    if (user == null) return;

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title aur message dono required hain')),
      );
      return;
    }

    try {
      setState(() {
        sending = true;
      });

      final profileDoc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid)
          .get();

      final profileData = profileDoc.data();

      await FirebaseFirestore.instance.collection('admin_requests').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'userName': (profileData?['name'] ?? user.displayName ?? 'Unknown User')
            .toString(),
        'userPhotoUrl': (profileData?['photoUrl'] ?? user.photoURL ?? '')
            .toString(),
        'category': selectedCategory,
        'title': title,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'adminReply': '',
        'reviewedAt': null,
        'reviewedBy': '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request send nahi hui: $e')));
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHelp = widget.mode == 'help';

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHelp
                    ? const [
                        Color(0xFF7C2D12),
                        Color(0xFFB45309),
                        Color(0xFFF59E0B),
                      ]
                    : const [
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screenTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  screenSubtitle,
                  style: const TextStyle(color: Color(0xFFFDF2E8), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: InputDecoration(
              labelText: isHelp ? 'Help Type' : 'Request Type',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: categoryItems,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedCategory = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: isHelp
                  ? 'Example: App crash on question submit'
                  : 'Example: Please add Behavioral type',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Message',
              hintText: isHelp
                  ? 'Problem detail me likho...'
                  : 'Apni request detail me likho...',
              filled: true,
              fillColor: Colors.white,
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: sending ? null : submitRequest,
              icon: Icon(
                sending ? Icons.hourglass_top_rounded : Icons.send_rounded,
              ),
              label: Text(sending ? 'Sending...' : 'Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isHelp
                    ? const Color(0xFFB45309)
                    : const Color(0xFF2346A0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
