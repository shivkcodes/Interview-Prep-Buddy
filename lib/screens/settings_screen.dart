import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../app_text.dart';
import '../app_lock_service.dart';
import '../admin_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String appVersion = '';
  String buildNumber = '';
  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _fontLabel(double scale) {
    if (scale <= 0.95) return 'Small';
    if (scale >= 1.15) return 'Large';
    return 'Medium';
  }

  String _languageLabel(String code) {
    return AppSettings.languageLabel(code);
  }

  Future<void> loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      appVersion = info.version;
      buildNumber = info.buildNumber;
    });
  }

  @override
  void initState() {
    super.initState();
    loadAppVersion();
  }

  Future<void> _showPinSetupSheet({bool isChange = false}) async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String errorText = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> savePin() async {
              final pin = pinController.text.trim();
              final confirmPin = confirmPinController.text.trim();

              if (pin.length != 4 || confirmPin.length != 4) {
                setSheetState(() {
                  errorText = 'PIN must be exactly 4 digits';
                });
                return;
              }

              if (pin != confirmPin) {
                setSheetState(() {
                  errorText = 'PIN does not match';
                });
                return;
              }

              await AppLockService.savePin(pin);
              await AppSettings.setAppLockEnabled(true);

              if (!mounted) return;

              Navigator.pop(sheetContext);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isChange
                        ? 'App lock PIN updated successfully'
                        : 'App lock enabled successfully',
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isChange ? 'Change App Lock PIN' : 'Set App Lock PIN',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C2434),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set a 4-digit PIN. This will be used if fingerprint or face unlock is not available.',
                    style: TextStyle(color: Color(0xFF667085), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Enter 4-digit PIN',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF4F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: 'Confirm PIN',
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF4F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (errorText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText,
                      style: const TextStyle(
                        color: Color(0xFFE4583E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: savePin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2346A0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(isChange ? 'Update PIN' : 'Enable App Lock'),
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

  Future<void> _handleAppLockToggle(bool value) async {
    if (value) {
      await _showPinSetupSheet();
      return;
    }

    await AppSettings.setAppLockEnabled(false);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('App lock disabled')));
  }

  Future<void> _handleBiometricToggle(bool value) async {
    await AppSettings.setBiometricUnlockEnabled(value);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Biometric unlock enabled' : 'Biometric unlock disabled',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = AdminConfig.isAdminEmail(user?.email);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppText.value(
            en: 'App Settings',
            hi: 'ऐप सेटिंग्स',
            mix: 'App Settings',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          if (isAdmin)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB7E4C7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF1B8A5A)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are logged in as Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B5E3C),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            AppText.value(en: 'Settings', hi: 'सेटिंग्स', mix: 'Settings'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            AppText.value(
              en: 'Customize the app experience the way you prefer.',
              hi: 'अपनी पसंद के अनुसार ऐप अनुभव को बदलें।',
              mix: 'App ko apni preference ke according customize karo.',
            ),
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 20),

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
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: AppSettings.themeModeNotifier,
              builder: (context, themeMode, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.value(en: 'Theme', hi: 'थीम', mix: 'Theme'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ThemeMode>(
                      value: themeMode,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF4F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ThemeMode.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(_themeLabel(mode)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          AppSettings.setThemeMode(value);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

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
            child: ValueListenableBuilder<double>(
              valueListenable: AppSettings.textScaleNotifier,
              builder: (context, textScale, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.value(
                        en: 'Font Size',
                        hi: 'फ़ॉन्ट साइज़',
                        mix: 'Font Size',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current: ${_fontLabel(textScale)}',
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: textScale,
                      min: 0.9,
                      max: 1.2,
                      divisions: 3,
                      label: _fontLabel(textScale),
                      onChanged: (value) {
                        AppSettings.setTextScale(value);
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Small'), Text('Medium'), Text('Large')],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

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
            child: ValueListenableBuilder<String>(
              valueListenable: AppSettings.languageCodeNotifier,
              builder: (context, languageCode, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.value(
                        en: 'Language',
                        hi: 'भाषा',
                        mix: 'Language',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: languageCode,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF4F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                        DropdownMenuItem(value: 'mix', child: Text('Hinglish')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          AppSettings.setLanguageCode(value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${_languageLabel(languageCode)}',
                      style: const TextStyle(color: Color(0xFF667085)),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

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
            child: ValueListenableBuilder<bool>(
              valueListenable: AppSettings.appLockEnabledNotifier,
              builder: (context, appLockEnabled, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Lock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enable PIN and biometric protection so the app asks for unlock when reopened.',
                      style: TextStyle(color: Color(0xFF667085), height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      value: appLockEnabled,
                      onChanged: _handleAppLockToggle,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable App Lock'),
                      subtitle: Text(
                        appLockEnabled
                            ? 'Currently enabled'
                            : 'Currently disabled',
                      ),
                    ),
                    if (appLockEnabled) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            AppSettings.biometricUnlockEnabledNotifier,
                        builder: (context, biometricEnabled, __) {
                          return SwitchListTile(
                            value: biometricEnabled,
                            onChanged: _handleBiometricToggle,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Use Fingerprint / Face ID'),
                            subtitle: const Text(
                              'If available on your device, biometrics can unlock the app faster.',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showPinSetupSheet(isChange: true);
                          },
                          icon: const Icon(Icons.password_rounded),
                          label: const Text('Change PIN'),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

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
                Text(
                  AppText.value(
                    en: 'Peer Connection',
                    hi: 'पीयर कनेक्शन',
                    mix: 'Peer Connection',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reset the install hint popup so you can test the peer install flow again.',
                  style: TextStyle(color: Color(0xFF667085), height: 1.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AppSettings.resetPeerInstallMessage();

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Peer install popup reset successfully',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset Peer Hint'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
                const Text(
                  'Developer Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Developer: Shivam Karmakar',
                  style: TextStyle(
                    color: Color(0xFF1C2434),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'App: Interview Prep Buddy',
                  style: TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Version: ${appVersion.isEmpty ? '--' : appVersion} (${buildNumber.isEmpty ? '--' : buildNumber})',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Support: Use Help section to report bugs, issues, or suggestions.',
                  style: TextStyle(color: Color(0xFF667085), height: 1.5),
                ),
                const Text(
                  'About this App: Prep Buddy is designed to help students practice interview questions, improve communication, review saved answers, connect with peers, and track performance in one place.',
                  style: TextStyle(color: Color(0xFF667085), height: 1.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Important: Please avoid sharing sensitive personal data in support messages.',
                  style: TextStyle(
                    color: Color(0xFFB54708),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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
