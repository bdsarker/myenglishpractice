import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/word_entry_model.dart';

class WordDb {
  static final WordDb _instance = WordDb._();
  WordDb._();
  factory WordDb() => _instance;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'english_buddy.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT UNIQUE NOT NULL,
            bangla_meaning TEXT,
            saved_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE word_cache (
            word TEXT PRIMARY KEY,
            synonyms_json TEXT,
            sentences_json TEXT,
            bangla_meaning TEXT,
            cached_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> saveFavorite(WordEntryModel entry) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'word': entry.word,
        'bangla_meaning': entry.banglaDefinition,
        'saved_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String word) async {
    final db = await database;
    await db.delete('favorites', where: 'word = ?', whereArgs: [word]);
  }

  Future<List<Map<String, dynamic>>> getAllFavorites() async {
    final db = await database;
    return db.query('favorites', orderBy: 'saved_at DESC');
  }

  Future<bool> isFavorite(String word) async {
    final db = await database;
    final result = await db.query('favorites', where: 'word = ?', whereArgs: [word]);
    return result.isNotEmpty;
  }

  Future<void> cacheWord(WordEntryModel entry) async {
    final db = await database;
    await db.insert(
      'word_cache',
      {
        'word': entry.word,
        'synonyms_json': jsonEncode(entry.synonyms),
        'sentences_json': jsonEncode(entry.sentences),
        'bangla_meaning': entry.banglaDefinition,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedWord(String word) async {
    final db = await database;
    final rows = await db.query('word_cache', where: 'word = ?', whereArgs: [word]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    final cachedAt = row['cached_at'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (age > AppConstants.cacheDurationHours * 3600 * 1000) {
      await db.delete('word_cache', where: 'word = ?', whereArgs: [word]);
      return null;
    }
    return row;
  }
}
