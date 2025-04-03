import 'package:flutter/material.dart';

class KeywordProvider with ChangeNotifier {
  List<String> _keywords = [
    "重要",
    "大事",
    "課題",
    "提出",
    "テスト",
    "レポート",
    "締め切り",
    "期限",
    "動作確認"
  ];

  List<String> get keywords => _keywords;

  void addKeyword(String keyword) {
    _keywords.add(keyword);
    notifyListeners();
  }

  void removeKeyword(int index) {
    _keywords.removeAt(index);
    notifyListeners();
  }
}
