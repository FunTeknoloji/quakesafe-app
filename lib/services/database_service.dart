import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<Database> initDb() async {
    String path = join(await getDatabasesPath(), 'quakesafe.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT,
            text TEXT,
            isMe INTEGER,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  static Future<void> insertMessage(String sender, String text, bool isMe) async {
    final database = await db;
    await database.insert(
      'messages',
      {
        'sender': sender,
        'text': text,
        'isMe': isMe ? 1 : 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getMessages() async {
    final database = await db;
    return await database.query('messages', orderBy: 'timestamp ASC');
  }
}
