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
      version: 3,
      onCreate: (db, version) async {
        await _createDb(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN type TEXT DEFAULT "text"');
          await db.execute('ALTER TABLE messages ADD COLUMN extraData TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN status TEXT DEFAULT "sent"');
          await db.execute('ALTER TABLE messages ADD COLUMN priority TEXT DEFAULT "normal"');
          await db.execute('ALTER TABLE messages ADD COLUMN retry_count INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE messages ADD COLUMN message_id TEXT');
          await db.execute('ALTER TABLE messages ADD COLUMN receiver_id TEXT DEFAULT "broadcast"');
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
        extraData TEXT,
        status TEXT DEFAULT "sent",
        priority TEXT DEFAULT "normal",
        retry_count INTEGER DEFAULT 0,
        message_id TEXT,
        receiver_id TEXT DEFAULT "broadcast"
      )
    ''');
  }

  static Future<int> insertMessage({
    required String sender,
    required String text,
    required bool isMe,
    String type = 'text',
    String? extraData,
    String status = 'sent',
    String priority = 'normal',
    String? messageId,
    String receiverId = 'broadcast',
  }) async {
    final database = await db;
    int id = await database.insert(
      'messages',
      {
        'sender': sender,
        'text': text,
        'isMe': isMe ? 1 : 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'extraData': extraData,
        'status': status,
        'priority': priority,
        'retry_count': 0,
        'message_id': messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'receiver_id': receiverId,
      },
    );
    _messageController.add(null);
    return id;
  }

  static Future<void> updateMessageStatus(int id, String status) async {
    final database = await db;
    await database.update('messages', {'status': status}, where: 'id = ?', whereArgs: [id]);
    _messageController.add(null);
  }

  static Future<void> incrementRetryCount(int id) async {
    final database = await db;
    await database.execute('UPDATE messages SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }

  static Future<List<Map<String, dynamic>>> getMessages() async {
    final database = await db;
    return await database.query('messages', orderBy: 'timestamp ASC');
  }
}
