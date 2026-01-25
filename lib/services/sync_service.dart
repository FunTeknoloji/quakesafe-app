import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_service.dart';

class SyncService {
  static const String apiUrl = 'https://quakesafe-app.vercel.app/api/data'; // Placeholder

  static Future<void> syncData() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Process and save to local DB
        // For example, emergency contacts or latest earthquake info
      }
    } catch (e) {
      print('Sync error: $e');
    }
  }
}
