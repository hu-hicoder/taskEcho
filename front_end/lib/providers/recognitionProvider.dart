import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../services/summaryService.dart';

class RecognitionProvider with ChangeNotifier {
  bool _isRecognizing = false;
  bool _speechEnabled = false;
  String _lastWords = '';

  // 認識テキストの履歴を保持するリスト
  List<String> _recognizedTextHistory = [];
  // 履歴の最大サイズ
  final int _maxHistorySize = 20;
  // 結合されたテキスト（キーワード検出用）
  String _combinedText = '';

  final SpeechToText _speechToText = SpeechToText();
  Timer? _cacheClearTimer; // キャッシュクリア用のタイマー

  bool get isRecognizing => _isRecognizing;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;
  String get combinedText => _combinedText;

  RecognitionProvider() {
    _initSpeech();
    _startCacheClearTimer();
    // SummaryServiceの設定は自動初期化されるため、明示的な初期化は不要
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
    try {
      // マイク権限をリクエスト
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _speechEnabled = await _speechToText.initialize(
          onStatus: (status) {
            print("SpeechToTextのステータス: $status");
          },
          onError: (error) {
            print("SpeechToTextのエラー: $error"); // ← エラーを確認
            // エラーが発生した場合、特にタイムアウトエラーの場合は再初期化を試みる
            if (_isRecognizing &&
               (error.errorMsg == "error_speech_timeout" ||
                error.errorMsg == "error_no_match")) {
              Future.delayed(Duration(milliseconds: 500), () {
                startListening();
              });
            }
          },
        );
        log('Speech recognition available: $_speechEnabled');
      } else {
        log('Microphone permission denied');
        _speechEnabled = false;
      }
      notifyListeners(); // 状態が変わったことを通知
    } catch (e) {
      log('Error initializing speech: $e');
      _speechEnabled = false;
      notifyListeners();
    }
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
    _recognizedTextHistory.clear(); // 履歴をクリア
    _combinedText = ''; // 結合テキストをクリア
    notifyListeners(); // UIを更新

    // 音声認識が停止していないか確認し、再開する
    if (!_speechToText.isListening && _isRecognizing) {
      print("キャッシュクリア後に音声認識を再開します...");
      startListening(); // 音声認識を再開
    }
  }

  /// 履歴から結合テキストを作成
  void _updateCombinedText() {
    _combinedText = _recognizedTextHistory.join(' ');
    // 長すぎる場合は最新の部分を優先
    if (_combinedText.length > 5000) {
      _combinedText = _combinedText.substring(_combinedText.length - 5000);
    }
  }

  /// 音声認識を開始（リアルタイム認識）
  Future<void> startListening() async {
    try {
      if (!_speechEnabled) {
        print("音声認識が使用できません");
        // 再度初期化を試みる
        await _initSpeech();
        if (!_speechEnabled) {
          return;
        }
      }

      print("音声認識を開始します...");
      _isRecognizing = true; // 🔥 `true` に変更して UI を更新
      notifyListeners();

      await _speechToText.listen(
        onResult: _onSpeechResult,
        partialResults: true,
        localeId: "ja_JP",
        pauseFor: Duration(seconds: 60),
        listenMode: ListenMode.dictation,
      );
      print("SpeechToText のリスニング開始");
    } catch (e) {
      print("音声認識の開始中にエラーが発生しました: $e");
      _isRecognizing = false;
      notifyListeners();
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
    String newText = result.recognizedWords.trim();
    
    // 新しいテキストが空でなく、前回と異なる場合のみ処理
    if (newText.isNotEmpty && newText != _lastWords.trim()) {
      _lastWords = " " + newText;
      print('onSpeechResult: $_lastWords');
      
      // 履歴に追加
      if (newText.length > 3) { // 短すぎるテキストは無視
        _recognizedTextHistory.add(newText);
        // 履歴が長すぎる場合は古いものを削除
        if (_recognizedTextHistory.length > _maxHistorySize) {
          _recognizedTextHistory.removeAt(0);
        }
        // 結合テキストを更新
        _updateCombinedText();
      }

      notifyListeners(); // UIを更新
    }

    // もし認識が止まったら自動で再開
    if (!_speechToText.isListening && _isRecognizing) {
      Future.delayed(Duration(milliseconds: 200), () {
        if (_isRecognizing && !_speechToText.isListening) {
          startListening(); // 🔥 停止中でなければ再開
        }
      });
    }

    // キーワードの検出はVoiceRecognitionPageで行うため、ここでは何もしない
    // UIコンポーネントでKeywordProviderを使用して検出する
  }

  /// テキストからキーワードを含む部分の前後の文脈を抽出し、SummaryServiceで要約する
  Future<String> extractSnippetWithKeyword(String text, List<String> keywords) async {
    // SummaryServiceを使用してキーワード周辺テキストの抽出・要約を実行
    return await SummaryService.extractAndSummarize(
      _combinedText.isNotEmpty ? _combinedText : text,
      keywords,
    );
  }

  /// クラスが破棄されるときにタイマーをキャンセル
  @override
  void dispose() {
    _cacheClearTimer?.cancel(); // タイマーを停止
    super.dispose();
  }
}
