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

  Future<List<String>> detectKeywords(String transcript) async {
    return _keywords.where((k) => transcript.contains(k)).toList();
  }
}
