import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class CalendarEvent {
  final int? id;
  final String title;
  final String date; // YYYY-MM-DD

  CalendarEvent({this.id, required this.title, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      title: map['title'],
      date: map['date'],
    );
  }
}

class CalendarService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'quakesafe_calendar.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, date TEXT)',
        );
      },
    );
  }

  static Future<void> insertEvent(CalendarEvent event) async {
    final d = await db;
    await d.insert('events', event.toMap());
  }

  static Future<List<CalendarEvent>> getEventsForDay(String date) async {
    final d = await db;
    final List<Map<String, dynamic>> maps = await d.query('events', where: 'date = ?', whereArgs: [date]);
    return List.generate(maps.length, (i) => CalendarEvent.fromMap(maps[i]));
  }

  static Future<void> deleteEvent(int id) async {
    final d = await db;
    await d.delete('events', where: 'id = ?', whereArgs: [id]);
  }
}
