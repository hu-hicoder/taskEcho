import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class KeywordProvider with ChangeNotifier {
  List<String> _keywords = [];

  List<String> get keywords => _keywords;

  KeywordProvider() {
    loadKeywords();
  }

  Future<void> loadKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    _keywords = prefs.getStringList('keywords') ?? [];
    notifyListeners();
  }

  Future<void> saveKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    _keywords = keywords;
    await prefs.setStringList('keywords', keywords);
    notifyListeners();
  }

  Future<void> addKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();

    // キーワードが既に存在しない場合のみ追加
    if (!_keywords.contains(keyword)) {
      _keywords.add(keyword); // 新しいキーワードをリストに追加
      await prefs.setStringList('keywords', _keywords); // 更新後のリストを保存
      notifyListeners(); // リスナーに変更を通知
    } else {
      print('キーワード "$keyword" は既に存在します');
    }
  }

  Future<List<String>> detectKeywords(String transcript) async {
    return _keywords.where((k) => transcript.contains(k)).toList();
  }

  Future<void> deleteKeywords(int index) async {
    final prefs = await SharedPreferences.getInstance();

    // インデックスが有効か確認
    if (index >= 0 && index < _keywords.length) {
      _keywords.removeAt(index); // 指定されたインデックスの要素を削除
      await prefs.setStringList('keywords', _keywords); // 更新後のリストを保存
      notifyListeners(); // リスナーに変更を通知
    } else {
      print('無効なインデックス: $index');
    }
  }
}
