import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class MapService {
  static Future<File> getTile(int z, int x, int y) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/maps/$z/$x/$y.png';
    final file = File(path);

    if (await file.exists()) {
      return file;
    } else {
      await file.create(recursive: true);
      final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
      final response = await http.get(Uri.parse(url));
      await file.writeAsBytes(response.bodyBytes);
      return file;
    }
  }
}
