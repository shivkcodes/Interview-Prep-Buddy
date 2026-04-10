import 'app_settings.dart';

class AppText {
  static String get currentLanguage => AppSettings.languageCodeNotifier.value;

  static String value({required String en, String? hi, String? mix}) {
    switch (currentLanguage) {
      case 'hi':
        return hi ?? en;
      case 'mix':
        return mix ?? hi ?? en;
      default:
        return en;
    }
  }
}
