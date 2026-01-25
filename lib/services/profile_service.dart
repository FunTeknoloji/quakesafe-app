import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _keyUsername = 'username';
  static const String _keyPhoto = 'profile_photo';

  static Future<void> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<void> setProfilePhoto(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhoto, path);
  }

  static Future<String?> getProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhoto);
  }
}
