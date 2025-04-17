import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/database_helper.dart';

class KeywordProvider with ChangeNotifier {
  List<String> _keywords = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<String> get keywords => _keywords;

  KeywordProvider() {
    loadKeywords();
  }

  // キーワードを追加するメソッド
  Future<void> addKeyword(String keyword) async {
    if (!_keywords.contains(keyword)) {
      _keywords.add(keyword);
      await saveKeywords(_keywords);
    }
  }

  // キーワードを削除するメソッド
  Future<void> removeKeyword(int index) async {
    if (index >= 0 && index < _keywords.length) {
      _keywords.removeAt(index);
      await saveKeywords(_keywords);
    }
  }

  Future<void> loadKeywords() async {
    try {
      _keywords = await _dbHelper.getKeywords();
      notifyListeners();
    } catch (e) {
      print('キーワードの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<void> saveKeywords(List<String> keywords) async {
    try {
      _keywords = keywords;
      await _dbHelper.saveKeywords(keywords);
      notifyListeners();
    } catch (e) {
      print('キーワードの保存中にエラーが発生しました: $e');
    }
  }

  Future<void> addKeywords(String keyword) async {
    // キーワードが既に存在しない場合のみ追加
    if (!_keywords.contains(keyword)) {
      try {
        await _dbHelper.insertKeyword(keyword);
        _keywords.add(keyword); // 新しいキーワードをリストに追加
        notifyListeners(); // リスナーに変更を通知
      } catch (e) {
        print('キーワードの追加中にエラーが発生しました: $e');
      }
    } else {
      print('キーワード "$keyword" は既に存在します');
    }
  }

  Future<List<String>> detectKeywords(String transcript) async {
    return _keywords.where((k) => transcript.contains(k)).toList();
  }

  Future<void> deleteKeywords(int index) async {
    // インデックスが有効か確認
    if (index >= 0 && index < _keywords.length) {
      try {
        String keyword = _keywords[index];
        await _dbHelper.deleteKeyword(keyword);
        _keywords.removeAt(index); // 指定されたインデックスの要素を削除
        notifyListeners(); // リスナーに変更を通知
      } catch (e) {
        print('キーワードの削除中にエラーが発生しました: $e');
      }
    } else {
      print('無効なインデックス: $index');
    }
  }

  // キーワード検出履歴を保存
  Future<void> saveKeywordDetection(
      String keyword, String className, String contextText) async {
    try {
      await _dbHelper.saveKeywordDetection(keyword, className, contextText);
    } catch (e) {
      print('キーワード検出履歴の保存中にエラーが発生しました: $e');
    }
  }

  // 特定の授業のキーワード検出履歴を取得
  Future<List<Map<String, dynamic>>> getKeywordDetectionsByClass(
      String className) async {
    try {
      return await _dbHelper.getKeywordDetectionsByClass(className);
    } catch (e) {
      print('キーワード検出履歴の取得中にエラーが発生しました: $e');
      return [];
    }
  }

  // 全てのキーワード検出履歴を取得
  Future<List<Map<String, dynamic>>> getAllKeywordDetections() async {
    try {
      return await _dbHelper.getKeywordDetections();
    } catch (e) {
      print('キーワード検出履歴の取得中にエラーが発生しました: $e');
      return [];
    }
  }
}
