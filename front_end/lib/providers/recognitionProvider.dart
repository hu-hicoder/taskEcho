import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart'; //ローカルにキーワードを保存するパッケージ
import './keywordProvider.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class RecognitionProvider with ChangeNotifier {
  bool _isRecognizing = false;
  bool _speechEnabled = false;
  String _lastWords = '';

  final SpeechToText _speechToText = SpeechToText();
  Timer? _cacheClearTimer; // キャッシュクリア用のタイマー

  bool get isRecognizing => _isRecognizing;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;

  RecognitionProvider() {
    _initSpeech();
    _startCacheClearTimer();
  }

  Future<void> saveKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', keywords);
  }

  Future<List<String>> loadKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('keywords') ?? [];
  }

  /// 初期化処理（アプリ起動時に1回だけ実行）
  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        print("SpeechToTextのステータス: $status");
      },
      onError: (error) {
        print("SpeechToTextのエラー: $error"); // ← エラーを確認
      },
    );
    log('Speech recognition available: $_speechEnabled');
    notifyListeners(); // 状態が変わったことを通知
  }

  /// キャッシュクリアタイマーを開始
  void _startCacheClearTimer() {
    _cacheClearTimer?.cancel(); // 既存のタイマーをキャンセル
    _cacheClearTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      _clearCache();
    });
  }

  /// キャッシュをクリアする
  void _clearCache() {
    print("キャッシュをクリアします");
    _lastWords = ''; // 認識結果をリセット
    notifyListeners(); // UIを更新

    // 音声認識が停止していないか確認し、再開する
    if (!_speechToText.isListening && _isRecognizing) {
      print("キャッシュクリア後に音声認識を再開します...");
      startListening(); // 音声認識を再開
    }
  }

  /// 音声認識を開始（リアルタイム認識）
  Future<void> startListening() async {
    if (!_speechEnabled) {
      print("音声認識が使用できません");
      return;
    }

    bool available = await _speechToText.initialize();

    if (available) {
      print("音声認識を開始します...");
      _isRecognizing = true; // 🔥 `true` に変更して UI を更新

      await _speechToText.listen(
        onResult: _onSpeechResult,
        partialResults: true,
        localeId: "ja_JP",
        listenMode: ListenMode.dictation,
      );
      notifyListeners();
      print("SpeechToText のリスニング開始");
    } else {
      print("SpeechToText の初期化に失敗");
    }
  }

  /// 音声認識を停止
  Future<void> stopListening() async {
    if (!_isRecognizing) return;

    print("音声認識を停止します...");
    _isRecognizing = false;

    notifyListeners(); // UI 更新

    await _speechToText.stop();
  }

  /// 音声認識の結果をリアルタイムで更新
  void _onSpeechResult(SpeechRecognitionResult result) async {
    print("onSpeechResult() が呼ばれました");
    _lastWords = " " + result.recognizedWords;
    print('onSpeechResult: $_lastWords');

    notifyListeners(); // UIを更新

    // もし認識が止まったら自動で再開
    if (!_speechToText.isListening && _isRecognizing) {
      Future.delayed(Duration(seconds: 1), () {
        if (_isRecognizing && !_speechToText.isListening)
          startListening(); // 🔥 停止中でなければ再開
      });
    }

    // キーワードを検出する
    List<String> keywords = await loadKeywords();
    List<String> matchedKeywords =
        keywords.where((keyword) => _lastWords.contains(keyword)).toList();

    if (matchedKeywords.isNotEmpty) {
      print("検出されたキーワード: $matchedKeywords");
      // ここでUIに通知するためにnotifyListenersを呼び出す
      notifyListeners();
    }
  }

  // キーワードを含む文脈を抽出するメソッド
  String extractSnippetWithKeyword(String text, List<String> keywords) {
    // 最初に見つかったキーワードを使用
    String keyword = keywords.first;
    
    // キーワードの位置を見つける
    int keywordIndex = text.indexOf(keyword);
    if (keywordIndex == -1) return text; // キーワードが見つからない場合は全文を返す
    
    // キーワードの前後の文脈を抽出（前後50文字ずつ）
    int startIndex = (keywordIndex - 50) < 0 ? 0 : keywordIndex - 50;
    int endIndex = (keywordIndex + keyword.length + 50) > text.length 
                  ? text.length 
                  : keywordIndex + keyword.length + 50;
    
    return text.substring(startIndex, endIndex);
  }

  /// クラスが破棄されるときにタイマーをキャンセル
  @override
  void dispose() {
    _cacheClearTimer?.cancel(); // タイマーを停止
    super.dispose();
  }
}
