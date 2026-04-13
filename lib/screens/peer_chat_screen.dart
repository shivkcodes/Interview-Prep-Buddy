import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

class _ForwardPeerOption {
  final String peerUserId;
  final String peerName;
  final String photoUrl;

  const _ForwardPeerOption({
    required this.peerUserId,
    required this.peerName,
    required this.photoUrl,
  });
}

class _PeerChatScreenState extends State<PeerChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  bool sending = false;
  String? replyingToMessageId;
  String? replyingToText;
  String? replyingToSenderName;

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
        'editedAt': null,
        'deletedForEveryone': false,
        'starredBy': <String>[],
        'reactions': <String, dynamic>{},
        'replyToMessageId': replyingToMessageId,
        'replyToText': replyingToText,
        'replyToSenderName': replyingToSenderName,
        'isForwarded': false,
        'originalSenderName': null,
        'forwardedByName': null,
      });

      messageController.clear();
      clearReply();
    } catch (e) {
      if (!mounted) return;
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

  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required List<dynamic> currentUsers,
  }) async {
    if (currentUser == null) return;

    final messageRef = FirebaseFirestore.instance
        .collection('peer_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final updatedUsers = List<String>.from(
      currentUsers.map((e) => e.toString()),
    );

    if (updatedUsers.contains(currentUser!.uid)) {
      updatedUsers.remove(currentUser!.uid);
    } else {
      updatedUsers.add(currentUser!.uid);
    }

    await messageRef.update({'reactions.$emoji': updatedUsers});
  }

  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    await FirebaseFirestore.instance
        .collection('peer_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'text': 'This message was deleted',
          'deletedForEveryone': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String oldText,
  }) async {
    final controller = TextEditingController(text: oldText);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Edit your message',
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
                final updatedText = controller.text.trim();
                if (updatedText.isEmpty) return;

                await FirebaseFirestore.instance
                    .collection('peer_chats')
                    .doc(chatId)
                    .collection('messages')
                    .doc(messageId)
                    .update({
                      'text': updatedText,
                      'editedAt': FieldValue.serverTimestamp(),
                    });

                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void startReply({
    required String messageId,
    required String text,
    required String senderName,
  }) {
    setState(() {
      replyingToMessageId = messageId;
      replyingToText = text;
      replyingToSenderName = senderName;
    });
  }

  void clearReply() {
    setState(() {
      replyingToMessageId = null;
      replyingToText = null;
      replyingToSenderName = null;
    });
  }

  Future<void> copyMessageText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied')));
  }

  Future<void> toggleStar({
    required String chatId,
    required String messageId,
    required bool isStarred,
  }) async {
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('peer_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
          'starredBy': isStarred
              ? FieldValue.arrayRemove([currentUser!.uid])
              : FieldValue.arrayUnion([currentUser!.uid]),
        });
  }

  Future<void> markChatAsRead() async {
    if (currentUser == null) return;

    final chatId = buildChatId(currentUser!.uid, widget.peerUserId);

    await FirebaseFirestore.instance.collection('peer_chats').doc(chatId).set({
      'unreadCounts.${currentUser!.uid}': 0,
    }, SetOptions(merge: true));
  }

  Future<List<_ForwardPeerOption>> _loadConnectedPeers() async {
    if (currentUser == null) return [];

    final currentUserId = currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('peer_invites')
        .where('status', isEqualTo: 'joined')
        .get();

    final Map<String, _ForwardPeerOption> peerMap = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final bool amOwner = data['ownerId'] == currentUserId;
      final bool amJoined = data['joinedUserId'] == currentUserId;

      if (!amOwner && !amJoined) continue;

      final String peerUserId = amOwner
          ? (data['joinedUserId'] ?? '').toString()
          : (data['ownerId'] ?? '').toString();

      if (peerUserId.isEmpty) continue;
      if (peerUserId == widget.peerUserId) continue;

      final String peerName = amOwner
          ? (data['joinedName'] ?? 'Unknown Peer').toString()
          : (data['ownerName'] ?? 'Unknown Peer').toString();

      final String invitePhotoUrl = amOwner
          ? (data['joinedPhotoUrl'] ?? '').toString()
          : (data['ownerPhotoUrl'] ?? '').toString();

      String resolvedName = peerName;
      String resolvedPhoto = invitePhotoUrl;

      try {
        final profileDoc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(peerUserId)
            .get();

        final profileData = profileDoc.data();
        if (profileData != null) {
          final profileName = (profileData['name'] ?? '').toString().trim();
          final profilePhoto = (profileData['photoUrl'] ?? '')
              .toString()
              .trim();

          if (profileName.isNotEmpty) {
            resolvedName = profileName;
          }
          if (profilePhoto.isNotEmpty) {
            resolvedPhoto = profilePhoto;
          }
        }
      } catch (_) {}

      peerMap[peerUserId] = _ForwardPeerOption(
        peerUserId: peerUserId,
        peerName: resolvedName,
        photoUrl: resolvedPhoto,
      );
    }

    return peerMap.values.toList()..sort(
      (a, b) => a.peerName.toLowerCase().compareTo(b.peerName.toLowerCase()),
    );
  }

  Future<void> _forwardMessageToSelectedPeers({
    required List<_ForwardPeerOption> targetPeers,
    required String messageText,
    required String originalSenderName,
  }) async {
    if (currentUser == null || targetPeers.isEmpty) return;

    final senderDisplayName =
        currentUser!.displayName ?? currentUser!.email ?? 'User';

    for (final targetPeer in targetPeers) {
      final targetChatId = buildChatId(currentUser!.uid, targetPeer.peerUserId);

      final chatRef = FirebaseFirestore.instance
          .collection('peer_chats')
          .doc(targetChatId);

      await chatRef.set({
        'participants': [currentUser!.uid, targetPeer.peerUserId],
        'participantNames': {
          currentUser!.uid: senderDisplayName,
          targetPeer.peerUserId: targetPeer.peerName,
        },
        'lastMessage': messageText,
        'lastMessageSenderId': currentUser!.uid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts.${targetPeer.peerUserId}': FieldValue.increment(1),
        'unreadCounts.${currentUser!.uid}': 0,
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderId': currentUser!.uid,
        'senderName': senderDisplayName,
        'text': messageText,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
        'deletedForEveryone': false,
        'starredBy': <String>[],
        'reactions': <String, dynamic>{},
        'replyToMessageId': null,
        'replyToText': null,
        'replyToSenderName': null,
        'isForwarded': true,
        'originalSenderName': originalSenderName,
        'forwardedByName': senderDisplayName,
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Message forwarded to ${targetPeers.length} peer${targetPeers.length > 1 ? 's' : ''}',
        ),
      ),
    );
  }

  Future<void> _showForwardPicker({
    required String messageText,
    required String originalSenderName,
  }) async {
    final Set<String> selectedPeerIds = {};
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return FutureBuilder<List<_ForwardPeerOption>>(
                  future: _loadConnectedPeers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final peers = snapshot.data ?? [];

                    if (peers.isEmpty) {
                      return const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            'Forward ke liye koi aur connected peer nahi mila.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final filteredPeers = peers.where((peer) {
                      final name = peer.peerName.toLowerCase();
                      final query = searchQuery.trim().toLowerCase();
                      if (query.isEmpty) return true;
                      return name.contains(query);
                    }).toList();

                    final selectedPeers = peers
                        .where(
                          (peer) => selectedPeerIds.contains(peer.peerUserId),
                        )
                        .toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7DEEA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Icon(
                              Icons.forward_to_inbox_rounded,
                              color: Color(0xFF2346A0),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Forward Message',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1C2434),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedPeerIds.isEmpty
                                ? 'Select one or more peers'
                                : '${selectedPeerIds.length} selected',
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: searchController,
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search peer...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(() {
                                        searchQuery = '';
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: const Color(0xFFF4F7FB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (filteredPeers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'No matching peer found.',
                              style: TextStyle(color: Color(0xFF667085)),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredPeers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final peer = filteredPeers[index];
                                final isSelected = selectedPeerIds.contains(
                                  peer.peerUserId,
                                );
                                final initial = peer.peerName.isNotEmpty
                                    ? peer.peerName
                                          .substring(0, 1)
                                          .toUpperCase()
                                    : 'P';

                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        selectedPeerIds.remove(peer.peerUserId);
                                      } else {
                                        selectedPeerIds.add(peer.peerUserId);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEAF1FF)
                                          : const Color(0xFFF8FAFD),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFBFD0FF)
                                            : const Color(0xFFE3EAF4),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFFE8EEFF,
                                          ),
                                          backgroundImage:
                                              peer.photoUrl.isNotEmpty
                                              ? NetworkImage(peer.photoUrl)
                                              : null,
                                          child: peer.photoUrl.isEmpty
                                              ? Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    color: Color(0xFF2346A0),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                peer.peerName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1C2434),
                                                ),
                                              ),
                                              Text(
                                                isSelected
                                                    ? 'Selected'
                                                    : 'Tap to select',
                                                style: const TextStyle(
                                                  color: Color(0xFF667085),
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          color: isSelected
                                              ? const Color(0xFF2346A0)
                                              : const Color(0xFF98A2B3),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: selectedPeers.isEmpty
                                ? null
                                : () async {
                                    Navigator.pop(context);
                                    await _forwardMessageToSelectedPeers(
                                      targetPeers: selectedPeers,
                                      messageText: messageText,
                                      originalSenderName: originalSenderName,
                                    );
                                  },
                            icon: const Icon(Icons.send_rounded),
                            label: Text(
                              selectedPeers.isEmpty
                                  ? 'Select Peers'
                                  : 'Forward to ${selectedPeers.length} Peer${selectedPeers.length > 1 ? 's' : ''}',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2346A0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> showMessageActions({
    required String chatId,
    required String messageId,
    required String text,
    required String senderName,
    required Timestamp? createdAt,
    required bool isMe,
    required bool isStarred,
    required Map<String, dynamic> reactions,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Message actions',
      barrierColor: Colors.black.withOpacity(0.26),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7DEEA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _reactionChip(
                            emoji: '👍',
                            chatId: chatId,
                            messageId: messageId,
                            reactions: reactions,
                          ),
                          _reactionChip(
                            emoji: '❤️',
                            chatId: chatId,
                            messageId: messageId,
                            reactions: reactions,
                          ),
                          _reactionChip(
                            emoji: '😂',
                            chatId: chatId,
                            messageId: messageId,
                            reactions: reactions,
                          ),
                          _reactionChip(
                            emoji: '🔥',
                            chatId: chatId,
                            messageId: messageId,
                            reactions: reactions,
                          ),
                          _reactionChip(
                            emoji: '👏',
                            chatId: chatId,
                            messageId: messageId,
                            reactions: reactions,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (isMe)
                        _messageActionTile(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(context);
                            editMessage(
                              chatId: chatId,
                              messageId: messageId,
                              oldText: text,
                            );
                          },
                        ),
                      _messageActionTile(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        onTap: () async {
                          Navigator.pop(context);
                          await copyMessageText(text);
                        },
                      ),
                      if (isMe)
                        _messageActionTile(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onTap: () async {
                            Navigator.pop(context);
                            await deleteMessageForEveryone(
                              chatId: chatId,
                              messageId: messageId,
                            );
                          },
                        ),
                      _messageActionTile(
                        icon: isStarred
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        label: isStarred ? 'Unstar' : 'Star',
                        onTap: () async {
                          Navigator.pop(context);
                          await toggleStar(
                            chatId: chatId,
                            messageId: messageId,
                            isStarred: isStarred,
                          );
                        },
                      ),
                      _messageActionTile(
                        icon: Icons.reply_rounded,
                        label: 'Reply',
                        onTap: () {
                          Navigator.pop(context);
                          startReply(
                            messageId: messageId,
                            text: text,
                            senderName: senderName,
                          );
                        },
                      ),
                      _messageActionTile(
                        icon: Icons.forward_to_inbox_outlined,
                        label: 'Forward',
                        onTap: () async {
                          Navigator.pop(context);
                          await _showForwardPicker(
                            messageText: text,
                            originalSenderName: senderName,
                          );
                        },
                      ),
                      _messageActionTile(
                        icon: Icons.info_outline_rounded,
                        label: 'View Details',
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Message Details'),
                              content: Text(
                                'Sender: $senderName\nTime: ${formatTimestamp(createdAt)}\nMessage: $text',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  Widget _messageActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: const Color(0xFF2346A0)),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1C2434),
        ),
      ),
    );
  }

  Widget _reactionChip({
    required String emoji,
    required String chatId,
    required String messageId,
    required Map<String, dynamic> reactions,
  }) {
    final currentUsers = List<String>.from(reactions[emoji] ?? []);
    final isSelected = currentUsers.contains(currentUser?.uid);

    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await toggleReaction(
          chatId: chatId,
          messageId: messageId,
          emoji: emoji,
          currentUsers: currentUsers,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8EEFF) : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBFD0FF)
                : const Color(0xFFE3EAF4),
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget _buildReactionSummary({
    required Map<String, dynamic> reactions,
    required bool isMe,
  }) {
    final visibleReactions = reactions.entries.where((entry) {
      final users = List<String>.from(entry.value ?? []);
      return users.isNotEmpty;
    }).toList();

    if (visibleReactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visibleReactions.map((entry) {
        final users = List<String>.from(entry.value ?? []);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withOpacity(0.18)
                : const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${entry.key} ${users.length}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : const Color(0xFF1C2434),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReplyPreview({
    required bool isMe,
    required String replyToSenderName,
    required String replyToText,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.14) : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : const Color(0xFF2346A0),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyToSenderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isMe ? Colors.white : const Color(0xFF2346A0),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            replyToText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: isMe ? Colors.white70 : const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
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
                    final text = (data['text'] ?? '').toString();
                    final senderName = (data['senderName'] ?? '').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final messageId = docs[index].id;
                    final deletedForEveryone =
                        data['deletedForEveryone'] == true;
                    final replyToText = (data['replyToText'] ?? '').toString();
                    final replyToSenderName = (data['replyToSenderName'] ?? '')
                        .toString();
                    final reactions = Map<String, dynamic>.from(
                      data['reactions'] ?? {},
                    );
                    final starredBy = List<String>.from(
                      data['starredBy'] ?? [],
                    );
                    final isStarred = starredBy.contains(currentUser!.uid);
                    final isForwarded = data['isForwarded'] == true;
                    final originalSenderName =
                        (data['originalSenderName'] ?? '').toString();

                    return GestureDetector(
                      onLongPress: () {
                        showMessageActions(
                          chatId: chatId,
                          messageId: messageId,
                          text: text,
                          senderName: senderName,
                          createdAt: createdAt,
                          isMe: isMe,
                          isStarred: isStarred,
                          reactions: reactions,
                        );
                      },
                      child: Slidable(
                        key: ValueKey(messageId),
                        startActionPane: isMe
                            ? null
                            : ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.22,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      startReply(
                                        messageId: messageId,
                                        text: text,
                                        senderName: senderName,
                                      );
                                    },
                                    backgroundColor: const Color(0xFF2346A0),
                                    foregroundColor: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    icon: Icons.reply_rounded,
                                    label: 'Reply',
                                  ),
                                ],
                              ),
                        endActionPane: isMe
                            ? ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.22,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      startReply(
                                        messageId: messageId,
                                        text: text,
                                        senderName: senderName,
                                      );
                                    },
                                    backgroundColor: const Color(0xFF2346A0),
                                    foregroundColor: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    icon: Icons.reply_rounded,
                                    label: 'Reply',
                                  ),
                                ],
                              )
                            : null,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.78,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF2346A0)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                border: isStarred
                                    ? Border.all(
                                        color: const Color(0xFFFFD76A),
                                        width: 1.5,
                                      )
                                    : null,
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
                                  if (isForwarded) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.forward_rounded,
                                          size: 14,
                                          color: isMe
                                              ? Colors.white70
                                              : const Color(0xFF667085),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            originalSenderName.isNotEmpty
                                                ? 'Forwarded from $originalSenderName'
                                                : 'Forwarded',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: isMe
                                                  ? Colors.white70
                                                  : const Color(0xFF667085),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (replyToText.isNotEmpty)
                                    _buildReplyPreview(
                                      isMe: isMe,
                                      replyToSenderName: replyToSenderName,
                                      replyToText: replyToText,
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            fontStyle: deletedForEveryone
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                            color: isMe
                                                ? Colors.white
                                                : const Color(0xFF1C2434),
                                          ),
                                        ),
                                      ),
                                      if (isStarred) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.star_rounded,
                                          size: 16,
                                          color: isMe
                                              ? const Color(0xFFFFE082)
                                              : const Color(0xFFFFB300),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (reactions.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildReactionSummary(
                                      reactions: reactions,
                                      isMe: isMe,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (data['editedAt'] != null) ...[
                                        Text(
                                          'edited',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isMe
                                                ? Colors.white70
                                                : const Color(0xFF667085),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (replyingToMessageId != null)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCAD8FF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    color: Color(0xFF2346A0),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${replyingToSenderName ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2346A0),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          replyingToText ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: clearReply,
                    icon: const Icon(Icons.close),
                  ),
                ],
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
                      hintText: replyingToMessageId != null
                          ? 'Write your reply...'
                          : 'Type a message...',
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
