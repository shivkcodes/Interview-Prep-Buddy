import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'peer_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final void Function(int tabIndex)? onOpenTab;
  final void Function(String query)? onOpenQuestionSearch;

  const NotificationsScreen({
    super.key,
    this.onOpenTab,
    this.onOpenQuestionSearch,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _messageSeenKey = 'notifications_last_seen_messages';
  static const String _questionSeenKey = 'notifications_last_seen_questions';

  DateTime messageSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime questionSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool loadingSeenState = true;
  bool showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    loadSeenState();
  }

  Future<void> loadSeenState() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMessageSeenAt = prefs.getInt(_messageSeenKey) ?? 0;
    final savedQuestionSeenAt = prefs.getInt(_questionSeenKey) ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;

    await prefs.setInt(_messageSeenKey, now);
    await prefs.setInt(_questionSeenKey, now);

    if (!mounted) return;

    setState(() {
      messageSeenAt = DateTime.fromMillisecondsSinceEpoch(savedMessageSeenAt);
      questionSeenAt = DateTime.fromMillisecondsSinceEpoch(savedQuestionSeenAt);
      loadingSeenState = false;
    });
  }

  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  bool isNewItem(Timestamp? timestamp, DateTime seenAt) {
    if (timestamp == null) return false;
    return timestamp.toDate().isAfter(seenAt);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (loadingSeenState) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2434),
                  ),
                ),
              ),
              FilterChip(
                label: const Text('Unread Only'),
                selected: showUnreadOnly,
                onSelected: (value) {
                  setState(() {
                    showUnreadOnly = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Peer Messages',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yahan aapko peers ke latest message updates dikhenge.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('peer_chats')
                .where('participants', arrayContains: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.toList();

              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aTime = aData['lastMessageAt'] as Timestamp?;
                final bTime = bData['lastMessageAt'] as Timestamp?;

                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;

                return bTime.compareTo(aTime);
              });

              final incomingMessageDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final lastMessage = (data['lastMessage'] ?? '')
                    .toString()
                    .trim();
                final senderId = (data['lastMessageSenderId'] ?? '').toString();

                return lastMessage.isNotEmpty && senderId != user.uid;
              }).toList();

              final filteredIncomingMessageDocs = showUnreadOnly
                  ? incomingMessageDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                      return isNewItem(lastMessageAt, messageSeenAt);
                    }).toList()
                  : incomingMessageDocs;

              if (filteredIncomingMessageDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Abhi koi peer message notification nahi hai.',
                  ),
                );
              }

              return Column(
                children: filteredIncomingMessageDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final participants = List<String>.from(
                    data['participants'] ?? [],
                  );
                  final participantNames = Map<String, dynamic>.from(
                    data['participantNames'] ?? {},
                  );
                  final senderId = (data['lastMessageSenderId'] ?? '')
                      .toString();
                  final lastMessage = (data['lastMessage'] ?? '').toString();
                  final lastMessageAt = data['lastMessageAt'] as Timestamp?;

                  final otherUserId = participants.firstWhere(
                    (id) => id != user.uid,
                    orElse: () => '',
                  );

                  final peerName = (participantNames[otherUserId] ?? 'Peer')
                      .toString();

                  final isNew = isNewItem(lastMessageAt, messageSeenAt);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PeerDetailScreen(
                            peerUserId: otherUserId,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFE8EEFF),
                            child: Text(
                              peerName.isNotEmpty
                                  ? peerName[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                color: Color(0xFF2346A0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        peerName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1C2434),
                                        ),
                                      ),
                                    ),
                                    if (isNew)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8EEFF),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'New',
                                          style: TextStyle(
                                            color: Color(0xFF2346A0),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lastMessage,
                                  style: const TextStyle(
                                    color: Color(0xFF667085),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatTime(lastMessageAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF98A2B3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          const Text(
            'New Questions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Yahan naye questions ki updates dikhenge jo doosre users ne add kiye hain.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('questions')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.toList();

              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;

                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;

                return bTime.compareTo(aTime);
              });

              final otherUserQuestions = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['createdByUid'] ?? '') != user.uid;
              }).toList();
              final filteredOtherUserQuestions = showUnreadOnly
                  ? otherUserQuestions.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final createdAt = data['createdAt'] as Timestamp?;
                      return isNewItem(createdAt, questionSeenAt);
                    }).toList()
                  : otherUserQuestions;

              if (filteredOtherUserQuestions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Abhi koi new question notification nahi hai.',
                  ),
                );
              }

              return Column(
                children: filteredOtherUserQuestions.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final question = (data['question'] ?? '').toString();
                  final type = (data['type'] ?? 'General').toString();
                  final createdBy = (data['createdBy'] ?? 'Unknown user')
                      .toString();
                  final createdAt = data['createdAt'] as Timestamp?;
                  final isNew = isNewItem(createdAt, questionSeenAt);

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onOpenTab?.call(1);
                      widget.onOpenQuestionSearch?.call(question);
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: type == 'HR'
                                  ? const Color(0xFFE7F0FF)
                                  : const Color(0xFFE8F7EC),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              type == 'HR'
                                  ? Icons.person_outline
                                  : Icons.memory_rounded,
                              color: type == 'HR'
                                  ? const Color(0xFF2F67D8)
                                  : const Color(0xFF2E9D57),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        question,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1C2434),
                                        ),
                                      ),
                                    ),
                                    if (isNew)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8EEFF),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: const Text(
                                          'New',
                                          style: TextStyle(
                                            color: Color(0xFF2346A0),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Type: $type',
                                  style: const TextStyle(
                                    color: Color(0xFF667085),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Added by: $createdBy',
                                  style: const TextStyle(
                                    color: Color(0xFF98A2B3),
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatTime(createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF98A2B3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
