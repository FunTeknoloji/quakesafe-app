import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _db;
  static final _messageController = StreamController<void>.broadcast();
  static Stream<void> get onMessageAdded => _messageController.stream;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<Database> initDb() async {
    String path = join(await getDatabasesPath(), 'quakesafe.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createDb(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN type TEXT DEFAULT "text"');
          await db.execute('ALTER TABLE messages ADD COLUMN extraData TEXT');
        }
      },
    );
  }

  static Future<void> _createDb(Database db) async {
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT,
        text TEXT,
        isMe INTEGER,
        timestamp INTEGER,
        type TEXT DEFAULT "text",
        extraData TEXT
      )
    ''');
  }

  static Future<void> insertMessage({
    required String sender,
    required String text,
    required bool isMe,
    String type = 'text',
    String? extraData,
  }) async {
    final database = await db;
    await database.insert(
      'messages',
      {
        'sender': sender,
        'text': text,
        'isMe': isMe ? 1 : 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'extraData': extraData,
      },
    );
    _messageController.add(null);
  }

  static Future<List<Map<String, dynamic>>> getMessages() async {
    final database = await db;
    return await database.query('messages', orderBy: 'timestamp ASC');
  }
}
