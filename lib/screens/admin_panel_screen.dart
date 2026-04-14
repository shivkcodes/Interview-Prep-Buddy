import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController typeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    typeController.dispose();
    super.dispose();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'No time';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return const Color(0xFF027A48);
      case 'reviewed':
        return const Color(0xFFB54708);
      default:
        return const Color(0xFF2346A0);
    }
  }

  Future<void> _sendUserNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String relatedId = '',
  }) async {
    await FirebaseFirestore.instance.collection('user_notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateRequestStatus({
    required String docId,
    required String status,
    required String userId,
    required String requestTitle,
    required String adminReply,
  }) async {
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'admin';

    await FirebaseFirestore.instance
        .collection('admin_requests')
        .doc(docId)
        .update({
          'status': status,
          'adminReply': adminReply,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminEmail,
        });

    await _sendUserNotification(
      userId: userId,
      title: 'Request $status',
      message: adminReply.trim().isEmpty
          ? 'Admin ne aapki request "$requestTitle" ko $status mark kiya hai.'
          : 'Admin reply: $adminReply',
      type: 'admin_request_status',
      relatedId: docId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Request marked as $status')));
  }

  Future<void> _showReplyDialog({
    required String docId,
    required String userId,
    required String requestTitle,
    required String status,
  }) async {
    final replyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            status == 'resolved' ? 'Resolve Request' : 'Review Request',
          ),
          content: TextField(
            controller: replyController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write admin reply (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateRequestStatus(
                  docId: docId,
                  status: status,
                  userId: userId,
                  requestTitle: requestTitle,
                  adminReply: replyController.text.trim(),
                );

                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('admin_requests')
        .doc(docId)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Request deleted')));
  }

  Future<void> _showAddTypeDialog() async {
    typeController.clear();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Question Type'),
          content: TextField(
            controller: typeController,
            decoration: const InputDecoration(
              hintText: 'Example: Behavioral',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final typeName = typeController.text.trim();
                if (typeName.isEmpty) return;

                final docId = typeName.toLowerCase().replaceAll(' ', '_');

                await FirebaseFirestore.instance
                    .collection('question_types')
                    .doc(docId)
                    .set({
                      'name': typeName,
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy':
                          FirebaseAuth.instance.currentUser?.email ?? 'admin',
                      'active': true,
                    });

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Question type added')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteQuestionType({required String docId}) async {
    await FirebaseFirestore.instance
        .collection('question_types')
        .doc(docId)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Question type deleted')));
  }

  Future<void> _showDeleteQuestionDialog({
    required String questionId,
    required String questionText,
    required String createdByUid,
  }) async {
    final reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Question'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                questionText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Write delete reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;

                final adminEmail =
                    FirebaseAuth.instance.currentUser?.email ?? 'admin';

                await FirebaseFirestore.instance
                    .collection('questions')
                    .doc(questionId)
                    .update({
                      'isDeleted': true,
                      'deletedBy': adminEmail,
                      'deletedReason': reason,
                      'deletedAt': FieldValue.serverTimestamp(),
                    });

                if (createdByUid.isNotEmpty) {
                  await _sendUserNotification(
                    userId: createdByUid,
                    title: 'Question removed',
                    message:
                        'Admin ne aapka question delete kiya hai. Reason: $reason',
                    type: 'question_deleted',
                    relatedId: questionId,
                  );
                }

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Question deleted successfully'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE4583E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_requests')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Abhi tak koi request ya help message nahi aaya.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final userName = (data['userName'] ?? 'Unknown User').toString();
            final userEmail = (data['userEmail'] ?? '').toString();
            final userPhotoUrl = (data['userPhotoUrl'] ?? '').toString();
            final category = (data['category'] ?? 'unknown').toString();
            final title = (data['title'] ?? '').toString();
            final message = (data['message'] ?? '').toString();
            final status = (data['status'] ?? 'pending').toString();
            final createdAt = data['createdAt'] as Timestamp?;
            final userId = (data['userId'] ?? '').toString();

            final initial = userName.isNotEmpty
                ? userName.substring(0, 1).toUpperCase()
                : 'U';

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: userPhotoUrl.isNotEmpty
                            ? NetworkImage(userPhotoUrl)
                            : null,
                        child: userPhotoUrl.isEmpty
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1C2434),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2346A0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF98A2B3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showReplyDialog(
                              docId: doc.id,
                              userId: userId,
                              requestTitle: title,
                              status: 'resolved',
                            );
                          },
                          child: const Text('Mark Reviewed'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _showReplyDialog(
                              docId: doc.id,
                              userId: userId,
                              requestTitle: title,
                              status: 'reviewed',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2346A0),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Resolve'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _deleteRequest(doc.id);
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE4583E),
                      ),
                      label: const Text(
                        'Delete Request',
                        style: TextStyle(color: Color(0xFFE4583E)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuestionTypesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddTypeDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Question Type'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2346A0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('question_types')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(child: Text('No question types found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString();
                  final createdBy = (data['createdBy'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                createdBy,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _deleteQuestionType(docId: doc.id);
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFE4583E),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('questions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        final visibleDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isDeleted'] != true;
        }).toList();

        if (visibleDocs.isEmpty) {
          return const Center(child: Text('No cloud questions found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visibleDocs.length,
          itemBuilder: (context, index) {
            final doc = visibleDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final question = (data['question'] ?? '').toString();
            final type = (data['type'] ?? '').toString();
            final createdBy = (data['createdBy'] ?? '').toString();
            final createdByUid = (data['createdByUid'] ?? '').toString();
            final createdAt = data['createdAt'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type: $type',
                    style: const TextStyle(color: Color(0xFF2346A0)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Created by: $createdBy',
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF98A2B3),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showDeleteQuestionDialog(
                          questionId: doc.id,
                          questionText: question,
                          createdByUid: createdByUid,
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE4583E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUserProfile({
    required String userId,
    required String userName,
  }) async {
    await FirebaseFirestore.instance
        .collection('profiles')
        .doc(userId)
        .delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$userName profile deleted from app data')),
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('profiles')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        final onlineCount = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isOnline'] == true;
        }).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Total Users',
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            docs.length.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2346A0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAFBF3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Online Users',
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            onlineCount.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF027A48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final name = (data['name'] ?? 'Unknown User').toString();
                  final email = (data['email'] ?? '').toString();
                  final photoUrl = (data['photoUrl'] ?? '').toString();
                  final isOnline = data['isOnline'] == true;
                  final lastSeenAt = data['lastSeenAt'] as Timestamp?;

                  final initial = name.isNotEmpty
                      ? name.substring(0, 1).toUpperCase()
                      : 'U';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
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
                          radius: 24,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? Text(
                                  initial,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isOnline
                                    ? 'Online'
                                    : 'Last seen: ${_formatTime(lastSeenAt)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isOnline
                                      ? const Color(0xFF027A48)
                                      : const Color(0xFF98A2B3),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF12B76A)
                                    : const Color(0xFFD0D5DD),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            IconButton(
                              onPressed: () {
                                _deleteUserProfile(
                                  userId: doc.id,
                                  userName: name,
                                );
                              },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFE4583E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Question Types'),
            Tab(text: 'Questions'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildQuestionTypesTab(),
          _buildQuestionsTab(),
          _buildUsersTab(),
        ],
      ),
    );
  }
}
