import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SurvivalKitService {
  static const String _keyKit = 'survival_kit_items';

  static Future<void> saveKit(Map<String, bool> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKit, jsonEncode(items));
  }

  static Future<Map<String, bool>> loadKit() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_keyKit);
    if (data == null) {
      return {
        'Su (4 Litre)': false,
        'Konserve Gıda': false,
        'El Feneri': false,
        'Pilli Radyo': false,
        'İlkyardım Çantası': false,
        'Düdük': false,
        'Toz Maskesi': false,
        'Çakı': false,
      };
    }
    return Map<String, bool>.from(jsonDecode(data));
  }
}
