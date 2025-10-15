// lib/data/db_helper.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/habit.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;
  DBHelper._init();

  // bump DB version if you change schema in future
  static const int _dbVersion = 4;
  static const String _dbFileName = 'habit_hero.db';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbFileName);
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = join(docs.path, fileName);
    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create base tables with the current schema (includes 'day' column in checks)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS checks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        day TEXT NOT NULL, /* YYYY-MM-DD */
        timestamp TEXT, /* ISO datetime string */
        UNIQUE(habit_id, day)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_schedule (
        habit_id INTEGER PRIMARY KEY,
        days_mask INTEGER DEFAULT 0,
        repeats_per_week INTEGER,
        time_start TEXT,
        time_end TEXT
      );
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // safe migrations for older DBs
    if (oldVersion < 2) {
      // create habit_schedule introduced in v2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS habit_schedule (
          habit_id INTEGER PRIMARY KEY,
          days_mask INTEGER DEFAULT 0,
          repeats_per_week INTEGER,
          time_start TEXT,
          time_end TEXT
        );
      ''');
    }

    if (oldVersion < 3) {
      // add created_at to habits if missing
      try {
        final info = await db.rawQuery("PRAGMA table_info('habits');");
        final hasCreated =
            info.where((row) => (row['name'] as String?) == 'created_at').isNotEmpty;
        if (!hasCreated) {
          await db.execute("ALTER TABLE habits ADD COLUMN created_at TEXT;");
        }
      } catch (_) {
        // ignore
      }
    }

    if (oldVersion < 4) {
      // ensure checks has columns day and timestamp
      try {
        final info = await db.rawQuery("PRAGMA table_info('checks');");
        final colNames = info.map((r) => (r['name'] as String?) ?? '').toList();

        if (!colNames.contains('day')) {
          // Add 'day' column (may be null for existing rows)
          await db.execute("ALTER TABLE checks ADD COLUMN day TEXT;");
        }
        if (!colNames.contains('timestamp')) {
          await db.execute("ALTER TABLE checks ADD COLUMN timestamp TEXT;");
        }
        // If existing DB had a different date column (e.g. 'date'), we leave it — the app will use 'day'.
      } catch (_) {
        // ignore migrations errors to avoid crash; we try to be tolerant
      }
    }
  }

  Future _onOpen(Database db) async {
    // Double-check columns exist and add missing ones (extra safety)
    await _ensureColumn(db, 'habits', 'created_at', 'TEXT');
    await _ensureColumn(db, 'checks', 'day', 'TEXT');
    await _ensureColumn(db, 'checks', 'timestamp', 'TEXT');
    await _ensureTable(db, 'habit_schedule', '''
      CREATE TABLE IF NOT EXISTS habit_schedule (
        habit_id INTEGER PRIMARY KEY,
        days_mask INTEGER DEFAULT 0,
        repeats_per_week INTEGER,
        time_start TEXT,
        time_end TEXT
      );
    ''');
  }

  Future<void> _ensureTable(Database db, String tableName, String createSql) async {
    try {
      final res = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", [tableName]);
      if (res.isEmpty) {
        await db.execute(createSql);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _ensureColumn(Database db, String table, String column, String type) async {
    try {
      final info = await db.rawQuery("PRAGMA table_info('$table');");
      final exists = info.where((row) => (row['name'] as String?) == column).isNotEmpty;
      if (!exists) {
        await db.execute("ALTER TABLE $table ADD COLUMN $column $type;");
      }
    } catch (_) {
      // ignore (best-effort)
    }
  }

  // ---------------------------
  // CRUD Habit
  // ---------------------------
  Future<int> insertHabit(Habit h) async {
    final db = await database;
    final map = h.toMap();
    // ensure created_at set if not provided
    if (map['created_at'] == null) {
      map['created_at'] = DateTime.now().toIso8601String();
    }
    final id = await db.insert('habits', map);
    return id;
  }

  Future<List<Habit>> getHabits() async {
    final db = await database;
    final rows = await db.query('habits', orderBy: 'id DESC');
    return rows.map((r) => Habit.fromMap(r)).toList();
  }

  Future<int> updateHabit(Habit h) async {
    final db = await database;
    return await db.update('habits', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
  }

  Future<int> deleteHabit(int id) async {
    final db = await database;
    await db.delete('habit_schedule', where: 'habit_id = ?', whereArgs: [id]);
    await db.delete('checks', where: 'habit_id = ?', whereArgs: [id]);
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------
  // Checks - toggle & queries
  // ---------------------------

  /// toggle for a given day string 'YYYY-MM-DD'
  Future<void> toggleCheckoff(int habitId, String dayIso) async {
    final db = await database;
    // ensure column 'day' exists (defensive)
    await _ensureColumn(db, 'checks', 'day', 'TEXT');

    final rows = await db.query('checks', where: 'habit_id = ? AND day = ?', whereArgs: [habitId, dayIso]);
    if (rows.isEmpty) {
      await db.insert('checks', {'habit_id': habitId, 'day': dayIso, 'timestamp': DateTime.now().toIso8601String()});
    } else {
      await db.delete('checks', where: 'habit_id = ? AND day = ?', whereArgs: [habitId, dayIso]);
    }
  }

  Future<List<int>> getCheckedForDay(String dayIso) async {
    final db = await database;
    await _ensureColumn(db, 'checks', 'day', 'TEXT');
    final rows = await db.query('checks', columns: ['habit_id'], where: 'day = ?', whereArgs: [dayIso]);
    return rows.map((r) => r['habit_id'] as int).toList();
  }

  /// returns list<int> of length n (oldest->newest) with 0/1 for habit
  Future<List<int>> getChecksForLastNDays(int habitId, int n) async {
    final db = await database;
    await _ensureColumn(db, 'checks', 'day', 'TEXT');
    final today = DateTime.now();
    final results = <int>[];
    for (int i = n - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dayIso = d.toIso8601String().split('T')[0];
      final rows = await db.query('checks', where: 'habit_id = ? AND day = ?', whereArgs: [habitId, dayIso]);
      results.add(rows.isNotEmpty ? 1 : 0);
    }
    return results;
  }

  // ---------------------------
  // Schedule helpers (habit_schedule)
  // ---------------------------

  Future<void> setSchedule(int habitId, {required int daysMask, int? repeatsPerWeek, String? timeStart, String? timeEnd}) async {
    final db = await database;
    final map = {
      'habit_id': habitId,
      'days_mask': daysMask,
      'repeats_per_week': repeatsPerWeek,
      'time_start': timeStart,
      'time_end': timeEnd
    };

    final existing = await db.query('habit_schedule', where: 'habit_id = ?', whereArgs: [habitId]);
    if (existing.isEmpty) {
      await db.insert('habit_schedule', map);
    } else {
      await db.update('habit_schedule', map, where: 'habit_id = ?', whereArgs: [habitId]);
    }
  }

  Future<Map<String, dynamic>?> getSchedule(int habitId) async {
    final db = await database;
    final rows = await db.query('habit_schedule', where: 'habit_id = ?', whereArgs: [habitId], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
