import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class JoinPeerScreen extends StatefulWidget {
  final String code;

  const JoinPeerScreen({super.key, required this.code});

  @override
  State<JoinPeerScreen> createState() => _JoinPeerScreenState();
}

class _JoinPeerScreenState extends State<JoinPeerScreen> {
  final TextEditingController nameController = TextEditingController();
  bool saving = false;

  Future<void> joinPeer() async {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your name")),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    await FirebaseFirestore.instance
        .collection('peer_invites')
        .doc(widget.code)
        .update({
      'joinedName': name,
      'status': 'joined',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Joined successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Peer Practice"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Invite Code: ${widget.code}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Your Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saving ? null : joinPeer,
              child: Text(saving ? "Joining..." : "Join"),
            ),
          ],
        ),
      ),
    );
  }
}
