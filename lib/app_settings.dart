import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.light);

  static final ValueNotifier<double> textScaleNotifier =
      ValueNotifier(1.0);
  
  static final ValueNotifier<String> languageCodeNotifier =
    ValueNotifier('en');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString('app_theme_mode') ?? 'light';
    final savedTextScale = prefs.getDouble('app_text_scale') ?? 1.0;
    final savedLanguageCode = prefs.getString('app_language_code') ?? 'en';

    themeModeNotifier.value = _themeModeFromString(savedTheme);
    textScaleNotifier.value = savedTextScale;
    languageCodeNotifier.value = savedLanguageCode;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', _themeModeToString(mode));
  }

  static Future<void> setTextScale(double scale) async {
    textScaleNotifier.value = scale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_text_scale', scale);
  }

  static Future<void> setLanguageCode(String code) async {
  languageCodeNotifier.value = code;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_language_code', code);
}

static String languageLabel(String code) {
  switch (code) {
    case 'hi':
      return 'Hindi';
    case 'mix':
      return 'Hinglish';
    default:
      return 'English';
  }
}

  static Future<void> resetPeerInstallMessage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_peer_install_message');
  }

  static ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
