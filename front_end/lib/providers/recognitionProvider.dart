import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer';

class RecognitionProvider with ChangeNotifier {
  bool _isRecognizing = false;
  bool _speechEnabled = false;
  String _lastWords = '';
  int resetRecognition = 200; // 認識文字数がこの値を超えたらリセット
  final SpeechToText _speechToText = SpeechToText();

  bool get isRecognizing => _isRecognizing;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;

  RecognitionProvider() {
    _initSpeech();
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
      notifyListeners();

      await _speechToText.listen(
        onResult: _onSpeechResult,
        partialResults: true,
        localeId: "ja_JP",
        listenMode: ListenMode.dictation,
      );

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
    _lastWords += " " + result.recognizedWords;
    print('onSpeechResult: $_lastWords');
    
    notifyListeners(); // UIを更新

    // もし認識が止まったら自動で再開
    if (!_speechToText.isListening && _isRecognizing) {
      Future.delayed(Duration(seconds: 1), () {
        if (_isRecognizing) startListening(); // 🔥 停止中でなければ再開
      });
    }

    // _lastWords が文字を超えた場合に音声認識を再起動
    if (_lastWords.length > resetRecognition) {
      await stopListening();
      _lastWords = ''; // リセット
      await startListening();
    }
  }
}
