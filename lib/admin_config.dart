class AdminConfig {
  static const String adminEmail = 'shivamkarmakar2006@gmail.com';

  static bool isAdminEmail(String? email) {
    return (email ?? '').trim().toLowerCase() == adminEmail.toLowerCase();
  }
}
