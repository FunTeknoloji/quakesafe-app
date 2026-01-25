import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class Note {
  final int? id;
  final String title;
  final String content;
  final String date;
  final List<String> attachments; // JSON string list

  Note({this.id, required this.title, required this.content, required this.date, required this.attachments});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date,
      'attachments': jsonEncode(attachments),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      date: map['date'],
      attachments: List<String>.from(jsonDecode(map['attachments'] ?? '[]')),
    );
  }
}

class NotesService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'quakesafe_notes.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, date TEXT, attachments TEXT)',
        );
      },
    );
  }

  static Future<void> insertNote(Note note) async {
    final d = await db;
    await d.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Note>> getNotes() async {
    final d = await db;
    final List<Map<String, dynamic>> maps = await d.query('notes', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  static Future<void> deleteNote(int id) async {
    final d = await db;
    await d.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateNote(Note note) async {
    final d = await db;
    await d.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }
}
