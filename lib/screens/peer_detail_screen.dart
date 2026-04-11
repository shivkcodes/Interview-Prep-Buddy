import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'peer_chat_screen.dart';

class PeerDetailScreen extends StatelessWidget {
  final String peerUserId;
  final String peerName;

  const PeerDetailScreen({
    super.key,
    required this.peerUserId,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(peerName)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('profiles')
            .doc(peerUserId)
            .snapshots(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profileData =
              (profileSnapshot.data?.data() as Map<String, dynamic>?) ?? {};
          final hasProfileInfo = profileData.isNotEmpty;
          final debugPeerUserId = peerUserId;
          final debugProfileKeys = profileData.keys.join(', ');
          final photoUrl = profileData['photoUrl'] ?? '';
          final localPhotoPath = profileData['localPhotoPath'] ?? '';
          final name = profileData['name'] ?? peerName;
          final email = profileData['email'] ?? '';
          final dob = profileData['dob'] ?? '';
          final tenth = profileData['tenth'] ?? '';
          final twelfth = profileData['twelfth'] ?? '';
          final graduation = profileData['graduation'] ?? '';
          final phone = profileData['phoneNumber'] ?? '';
          final college = profileData['collegeName'] ?? '';
          final degree = profileData['degree'] ?? '';
          final skills = profileData['skills'] ?? '';
          final hobbies = profileData['hobbies'] ?? '';
          final address = profileData['address'] ?? '';
          final linkedin = profileData['linkedin'] ?? '';
          final github = profileData['github'] ?? '';
          final resumeUrl = profileData['resumeUrl'] ?? '';
          final resumeName = profileData['resumeName'] ?? '';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('saved_answers')
                .where('userId', isEqualTo: peerUserId)
                .snapshots(),
            builder: (context, answersSnapshot) {
              if (answersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = answersSnapshot.data?.docs ?? [];

              double averageScore = 0;
              double bestScore = 0;
              double averageVoiceAccuracy = 0;
              String topWeakArea = 'No data';

              if (docs.isNotEmpty) {
                double totalScore = 0;
                double totalVoice = 0;
                final weakAreaCounts = <String, int>{};

                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final score = (data['score'] ?? 0).toDouble();
                  final voice =
                      (data['speechConfidence'] ?? 0).toDouble() * 100;
                  final weakArea = data['weakArea'] ?? 'No data';

                  totalScore += score;
                  totalVoice += voice;

                  if (weakArea != 'Good performance') {
                    weakAreaCounts[weakArea] =
                        (weakAreaCounts[weakArea] ?? 0) + 1;
                  }

                  if (score > bestScore) {
                    bestScore = score;
                  }
                }

                averageScore = totalScore / docs.length;
                averageVoiceAccuracy = totalVoice / docs.length;

                int maxCount = 0;
                weakAreaCounts.forEach((key, value) {
                  if (value > maxCount) {
                    maxCount = value;
                    topWeakArea = key;
                  }
                });

                if (weakAreaCounts.isEmpty) {
                  topWeakArea = 'None';
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!hasProfileInfo)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Debug -> peerUserId: $debugPeerUserId\nprofile keys: $debugProfileKeys',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                          height: 1.5,
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundImage: photoUrl.toString().isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.toString().isEmpty
                              ? Text(
                                  name.toString().isNotEmpty
                                      ? name.toString()[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: Color(0xFF667085)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PeerChatScreen(
                              peerUserId: peerUserId,
                              peerName: peerName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with Peer'),
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
                  const SizedBox(height: 24),
                  const Text(
                    'Overall Performance',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _detailCard(
                    'Total Answers',
                    '${docs.length}',
                    const Color(0xFF335CFF),
                  ),
                  const SizedBox(height: 12),
                  _detailCard(
                    'Average Score',
                    '${averageScore.toStringAsFixed(1)}%',
                    const Color(0xFFFF8A3D),
                  ),
                  const SizedBox(height: 12),
                  _detailCard(
                    'Best Score',
                    '${bestScore.toStringAsFixed(1)}%',
                    const Color(0xFF15A37D),
                  ),
                  const SizedBox(height: 12),
                  _detailCard(
                    'Average Voice Accuracy',
                    '${averageVoiceAccuracy.toStringAsFixed(1)}%',
                    const Color(0xFF06B6D4),
                  ),
                  const SizedBox(height: 12),
                  _detailCard(
                    'Top Weak Area',
                    topWeakArea,
                    const Color(0xFFE4583E),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Profile Information',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _infoTile('Date of Birth', dob),
                  _infoTile('10th Percentage / CGPA', tenth),
                  _infoTile('12th Percentage / CGPA', twelfth),
                  _infoTile('Graduation Percentage / CGPA', graduation),
                  _infoTile('Phone', phone),
                  _infoTile('College', college),
                  _infoTile('Degree', degree),
                  _infoTile('Skills', skills),
                  _infoTile('Hobbies', hobbies),
                  _infoTile('Address', address),
                  const SizedBox(height: 24),
                  const Text(
                    'Professional Links',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),

                  if (linkedin.toString().isNotEmpty)
                    _linkButton('Open LinkedIn', linkedin),
                  if (github.toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _linkButton('Open GitHub', github),
                  ],

                  const SizedBox(height: 24),
                  const Text(
                    'Resume',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),

                  if (resumeUrl.toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
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
                          Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFFE4583E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  resumeName.toString().isNotEmpty
                                      ? resumeName
                                      : 'Uploaded Resume',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1C2434),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            resumeUrl,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(resumeUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open Resume'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2346A0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: const Text(
                        'This peer has not uploaded a resume yet.',
                        style: TextStyle(color: Color(0xFF667085), height: 1.5),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Saved Answers',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),

                  if (docs.isEmpty)
                    const Text(
                      'No saved answers available.',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),

                  ...docs.take(5).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final question = data['question'] ?? '';
                    final answer = data['answer'] ?? '';
                    final score = (data['score'] ?? 0).toDouble();
                    final weakArea = data['weakArea'] ?? '';

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
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            answer,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Score: ${score.toStringAsFixed(1)}% | Weak Area: $weakArea',
                            style: const TextStyle(
                              color: Color(0xFF2346A0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _detailCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            radius: 22,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(Icons.analytics_rounded, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C2434),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString().isEmpty ? 'Not provided' : value,
              style: const TextStyle(color: Color(0xFF667085), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkButton(String label, String url) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.open_in_new),
        label: Text(label),
      ),
    );
  }
}
