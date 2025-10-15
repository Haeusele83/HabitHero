// lib/data/db_helper.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/habit.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  static const int _dbVersion = 2; // erhöht wegen reminder fields

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('habit_hero.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, fileName);
    return await openDatabase(path, version: _dbVersion, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT,
        reminder_enabled INTEGER DEFAULT 0,
        reminder_time TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
      );
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // add reminder fields
      try {
        await db.execute('ALTER TABLE habits ADD COLUMN reminder_enabled INTEGER DEFAULT 0;');
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE habits ADD COLUMN reminder_time TEXT;");
      } catch (_) {}
    }
  }

  // Habits
  Future<List<Habit>> getHabits() async {
    final db = await database;
    final res = await db.query('habits', orderBy: 'id DESC');
    return res.map((r) => Habit.fromMap(r)).toList();
  }

  Future<Habit?> getHabit(int id) async {
    final db = await database;
    final res = await db.query('habits', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) return Habit.fromMap(res.first);
    return null;
  }

  Future<int> insertHabit(Habit habit) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('habits', {
      'name': habit.name,
      'created_at': now,
      'reminder_enabled': habit.reminderEnabled ? 1 : 0,
      'reminder_time': habit.reminderTime,
    });
    return id;
  }

  Future<int> updateHabit(Habit habit) async {
    final db = await database;
    if (habit.id == null) return 0;
    final data = {
      'name': habit.name,
      'reminder_enabled': habit.reminderEnabled ? 1 : 0,
      'reminder_time': habit.reminderTime,
    };
    final rows = await db.update('habits', data, where: 'id = ?', whereArgs: [habit.id]);
    return rows;
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // Checks (wie vorher)
  Future<void> toggleCheckoff(int habitId, String dateYMD) async {
    final db = await database;
    final rows = await db.query('checks', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, dateYMD]);

    if (rows.isNotEmpty) {
      await db.delete('checks', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, dateYMD]);
    } else {
      final now = DateTime.now().toIso8601String();
      await db.insert('checks', {
        'habit_id': habitId,
        'date': dateYMD,
        'timestamp': now,
      });
    }
  }

  Future<List<int>> getCheckedForDay(String dateYMD) async {
    final db = await database;
    final res = await db.rawQuery('SELECT DISTINCT habit_id FROM checks WHERE date = ?', [dateYMD]);
    return res.map<int>((r) => r['habit_id'] as int).toList();
  }

  Future<int> getCheckCountForDay(int habitId, String dateYMD) async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM checks WHERE habit_id = ? AND date = ?', [habitId, dateYMD]);
    final v = Sqflite.firstIntValue(res);
    return v ?? 0;
  }

  Future<List<Map<String, dynamic>>> getCheckDetailsForDay(int habitId, String dateYMD) async {
    final db = await database;
    final res = await db.query('checks', where: 'habit_id = ? AND date = ?', whereArgs: [habitId, dateYMD], orderBy: 'timestamp ASC');
    return res;
  }

  Future<List<int>> getChecksForLastNDays(int habitId, int n) async {
    final db = await database;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: n - 1));
    final startStr = _toYMD(start);
    final endStr = _toYMD(today);

    final rows = await db.rawQuery('''
      SELECT date, COUNT(*) as cnt
      FROM checks
      WHERE habit_id = ? AND date BETWEEN ? AND ?
      GROUP BY date
    ''', [habitId, startStr, endStr]);

    final Map<String, int> map = {};
    for (final r in rows) {
      final d = r['date'] as String;
      final c = r['cnt'] is int ? r['cnt'] as int : int.parse((r['cnt']).toString());
      map[d] = c;
    }

    List<int> out = [];
    for (int i = 0; i < n; i++) {
      final d = start.add(Duration(days: i));
      final ks = _toYMD(d);
      out.add(map[ks] ?? 0);
    }
    return out;
  }

  Future<Map<String, int>> getCheckCountsForRange(int habitId, String startYMD, String endYMD) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT date, COUNT(*) as cnt
      FROM checks
      WHERE habit_id = ? AND date BETWEEN ? AND ?
      GROUP BY date
    ''', [habitId, startYMD, endYMD]);

    final Map<String, int> map = {};
    for (final r in rows) {
      final d = r['date'] as String;
      final c = r['cnt'] is int ? r['cnt'] as int : int.parse((r['cnt']).toString());
      map[d] = c;
    }
    return map;
  }

  String _toYMD(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
