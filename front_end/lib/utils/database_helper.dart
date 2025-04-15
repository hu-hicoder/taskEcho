import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // シングルトンパターン
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'taskecho.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    // キーワードテーブル
    await db.execute('''
      CREATE TABLE keywords(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword TEXT NOT NULL UNIQUE
      )
    ''');

    // キーワード検出履歴テーブル
    await db.execute('''
      CREATE TABLE keyword_detections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keyword_id INTEGER NOT NULL,
        class_name TEXT NOT NULL,
        context_text TEXT NOT NULL,
        detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (keyword_id) REFERENCES keywords (id) ON DELETE CASCADE
      )
    ''');
  }

  // キーワード関連の操作
  Future<List<String>> getKeywords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('keywords');
    return List.generate(maps.length, (i) {
      return maps[i]['keyword'] as String;
    });
  }

  Future<int> insertKeyword(String keyword) async {
    final db = await database;
    return await db.insert(
      'keywords',
      {'keyword': keyword},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> deleteKeyword(String keyword) async {
    final db = await database;
    await db.delete(
      'keywords',
      where: 'keyword = ?',
      whereArgs: [keyword],
    );
  }

  Future<void> saveKeywords(List<String> keywords) async {
    final db = await database;
    await db.transaction((txn) async {
      // 既存のキーワードを全て削除
      await txn.delete('keywords');

      // 新しいキーワードを挿入
      for (String keyword in keywords) {
        await txn.insert(
          'keywords',
          {'keyword': keyword},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  // キーワード検出履歴の操作
  Future<int> saveKeywordDetection(
      String keyword, String className, String contextText) async {
    final db = await database;

    // まずキーワードのIDを取得（なければ挿入）
    int keywordId;
    List<Map<String, dynamic>> keywordMaps = await db.query(
      'keywords',
      where: 'keyword = ?',
      whereArgs: [keyword],
    );

    if (keywordMaps.isEmpty) {
      keywordId = await insertKeyword(keyword);
    } else {
      keywordId = keywordMaps.first['id'] as int;
    }

    // 検出履歴を保存
    return await db.insert(
      'keyword_detections',
      {
        'keyword_id': keywordId,
        'class_name': className,
        'context_text': contextText,
        'detected_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> getKeywordDetections() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT kd.id, k.keyword, kd.class_name, kd.context_text, kd.detected_at
      FROM keyword_detections kd
      JOIN keywords k ON kd.keyword_id = k.id
      ORDER BY kd.detected_at DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getKeywordDetectionsByClass(
      String className) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT kd.id, k.keyword, kd.class_name, kd.context_text, kd.detected_at
      FROM keyword_detections kd
      JOIN keywords k ON kd.keyword_id = k.id
      WHERE kd.class_name = ?
      ORDER BY kd.detected_at DESC
    ''', [className]);
  }
}
