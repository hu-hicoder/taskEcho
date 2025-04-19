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
import 'package:flutter_gemini/flutter_gemini.dart';

class RecognitionProvider with ChangeNotifier {
  bool _isRecognizing = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  final apiKey = dotenv.env['GEMINI_API_KEY'];

  // 認識テキストの履歴を保持するリスト
  List<String> _recognizedTextHistory = [];
  // 履歴の最大サイズ
  final int _maxHistorySize = 20;
  // 結合されたテキスト（キーワード検出用）
  String _combinedText = '';

  final SpeechToText _speechToText = SpeechToText();
  Gemini? _gemini; 
  Timer? _cacheClearTimer; // キャッシュクリア用のタイマー
  bool _geminiInitialized = false; // Geminiの初期化状態を追跡

  bool get isRecognizing => _isRecognizing;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;
  String get combinedText => _combinedText;

  RecognitionProvider() {
    _initSpeech();
    _startCacheClearTimer();
    _initGeminiAsync(); // 非同期初期化を呼び出す
  }

  // 非同期初期化を呼び出すためのヘルパーメソッド
  void _initGeminiAsync() {
    _initGemini().then((_) {
      // 初期化完了後の処理（必要に応じて）
      if (_geminiInitialized) {
        print('Gemini初期化が完了しました');
      } else {
        print('Gemini初期化に失敗しました');
      }
    });
  }

  /// Gemini APIの初期化
  Future<void> _initGemini() async {
    try {
      if (apiKey != null) {
        // APIキーが設定されている場合のみ初期化を試みる
        print('Gemini APIの初期化を開始します: $apiKey');
        
        try {
          Gemini.init(apiKey: apiKey!, enableDebugging: true);
          _gemini = Gemini.instance;
          
          // 初期化テスト - 簡単なプロンプトを送信して応答を確認
          final testResult = await _gemini!.text('テスト');
          if (testResult != null && testResult.output != null) {
            _geminiInitialized = true;
            print('Gemini API initialized successfully: ${testResult.output}');
          } else {
            print('Gemini API test returned null result');
          }
        } catch (initError) {
          print('Gemini API initialization specific error: $initError');
          
          // 別の初期化方法を試す
          try {
            print('Trying alternative initialization method...');
            // 別の初期化方法を試す（configureTransportはないので代替手段）
            Gemini.init(apiKey: apiKey!);
            _gemini = Gemini.instance;
            
            final testResult = await _gemini!.text('テスト');
            if (testResult != null && testResult.output != null) {
              _geminiInitialized = true;
              print('Alternative Gemini API initialization successful: ${testResult.output}');
            }
          } catch (altError) {
            print('Alternative initialization also failed: $altError');
          }
        }
      } else {
        print('GEMINI_API_KEYが設定されていません。.envファイルを確認してください。');
      }
    } catch (e) {
      print('Gemini API initialization error: $e');
    }
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

  /// テキストからキーワードを含む部分の前後の文脈を抽出し、可能であればGeminiで要約する
  Future<String> extractSnippetWithKeyword(String text, List<String> keywords) async {
    // 最初に見つかったキーワードを使用
    String keyword = keywords.first;
    
    // 結合テキストを使用（履歴からの情報を含む）
    String textToSearch = _combinedText.isNotEmpty ? _combinedText : text;
    
    // キーワードの位置を見つける
    int keywordIndex = textToSearch.indexOf(keyword);
    if (keywordIndex == -1) return text; // キーワードが見つからない場合は全文を返す

    // 前後の文脈を含めるための範囲を計算（前後200文字程度）
    int startIndex = (keywordIndex - 200) < 0 ? 0 : keywordIndex - 200;
    int endIndex = (keywordIndex + keyword.length + 200) > textToSearch.length
        ? textToSearch.length
        : keywordIndex + keyword.length + 200;
    
    // 抽出したテキスト
    String extractedText = textToSearch.substring(startIndex, endIndex);
    String resultText = "【キーワード「$keyword」の周辺テキスト】: $extractedText";
    
    // ネットワーク接続がない場合やGeminiが初期化されていない場合は、
    // 抽出したテキストをそのまま返す（フォールバック）
    if (apiKey == null || !_geminiInitialized || _gemini == null) {
      print('Gemini APIが使用できないため、要約をスキップします。');
      return resultText;
    }
    
    // Geminiによる要約を試みる（ネットワークエラーなどに対応）
    try {
      // Gemini APIに要約を依頼するプロンプト
      String prompt = '''
以下のテキストを要約してください。キーワード「$keyword」に関連する重要な情報を保持しつつ、簡潔にまとめてください。
テキスト: $extractedText
''';
      
      // タイムアウト付きでGemini APIを呼び出す
      final resultFuture = _gemini!.text(prompt);
      final result = await resultFuture.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Gemini API呼び出しがタイムアウトしました。');
          return null;
        },
      );
      
      if (result != null && result.output != null && result.output!.isNotEmpty) {
        print('Geminiによる要約: ${result.output}');
        return "【キーワード「$keyword」の要約】: ${result.output}";
      }
    } catch (e) {
      print('Gemini API呼び出し中にエラーが発生しました: $e');
      // エラーが発生した場合は元のテキストを返す（フォールバック）
    }
    
    // Geminiが使えない場合や要約に失敗した場合は、抽出したテキストをそのまま返す
    return resultText;
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
