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
  static const String _archivedMessagesKey = 'notifications_archived_messages';
  static const String _archivedQuestionsKey =
      'notifications_archived_questions';
  static const String _deletedMessagesKey = 'notifications_deleted_messages';
  static const String _deletedQuestionsKey = 'notifications_deleted_questions';
  static const String _adminSeenKey = 'notifications_last_seen_admin';
  static const String _archivedAdminKey = 'notifications_archived_admin';
  static const String _deletedAdminKey = 'notifications_deleted_admin';

  DateTime messageSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime questionSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool loadingSeenState = true;
  String selectedFilter = 'all';
  Set<String> archivedMessageIds = {};
  Set<String> archivedQuestionIds = {};
  Set<String> deletedMessageIds = {};
  Set<String> deletedQuestionIds = {};
  DateTime adminSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  Set<String> archivedAdminIds = {};
  Set<String> deletedAdminIds = {};

  @override
  void initState() {
    super.initState();
    loadSeenState();
  }

  Future<void> loadSeenState() async {
    final prefs = await SharedPreferences.getInstance();

    final savedMessageSeenAt = prefs.getInt(_messageSeenKey) ?? 0;
    final savedQuestionSeenAt = prefs.getInt(_questionSeenKey) ?? 0;
    final savedArchivedMessages =
        prefs.getStringList(_archivedMessagesKey) ?? <String>[];
    final savedArchivedQuestions =
        prefs.getStringList(_archivedQuestionsKey) ?? <String>[];
    final savedDeletedMessages =
        prefs.getStringList(_deletedMessagesKey) ?? <String>[];
    final savedDeletedQuestions =
        prefs.getStringList(_deletedQuestionsKey) ?? <String>[];

    final now = DateTime.now().millisecondsSinceEpoch;
    final savedAdminSeenAt = prefs.getInt(_adminSeenKey) ?? 0;
    final savedArchivedAdmin =
        prefs.getStringList(_archivedAdminKey) ?? <String>[];
    final savedDeletedAdmin =
        prefs.getStringList(_deletedAdminKey) ?? <String>[];

    await prefs.setInt(_messageSeenKey, now);
    await prefs.setInt(_questionSeenKey, now);
    await prefs.setInt(_adminSeenKey, now);

    if (!mounted) return;

    setState(() {
      messageSeenAt = DateTime.fromMillisecondsSinceEpoch(savedMessageSeenAt);
      questionSeenAt = DateTime.fromMillisecondsSinceEpoch(savedQuestionSeenAt);
      archivedMessageIds = savedArchivedMessages.toSet();
      archivedQuestionIds = savedArchivedQuestions.toSet();
      deletedMessageIds = savedDeletedMessages.toSet();
      deletedQuestionIds = savedDeletedQuestions.toSet();
      loadingSeenState = false;
      adminSeenAt = DateTime.fromMillisecondsSinceEpoch(savedAdminSeenAt);
      archivedAdminIds = savedArchivedAdmin.toSet();
      deletedAdminIds = savedDeletedAdmin.toSet();
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

  Future<void> archiveMessageNotification(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    archivedMessageIds.add(chatId);
    await prefs.setStringList(
      _archivedMessagesKey,
      archivedMessageIds.toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> archiveQuestionNotification(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    archivedQuestionIds.add(questionId);
    await prefs.setStringList(
      _archivedQuestionsKey,
      archivedQuestionIds.toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> deleteMessageNotification(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    deletedMessageIds.add(chatId);
    await prefs.setStringList(_deletedMessagesKey, deletedMessageIds.toList());

    if (!mounted) return;
    setState(() {});
  }

  Future<void> deleteQuestionNotification(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    deletedQuestionIds.add(questionId);
    await prefs.setStringList(
      _deletedQuestionsKey,
      deletedQuestionIds.toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> archiveAdminNotification(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    archivedAdminIds.add(notificationId);
    await prefs.setStringList(_archivedAdminKey, archivedAdminIds.toList());

    if (!mounted) return;
    setState(() {});
  }

  Future<void> unarchiveMessageNotification(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    archivedMessageIds.remove(chatId);
    await prefs.setStringList(
      _archivedMessagesKey,
      archivedMessageIds.toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> unarchiveQuestionNotification(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    archivedQuestionIds.remove(questionId);
    await prefs.setStringList(
      _archivedQuestionsKey,
      archivedQuestionIds.toList(),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> unarchiveAdminNotification(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    archivedAdminIds.remove(notificationId);
    await prefs.setStringList(_archivedAdminKey, archivedAdminIds.toList());

    if (!mounted) return;
    setState(() {});
  }

  Future<void> deleteAdminNotification(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    deletedAdminIds.add(notificationId);
    await prefs.setStringList(_deletedAdminKey, deletedAdminIds.toList());

    if (!mounted) return;
    setState(() {});
  }

  bool matchesFilter({required bool isNew, required bool isArchived}) {
    switch (selectedFilter) {
      case 'unread':
        return isNew && !isArchived;
      case 'archived':
        return isArchived;
      default:
        return !isArchived;
    }
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: selectedFilter,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(16),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'unread', child: Text('Unread')),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text('Archived'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFilter = value;
                      });
                    }
                  },
                ),
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
            'Here you see the latest message updates from peers.',
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

              final filteredIncomingMessageDocs = incomingMessageDocs.where((
                doc,
              ) {
                if (deletedMessageIds.contains(doc.id)) {
                  return false;
                }

                final data = doc.data() as Map<String, dynamic>;
                final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                final isNew = isNewItem(lastMessageAt, messageSeenAt);
                final isArchived = archivedMessageIds.contains(doc.id);

                return matchesFilter(isNew: isNew, isArchived: isArchived);
              }).toList();

              if (filteredIncomingMessageDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'There are currently no peer message notifications.',
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

                  return Dismissible(
                    key: ValueKey('message_${doc.id}'),
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFilter == 'archived'
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedFilter == 'archived'
                                ? 'Unarchive'
                                : 'Archive',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4583E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete_outline, color: Colors.white),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        if (selectedFilter == 'archived') {
                          await unarchiveMessageNotification(doc.id);
                        } else {
                          await archiveMessageNotification(doc.id);
                        }
                      } else {
                        await deleteMessageNotification(doc.id);
                      }
                      return false;
                    },

                    child: GestureDetector(
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
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          const Text(
            'Admin Updates',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2434),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Admin reviewed, resolved, and deleted question updates will appear here.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_notifications')
                .where('userId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Admin notifications load nahi ho rahi: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFE4583E)),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Admin notifications abhi available nahi hain.',
                  ),
                );
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

              final filteredDocs = docs.where((doc) {
                if (deletedAdminIds.contains(doc.id)) {
                  return false;
                }

                final data = doc.data() as Map<String, dynamic>;
                final createdAt = data['createdAt'] as Timestamp?;
                final isNew = isNewItem(createdAt, adminSeenAt);
                final isArchived = archivedAdminIds.contains(doc.id);

                return matchesFilter(isNew: isNew, isArchived: isArchived);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'There are no admin updates at the moment.',
                  ),
                );
              }

              return Column(
                children: filteredDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  final title = (data['title'] ?? 'Admin Update').toString();
                  final message = (data['message'] ?? '').toString();
                  final type = (data['type'] ?? '').toString();
                  final createdAt = data['createdAt'] as Timestamp?;
                  final isNew = isNewItem(createdAt, adminSeenAt);

                  IconData leadingIcon;
                  Color iconColor;
                  Color bgColor;

                  if (type == 'question_deleted') {
                    leadingIcon = Icons.delete_outline_rounded;
                    iconColor = const Color(0xFFE4583E);
                    bgColor = const Color(0xFFFFEAE5);
                  } else if (type == 'admin_request_status') {
                    leadingIcon = Icons.admin_panel_settings_rounded;
                    iconColor = const Color(0xFF2346A0);
                    bgColor = const Color(0xFFEAF1FF);
                  } else {
                    leadingIcon = Icons.notifications_none_rounded;
                    iconColor = const Color(0xFF667085);
                    bgColor = const Color(0xFFF4F7FB);
                  }

                  return Dismissible(
                    key: ValueKey('admin_${doc.id}'),
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFilter == 'archived'
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedFilter == 'archived'
                                ? 'Unarchive'
                                : 'Archive',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4583E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete_outline, color: Colors.white),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        if (selectedFilter == 'archived') {
                          await unarchiveAdminNotification(doc.id);
                        } else {
                          await archiveAdminNotification(doc.id);
                        }
                      } else {
                        await deleteAdminNotification(doc.id);
                      }
                      return false;
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
                              color: bgColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(leadingIcon, color: iconColor),
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
                                        title,
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
                                          color: const Color(0xFFEAF1FF),
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
                                  message,
                                  style: const TextStyle(
                                    color: Color(0xFF667085),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
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
          const SizedBox(height: 24),

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
            'Updates on new questions added by other users will appear here.',
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
              final filteredOtherUserQuestions = otherUserQuestions.where((
                doc,
              ) {
                if (deletedQuestionIds.contains(doc.id)) {
                  return false;
                }

                final data = doc.data() as Map<String, dynamic>;
                final createdAt = data['createdAt'] as Timestamp?;
                final isNew = isNewItem(createdAt, questionSeenAt);
                final isArchived = archivedQuestionIds.contains(doc.id);

                return matchesFilter(isNew: isNew, isArchived: isArchived);
              }).toList();
              if (filteredOtherUserQuestions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'There are currently no new question notifications.',
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

                  return Dismissible(
                    key: ValueKey('question_${doc.id}'),
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFilter == 'archived'
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedFilter == 'archived'
                                ? 'Unarchive'
                                : 'Archive',

                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4583E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete_outline, color: Colors.white),
                        ],
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        if (selectedFilter == 'archived') {
                          await unarchiveQuestionNotification(doc.id);
                        } else {
                          await archiveQuestionNotification(doc.id);
                        }
                      } else {
                        await deleteQuestionNotification(doc.id);
                      }
                      return false;
                    },

                    child: GestureDetector(
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
