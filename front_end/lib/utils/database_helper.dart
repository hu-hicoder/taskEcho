import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _useFallback = false; // SQLiteが使用できない場合のフォールバックフラグ
  static const String DB_NAME = 'taskecho.db';

  // シングルトンパターン
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database?> get database async {
    if (_useFallback) {
      print('Using fallback mechanism instead of SQLite');
      return null;
    }

    if (_database != null) return _database!;

    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      print('Error initializing database: $e');
      _useFallback = true;
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      // Get a better location for the database file
      Directory documentsDirectory;
      if (!kIsWeb) {
        // For mobile platforms, use the app documents directory
        documentsDirectory =
            await path_provider.getApplicationDocumentsDirectory();
      } else {
        // For web, we'll still use the default path
        documentsDirectory = Directory(await getDatabasesPath());
      }

      String path = join(documentsDirectory.path, DB_NAME);
      print('Database path: $path');

      // Open the database with WAL mode for better performance
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDb,
        onOpen: (db) async {
          // WAL mode configuration is platform-specific
          // Android doesn't support direct PRAGMA commands through the Flutter SQLite plugin
          // These optimizations are automatically applied on newer Android versions
          print('Database opened successfully');
        },
      );
    } catch (e) {
      print('Error in _initDatabase: $e');
      _useFallback = true;
      throw e;
    }
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
    try {
      final db = await database;
      if (db == null) {
        return await _getKeywordsFromPrefs();
      }

      final List<Map<String, dynamic>> maps = await db.query('keywords');
      return List.generate(maps.length, (i) {
        return maps[i]['keyword'] as String;
      });
    } catch (e) {
      print('Error in getKeywords: $e');
      return await _getKeywordsFromPrefs();
    }
  }

  // SharedPreferencesからキーワードを取得するフォールバック
  Future<List<String>> _getKeywordsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('keywords') ?? [];
  }

  Future<int> insertKeyword(String keyword) async {
    try {
      final db = await database;
      if (db == null) {
        await _saveKeywordToPrefs(keyword);
        return 1;
      }

      return await db.insert(
        'keywords',
        {'keyword': keyword},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      print('Error in insertKeyword: $e');
      await _saveKeywordToPrefs(keyword);
      return 1;
    }
  }

  // SharedPreferencesに単一のキーワードを保存するフォールバック
  Future<void> _saveKeywordToPrefs(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> keywords = prefs.getStringList('keywords') ?? [];
    if (!keywords.contains(keyword)) {
      keywords.add(keyword);
      await prefs.setStringList('keywords', keywords);
    }
  }

  Future<void> deleteKeyword(String keyword) async {
    try {
      final db = await database;
      if (db == null) {
        await _deleteKeywordFromPrefs(keyword);
        return;
      }

      await db.delete(
        'keywords',
        where: 'keyword = ?',
        whereArgs: [keyword],
      );
    } catch (e) {
      print('Error in deleteKeyword: $e');
      await _deleteKeywordFromPrefs(keyword);
    }
  }

  // SharedPreferencesから単一のキーワードを削除するフォールバック
  Future<void> _deleteKeywordFromPrefs(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> keywords = prefs.getStringList('keywords') ?? [];
    keywords.remove(keyword);
    await prefs.setStringList('keywords', keywords);
  }

  Future<void> saveKeywords(List<String> keywords) async {
    try {
      final db = await database;
      if (db == null) {
        await _saveKeywordsToPrefs(keywords);
        return;
      }

      await db.transaction((txn) async {
        // 既存のキーワードを取得
        final List<Map<String, dynamic>> existingKeywords =
            await txn.query('keywords');
        final Set<String> existingKeywordSet =
            existingKeywords.map((k) => k['keyword'] as String).toSet();

        // 新しいキーワードのセット
        final Set<String> newKeywordSet = keywords.toSet();

        // 削除するキーワード（履歴がないもののみ削除）
        final keywordsToDelete = existingKeywordSet.difference(newKeywordSet);
        for (String keyword in keywordsToDelete) {
          // 履歴があるかチェック
          final keywordData = await txn.query(
            'keywords',
            where: 'keyword = ?',
            whereArgs: [keyword],
          );
          if (keywordData.isNotEmpty) {
            final keywordId = keywordData.first['id'] as int;
            final detections = await txn.query(
              'keyword_detections',
              where: 'keyword_id = ?',
              whereArgs: [keywordId],
            );
            
            // 履歴がない場合のみ削除
            if (detections.isEmpty) {
              await txn.delete(
                'keywords',
                where: 'keyword = ?',
                whereArgs: [keyword],
              );
            }
          }
        }

        // 新しいキーワードを挿入
        for (String keyword in keywords) {
          await txn.insert(
            'keywords',
            {'keyword': keyword},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      });
    } catch (e) {
      print('Error in saveKeywords: $e');
      await _saveKeywordsToPrefs(keywords);
    }
  }

  // SharedPreferencesにキーワードリストを保存するフォールバック
  Future<void> _saveKeywordsToPrefs(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', keywords);
  }

  // キーワード検出履歴の操作
  Future<int> saveKeywordDetection(
      String keyword, String className, String contextText) async {
    try {
      final db = await database;
      if (db == null) {
        await _saveDetectionToPrefs(keyword, className, contextText);
        return 1;
      }

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
    } catch (e) {
      print('Error in saveKeywordDetection: $e');
      await _saveDetectionToPrefs(keyword, className, contextText);
      return 1;
    }
  }

  // SharedPreferencesに検出履歴を保存するフォールバック
  Future<void> _saveDetectionToPrefs(
      String keyword, String className, String contextText) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> detections = prefs.getStringList('keyword_detections') ?? [];

    // JSON形式で保存
    final detection = {
      'keyword': keyword,
      'class_name': className,
      'context_text': contextText,
      'detected_at': DateTime.now().toIso8601String(),
    };

    detections.add(detection.toString());
    await prefs.setStringList('keyword_detections', detections);
  }

  Future<List<Map<String, dynamic>>> getKeywordDetections() async {
    try {
      final db = await database;
      if (db == null) {
        return await _getDetectionsFromPrefs();
      }

      return await db.rawQuery('''
        SELECT kd.id, k.keyword, kd.class_name, kd.context_text, kd.detected_at
        FROM keyword_detections kd
        JOIN keywords k ON kd.keyword_id = k.id
        ORDER BY kd.detected_at DESC
      ''');
    } catch (e) {
      print('Error in getKeywordDetections: $e');
      return await _getDetectionsFromPrefs();
    }
  }

  Future<List<Map<String, dynamic>>> getKeywordDetectionsByClass(
      String className) async {
    try {
      final db = await database;
      if (db == null) {
        return await _getDetectionsByClassFromPrefs(className);
      }

      return await db.rawQuery('''
        SELECT kd.id, k.keyword, kd.class_name, kd.context_text, kd.detected_at
        FROM keyword_detections kd
        JOIN keywords k ON kd.keyword_id = k.id
        WHERE kd.class_name = ?
        ORDER BY kd.detected_at DESC
      ''', [className]);
    } catch (e) {
      print('Error in getKeywordDetectionsByClass: $e');
      return await _getDetectionsByClassFromPrefs(className);
    }
  }

  // SharedPreferencesから検出履歴を取得するフォールバック
  Future<List<Map<String, dynamic>>> _getDetectionsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> detections = prefs.getStringList('keyword_detections') ?? [];

    // 文字列からマップに変換
    List<Map<String, dynamic>> result = [];
    for (int i = 0; i < detections.length; i++) {
      try {
        // 簡易的な文字列からマップへの変換（実際にはJSONパースが望ましい）
        String detection = detections[i];
        Map<String, dynamic> map = {
          'id': i,
          'keyword': _extractValue(detection, 'keyword'),
          'class_name': _extractValue(detection, 'class_name'),
          'context_text': _extractValue(detection, 'context_text'),
          'detected_at': _extractValue(detection, 'detected_at'),
        };
        result.add(map);
      } catch (e) {
        print('Error parsing detection: $e');
      }
    }

    // 日付の降順でソート
    result.sort((a, b) => b['detected_at'].compareTo(a['detected_at']));
    return result;
  }

  // SharedPreferencesから特定のクラスの検出履歴を取得するフォールバック
  Future<List<Map<String, dynamic>>> _getDetectionsByClassFromPrefs(
      String className) async {
    List<Map<String, dynamic>> allDetections = await _getDetectionsFromPrefs();
    return allDetections.where((d) => d['class_name'] == className).toList();
  }

  // 文字列からキーと値を抽出するヘルパーメソッド
  String _extractValue(String text, String key) {
    RegExp regex = RegExp('$key: ([^,}]+)');
    Match? match = regex.firstMatch(text);
    return match?.group(1) ?? '';
  }
}
