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
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RecognitionProvider with ChangeNotifier {
  bool _isRecognizing = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  final apiKey = dotenv.env['GEMINI_API_KEY'];

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
            if (error.errorMsg == "error_speech_timeout" && _isRecognizing) {
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
    notifyListeners(); // UIを更新

    // 音声認識が停止していないか確認し、再開する
    if (!_speechToText.isListening && _isRecognizing) {
      print("キャッシュクリア後に音声認識を再開します...");
      startListening(); // 音声認識を再開
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
    _lastWords = " " + result.recognizedWords;
    print('onSpeechResult: $_lastWords');

    notifyListeners(); // UIを更新

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

  /// テキストからキーワードを含む部分の前後の文脈を抽出する
  Future<String> extractSnippetWithKeyword(String text, List<String> keywords) async {
    // 最初に見つかったキーワードを使用
    String keyword = keywords.first;

    // キーワードの位置を見つける
    int keywordIndex = text.indexOf(keyword);
    if (keywordIndex == -1) return text; // キーワードが見つからない場合は全文を返す

    // 前後の文脈を含めるための範囲を計算（前後100文字程度）
    int startIndex = (keywordIndex - 100) < 0 ? 0 : keywordIndex - 100;
    int endIndex = (keywordIndex + keyword.length + 100) > text.length
        ? text.length
        : keywordIndex + keyword.length + 100;
    
    // 抽出したテキスト
    String extractedText = text.substring(startIndex, endIndex);
    
    // 要約のプレースホルダー（将来的にGemini APIを使用して要約する予定）
    String summary = "【キーワード「$keyword」の周辺テキスト】: $extractedText";
    
    print('キーワード "$keyword" の周辺テキストを抽出: $summary');
    return summary;
  }

  /// バックエンドにデータを送信する
  Future<void> _sendToBackend(String snippet, List<String> keywords) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/process_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': snippet,
          'keywords': keywords,
        }),
      );

      if (response.statusCode == 200) {
        print('バックエンドにデータを送信しました: $snippet');
      } else {
        print('バックエンドへのデータ送信に失敗しました: ${response.statusCode}');
      }
    } catch (e) {
      print('バックエンドへのデータ送信中にエラーが発生しました: $e');
    }
  }

  /// クラスが破棄されるときにタイマーをキャンセル
  @override
  void dispose() {
    _cacheClearTimer?.cancel(); // タイマーを停止
    super.dispose();
  }
}
