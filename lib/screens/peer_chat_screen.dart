import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PeerChatScreen extends StatefulWidget {
  final String peerUserId;
  final String peerName;

  const PeerChatScreen({
    super.key,
    required this.peerUserId,
    required this.peerName,
  });

  @override
  State<PeerChatScreen> createState() => _PeerChatScreenState();
}

class _PeerChatScreenState extends State<PeerChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  bool sending = false;

  String buildChatId(String userA, String userB) {
    final users = [userA, userB]..sort();
    return '${users[0]}_${users[1]}';
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final chatId = buildChatId(currentUser!.uid, widget.peerUserId);

    try {
      setState(() {
        sending = true;
      });

      final chatRef = FirebaseFirestore.instance
          .collection('peer_chats')
          .doc(chatId);

      await chatRef.set({
        'participants': [currentUser!.uid, widget.peerUserId],
        'participantNames': {
          currentUser!.uid:
              currentUser!.displayName ?? currentUser!.email ?? 'User',
          widget.peerUserId: widget.peerName,
        },
        'lastMessage': text,
        'lastMessageSenderId': currentUser!.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.peerUserId}': FieldValue.increment(1),
        'unreadCounts.${currentUser!.uid}': 0,
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': currentUser!.uid,
        'senderName': currentUser!.displayName ?? currentUser!.email ?? 'User',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message send nahi hua: $e')));
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> markChatAsRead() async {
    if (currentUser == null) return;

    final chatId = buildChatId(currentUser!.uid, widget.peerUserId);

    await FirebaseFirestore.instance.collection('peer_chats').doc(chatId).set({
      'unreadCounts.${currentUser!.uid}': 0,
    }, SetOptions(merge: true));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markChatAsRead();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    final chatId = buildChatId(currentUser!.uid, widget.peerUserId);

    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('peer_chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  markChatAsRead();
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nStart the conversation.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUser!.uid;
                    final text = data['text'] ?? '';
                    final senderName = data['senderName'] ?? '';
                    final createdAt = data['createdAt'] as Timestamp?;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF2346A0) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                senderName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2346A0),
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 6),
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: isMe
                                    ? Colors.white
                                    : const Color(0xFF1C2434),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatTimestamp(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe
                                    ? Colors.white70
                                    : const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: const Color(0xFFF4F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: ElevatedButton(
                    onPressed: sending ? null : sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2346A0),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Icon(
                      sending ? Icons.hourglass_top : Icons.send_rounded,
                    ),
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
