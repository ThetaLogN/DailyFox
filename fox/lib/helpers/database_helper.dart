import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/diary_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'diary.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(diary_entries)');
      final columnNames = columns.map((col) => col['name']).toList();

      if (!columnNames.contains('slancio')) {
        await db.execute(
          'ALTER TABLE diary_entries ADD COLUMN slancio INTEGER',
        );
      }
      await db.execute('UPDATE diary_entries SET slancio = 1');
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE diary_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rating INTEGER NOT NULL,
      emoji TEXT NOT NULL,
      keyword TEXT NOT NULL,
      date TEXT NOT NULL,
      slancio INTEGER NOT NULL DEFAULT 0
    )
  ''');
  }

  Future<void> insertEntry(DiaryEntry entry) async {
    final db = await database;
    await db.insert('diary_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateEntry(DiaryEntry entry) async {
    final db = await database;
    await db.update(
      'diary_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('diary_entries');
    return List.generate(maps.length, (i) => DiaryEntry.fromMap(maps[i]));
  }

  Future<List<DiaryEntry>> getAllEntriesWithSlancioTrue() async {
    final db = await database;
    final maps = await db.query(
      'diary_entries',
      where: 'slancio = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => DiaryEntry.fromMap(maps[i]));
  }

  Future<void> clearAllEntries() async {
    final db = await database;
    await db.delete('diary_entries');
  }

  void printDatabase() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query('diary_entries');
    for (var row in result) {
      debugPrint(row.toString());
    }
  }
}
