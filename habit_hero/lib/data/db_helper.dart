import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/habit.dart';

class DBHelper {
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDB();

  Future<Database> _initDB() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    String path = join(docDir.path, 'habithero.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE checkoffs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        day TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits (id) ON DELETE CASCADE
      );
    ''');
  }

  // --- CRUD Habits ---
  Future<int> insertHabit(Habit h) async {
    final db = await database;
    return await db.insert('habits', h.toMap());
  }

  Future<int> updateHabit(Habit h) async {
    final db = await database;
    return await db.update('habits', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  Future<List<Habit>> getHabits() async {
    final db = await database;
    final rows = await db.query('habits', orderBy: 'id DESC');
    return rows.map((r) => Habit.fromMap(r)).toList();
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    await db.delete('checkoffs', where: 'habit_id = ?', whereArgs: [id]);
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // --- Checkoff toggle (day as YYYY-MM-DD) ---
  Future<void> toggleCheckoff(int habitId, String day) async {
    final db = await database;
    final existing = await db.query('checkoffs',
        where: 'habit_id = ? AND day = ?', whereArgs: [habitId, day]);
    if (existing.isNotEmpty) {
      await db.delete('checkoffs',
          where: 'habit_id = ? AND day = ?', whereArgs: [habitId, day]);
    } else {
      await db.insert('checkoffs', {'habit_id': habitId, 'day': day});
    }
  }

  Future<List<int>> getCheckedForDay(String day) async {
    final db = await database;
    final rows = await db.query('checkoffs', where: 'day = ?', whereArgs: [day]);
    return rows.map((r) => r['habit_id'] as int).toList();
  }

  // --- Zähle Checkoffs eines Habits im Datumsbereich (inklusive) ---
  Future<int> countChecksForHabitInRange(int habitId, String fromDay, String toDay) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM checkoffs WHERE habit_id = ? AND day BETWEEN ? AND ?',
      [habitId, fromDay, toDay],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // --- Liefere die Tage (YYYY-MM-DD) eines Habits innerhalb der letzten N Tage (ältester zuerst) ---
  Future<List<String>> getCheckedDaysForHabit(int habitId, int days) async {
    final db = await database;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    final startStr = _toDayString(start);
    final rows = await db.query(
      'checkoffs',
      columns: ['day'],
      where: 'habit_id = ? AND day >= ?',
      whereArgs: [habitId, startStr],
      orderBy: 'day ASC',
    );
    return rows.map((r) => r['day'] as String).toList();
  }

  // --- Liefert eine Liste mit 0/1 für die letzten `days` Tage (ältester zuerst) ---
  Future<List<int>> getChecksForLastNDays(int habitId, int days) async {
    final db = await database;
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    final startStr = _toDayString(start);

    final rows = await db.query(
      'checkoffs',
      columns: ['day'],
      where: 'habit_id = ? AND day >= ?',
      whereArgs: [habitId, startStr],
    );
    final presentDays = rows.map((r) => r['day'] as String).toSet();

    List<int> res = [];
    for (int i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final s = _toDayString(day);
      res.add(presentDays.contains(s) ? 1 : 0);
    }
    return res;
  }

  String _toDayString(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
