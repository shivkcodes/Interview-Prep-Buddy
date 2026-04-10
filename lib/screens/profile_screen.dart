import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'settings_screen.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController tenthController = TextEditingController();
  final TextEditingController twelfthController = TextEditingController();
  final TextEditingController graduationController = TextEditingController();
  final TextEditingController collegeController = TextEditingController();
  final TextEditingController degreeController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController skillsController = TextEditingController();
  final TextEditingController hobbiesController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();
  final TextEditingController githubController = TextEditingController();

  bool loading = true;
  bool saving = false;
  bool fetchingAddress = false;
  bool uploadingResume = false;

  String photoUrl = '';
  String resumeUrl = '';
  String resumeName = '';
  String resumeDriveFileId = '';
  String resumeUploadedAt = '';
  String localPhotoPath = '';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('profiles')
        .doc(user.uid)
        .get();

    final data = doc.data();

    setState(() {
      nameController.text = data?['name'] ?? user.displayName ?? '';
      emailController.text = data?['email'] ?? user.email ?? '';
      dobController.text = data?['dob'] ?? '';
      tenthController.text = data?['tenth'] ?? '';
      twelfthController.text = data?['twelfth'] ?? '';
      graduationController.text = data?['graduation'] ?? '';
      collegeController.text = data?['collegeName'] ?? '';
      degreeController.text = data?['degree'] ?? '';
      phoneController.text = data?['phoneNumber'] ?? '';
      skillsController.text = data?['skills'] ?? '';
      hobbiesController.text = data?['hobbies'] ?? '';
      addressController.text = data?['address'] ?? '';
      linkedinController.text = data?['linkedin'] ?? '';
      githubController.text = data?['github'] ?? '';
      photoUrl = data?['photoUrl'] ?? user.photoURL ?? '';
      localPhotoPath = data?['localPhotoPath'] ?? '';
      resumeUrl = data?['resumeUrl'] ?? '';
      resumeName = data?['resumeName'] ?? '';
      resumeDriveFileId = data?['resumeDriveFileId'] ?? '';
      resumeUploadedAt = data?['resumeUploadedAt'] ?? '';
      loading = false;
    });
  }

  Future<void> pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2003, 1, 1),
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() {});
    }
  }

  Future<void> fetchCurrentAddress() async {
    try {
      setState(() {
        fetchingAddress = true;
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services disabled hain.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw 'Location permission deny ho gayi.';
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission permanently deny hai.';
      }

      final position = await Geolocator.getCurrentPosition();

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final place = placemarks.first;

      final address =
          '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.postalCode ?? ''}, ${place.country ?? ''}';

      addressController.text = address;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Address fetch nahi hua: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          fetchingAddress = false;
        });
      }
    }
  }

  Future<void> uploadResumeToDrive() async {
    try {
      setState(() {
        uploadingResume = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          uploadingResume = false;
        });
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      final googleSignIn = GoogleSignIn.instance;

      await googleSignIn.initialize(
        serverClientId: '808331321792-m83hgrihoris9lcejipj3a7diel7ndic.apps.googleusercontent.com',
      );

      GoogleSignInAccount? googleUser =
        await googleSignIn.attemptLightweightAuthentication();

      googleUser ??= await googleSignIn.authenticate();

      if (googleUser == null) {
        throw 'Google account available nahi hai.';
      }

      const scopes = <String>[
        'https://www.googleapis.com/auth/drive.file',
      ];

      GoogleSignInClientAuthorization? authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes);

      authorization ??=
          await googleUser.authorizationClient.authorizeScopes(scopes);

      final authClient = GoogleAuthClient({
        'Authorization': 'Bearer ${authorization.accessToken}',
      });

      final driveApi = drive.DriveApi(authClient);

      final driveFile = drive.File()..name = fileName;

      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(
          file.openRead(),
          file.lengthSync(),
        ),
        $fields: 'id,name,webViewLink,webContentLink',
      );

      authClient.close();

      final now = DateTime.now();
      final formattedTime =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      setState(() {
        resumeName = uploadedFile.name ?? fileName;
        resumeUrl = uploadedFile.webViewLink ??
          uploadedFile.webContentLink ??
          '';
        resumeDriveFileId = uploadedFile.id ?? '';
        resumeUploadedAt = formattedTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume Google Drive me upload ho gaya')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Resume upload nahi hua: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingResume = false;
        });
      }
    }
  }

  Future<void> deleteResume() async {
  final user = currentUser;
  if (user == null) return;

  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete Resume'),
        content: const Text(
          'Kya aap sure hain ki aap saved resume information remove karna chahte ho?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (shouldDelete != true) return;

  try {
    setState(() {
      resumeUrl = '';
      resumeName = '';
      resumeDriveFileId = '';
      resumeUploadedAt = '';
    });

    await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
      'resumeUrl': '',
      'resumeName': '',
      'resumeDriveFileId': '',
      'resumeUploadedAt': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resume removed successfully')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Resume delete nahi hua: $e')),
    );
  }
}

  Future<void> saveProfile() async {
    final user = currentUser;
    if (user == null) return;

    try {
      setState(() {
        saving = true;
      });

      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'dob': dobController.text.trim(),
        'tenth': tenthController.text.trim(),
        'twelfth': twelfthController.text.trim(),
        'graduation': graduationController.text.trim(),
        'collegeName': collegeController.text.trim(),
        'degree': degreeController.text.trim(),
        'phoneNumber': phoneController.text.trim(),
        'skills': skillsController.text.trim(),
        'hobbies': hobbiesController.text.trim(),
        'address': addressController.text.trim(),
        'linkedin': linkedinController.text.trim(),
        'github': githubController.text.trim(),
        'photoUrl': photoUrl,
        'localPhotoPath': localPhotoPath,
        'resumeUrl': resumeUrl,
        'resumeName': resumeName,
        'resumeDriveFileId': resumeDriveFileId,
        'resumeUploadedAt': resumeUploadedAt,   
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile save nahi hua: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> pickProfilePhoto() async {
  try {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (pickedFile == null) return;

    setState(() {
      localPhotoPath = pickedFile.path;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile photo selected')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Photo select nahi hui: $e')),
    );
  }
}

  Widget buildField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    dobController.dispose();
    tenthController.dispose();
    twelfthController.dispose();
    graduationController.dispose();
    collegeController.dispose();
    degreeController.dispose();
    phoneController.dispose();
    skillsController.dispose();
    hobbiesController.dispose();
    addressController.dispose();
    linkedinController.dispose();
    githubController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  if (loading) {
    return const Scaffold(
      body: SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  return Scaffold(
    appBar: AppBar(
      title: const Text('Profile'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Google se name, email aur photo aayegi. Baaki details aap fill kar sakte ho.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundImage: localPhotoPath.isNotEmpty
                      ? FileImage(File(localPhotoPath))
                      : (photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null)
                          as ImageProvider<Object>?,
                  child: localPhotoPath.isEmpty && photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 42)
                      : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: pickProfilePhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload Profile Photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          buildField(controller: nameController, label: 'Name'),
          buildField(
            controller: emailController,
            label: 'Email',
            readOnly: true,
          ),
          buildField(
            controller: dobController,
            label: 'Date of Birth',
            readOnly: true,
            onTap: pickDob,
          ),
          buildField(controller: phoneController, label: 'Phone Number'),
          buildField(controller: tenthController, label: '10th Percentage / CGPA'),
          buildField(controller: twelfthController, label: '12th Percentage / CGPA'),
          buildField(controller: graduationController, label: 'Graduation Percentage / CGPA'),
          buildField(controller: collegeController, label: 'College Name'),
          buildField(controller: degreeController, label: 'Degree'),
          buildField(controller: skillsController, label: 'Skills'),
          buildField(controller: hobbiesController, label: 'Hobbies'),
          buildField(
            controller: addressController,
            label: 'Address',
            maxLines: 3,
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: fetchingAddress ? null : fetchCurrentAddress,
                  icon: const Icon(Icons.my_location),
                  label: Text(fetchingAddress ? 'Fetching...' : 'Use Current Location'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          buildField(controller: linkedinController, label: 'LinkedIn URL'),
          buildField(controller: githubController, label: 'GitHub URL'),

          Container(
            padding: const EdgeInsets.all(16),
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
                const Row(
                  children: [
                    Icon(Icons.description_rounded, color: Color(0xFF2346A0)),
                    SizedBox(width: 8),
                    Text(
                      'Resume',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF1C2434),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3E8F2)),
                  ),
                  child: resumeUrl.isEmpty
                      ? const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No resume uploaded',
                              style: TextStyle(
                                color: Color(0xFF1C2434),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Aapka uploaded resume yahan dikhai dega.',
                              style: TextStyle(color: Color(0xFF667085)),
                            ),
                          ],
                        )
                      : Column(
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
                                    resumeName,
                                    style: const TextStyle(
                                      color: Color(0xFF1C2434),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (resumeUploadedAt.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Uploaded: $resumeUploadedAt',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF2346A0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              resumeUrl,
                              style: const TextStyle(
                                color: Color(0xFF667085),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                if (resumeUrl.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(resumeUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Resume link open nahi ho rahi'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: resumeUrl),
                            );

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Resume link copied')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy Link'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: deleteResume,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE4583E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: uploadingResume ? null : uploadResumeToDrive,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2346A0),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            uploadingResume ? 'Uploading...' : 'Re-upload',
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: uploadingResume ? null : uploadResumeToDrive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2346A0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        uploadingResume
                            ? 'Uploading...'
                            : 'Upload Resume to Google Drive',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: saving ? null : saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2346A0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(saving ? 'Saving...' : 'Save Profile'),
            ),
          ),
          const SizedBox(height: 14),
SizedBox(
  height: 54,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        ),
      );
    },
    icon: const Icon(Icons.settings_outlined),
    label: const Text('Open Settings'),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF2346A0),
      side: const BorderSide(color: Color(0xFF2346A0)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  ),
),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE4583E),
                side: const BorderSide(color: Color(0xFFE4583E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
