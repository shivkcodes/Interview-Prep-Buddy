import 'package:flutter/material.dart';
import '../app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Customize the app experience the way you prefer.',
            style: TextStyle(color: Color(0xFF667085)),
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
                    const Text(
                      'Theme',
                      style: TextStyle(
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
                    const Text(
                      'Font Size',
                      style: TextStyle(
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
                      children: [
                        Text('Small'),
                        Text('Medium'),
                        Text('Large'),
                      ],
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
          const Text(
            'Language',
            style: TextStyle(
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
              DropdownMenuItem(
                value: 'en',
                child: Text('English'),
              ),
              DropdownMenuItem(
                value: 'hi',
                child: Text('Hindi'),
              ),
              DropdownMenuItem(
                value: 'mix',
                child: Text('Hinglish'),
              ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peer Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reset the install hint popup so you can test the peer install flow again.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.5,
                  ),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Prep Buddy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Prep Buddy is designed to help students practice interview questions, improve communication, review saved answers, connect with peers, and track performance in one place.',
                  style: TextStyle(
                    color: Color(0xFF667085),
                    height: 1.6,
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
