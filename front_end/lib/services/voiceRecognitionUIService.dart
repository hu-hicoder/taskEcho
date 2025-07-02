import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/classProvider.dart';
import '../providers/textsDataProvider.dart';
import '../providers/recognitionProvider.dart';
import '../providers/keywordProvider.dart';
import 'voiceRecognitionService.dart';

class VoiceRecognitionUIService extends ChangeNotifier {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();

  // UI状態管理用の変数
  List<String> recognizedTexts = ["認識結果1", "認識結果2", "認識結果3"];
  List<String> summarizedTexts = ["要約1", "要約2", "要約3"];
  String keyword = "キーワード検出待機中";
  List<String> detectedKeywords = [];

  // タイマー関連
  Timer? timer;
  Timer? flashTimer;
  Timer? autoResetTimer;

  // UI状態フラグ
  bool isFlashing = false;
  bool showGradient = true;
  bool existKeyword = false;
  Color backgroundColor = Colors.indigoAccent;
  int currentIndex = 0;

  // コンストラクタでコントローラーを初期化
  final TextEditingController classController = TextEditingController();

  // 音声認識結果を取得する関数
  Future<void> fetchRecognizedText(BuildContext context) async {
    final textsDataProvider =
        Provider.of<TextsDataProvider>(context, listen: false);
    final selectedClass =
        Provider.of<ClassProvider>(context, listen: false).selectedClass;
    final recognitionProvider =
        Provider.of<RecognitionProvider>(context, listen: false);
    final keywordProvider =
        Provider.of<KeywordProvider>(context, listen: false);

    try {
      // 認識結果を取得
      String newRecognizedText = recognitionProvider.lastWords;

      if (newRecognizedText.isNotEmpty) {
        // データ処理サービスを使用
        final processedData = _voiceService.processRecognitionData(
          newRecognizedText,
          selectedClass,
          textsDataProvider,
          keywordProvider,
          recognitionProvider,
        );

        // UIの更新用にデータを格納
        detectedKeywords = processedData.detectedKeywords;
        existKeyword = processedData.hasKeyword;

        // リストの更新
        _updateTextLists(
            processedData.recognizedText, processedData.summarizedText);

        // キーワードに応じて点滅処理を実行
        if (existKeyword) {
          keyword = "検出: ${detectedKeywords.join(', ')}";
          startFlashing();

          // キーワードごとに1分後にDBに保存
          for (String detectedKeyword in detectedKeywords) {
            _voiceService.saveKeywordWithDelay(
              newRecognizedText,
              detectedKeyword,
              selectedClass,
              keywordProvider,
              recognitionProvider,
            );
          }
        } else {
          stopFlashing();
        }

        // UIの更新を通知
        notifyListeners();
      }
    } catch (e) {
      print('エラーが発生しました: $e');
      recognizedTexts[currentIndex] = "データ取得エラー";
    }
  }

  // テキストリストの更新
  void _updateTextLists(String recognizedText, String summarizedText) {
    if (recognizedTexts.length > 3) {
      recognizedTexts.removeAt(0);
      summarizedTexts.removeAt(0);
    }
    recognizedTexts.add(recognizedText);
    summarizedTexts.add(summarizedText);

    if (recognizedText.length > 100) {
      recognizedTexts = ["", "", ""];
      summarizedTexts = ["", "", ""];
    }
    currentIndex = recognizedTexts.length - 1;
  }

  // 点滅を開始する
  void startFlashing() {
    if (!isFlashing) {
      isFlashing = true;
      showGradient = false;

      // 既存のタイマーをキャンセル
      flashTimer?.cancel();
      autoResetTimer?.cancel();

      // 点滅タイマーを開始
      flashTimer = Timer.periodic(Duration(milliseconds: 500), (Timer t) {
        // 交互に赤と白を切り替える
        backgroundColor = (backgroundColor == Colors.redAccent)
            ? Colors.white
            : Colors.redAccent;
        notifyListeners(); // UI更新を通知
      });

      // 10秒後に自動的に点滅を停止するタイマーを設定
      autoResetTimer = Timer(Duration(seconds: 10), () {
        stopFlashing();
      });
    }
  }

  // 点滅を停止する
  void stopFlashing() {
    if (flashTimer != null) {
      flashTimer?.cancel();
      flashTimer = null;
    }
    isFlashing = false;
    showGradient = true;
    notifyListeners(); // UI更新を通知
  }

  // 音声認識停止時にキーワード表示をリセットする
  void resetKeywordDisplay() {
    keyword = "キーワード検出待機中";
    existKeyword = false;
  }

  // 音声認識の開始
  Future<void> startRecording(BuildContext context) async {
    final recognitionProvider =
        Provider.of<RecognitionProvider>(context, listen: false);

    if (recognitionProvider.isRecognizing) {
      print("⚠️ すでに音声認識中です。");
      return;
    }

    recognitionProvider.startListening();
    print("🎤 音声認識を開始しました");

    // 定期的にデータを取得するためのタイマーを設定
    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (recognitionProvider.isRecognizing) {
        fetchRecognizedText(context);
      } else {
        t.cancel();
      }
    });
  }

  // 音声認識の停止
  Future<void> stopRecording(BuildContext context) async {
    final recognitionProvider =
        Provider.of<RecognitionProvider>(context, listen: false);

    if (!recognitionProvider.isRecognizing) {
      print("⚠️ 音声認識は開始されていません。");
      return;
    }

    // 最後の保留中テキストがあれば保存
    final textsDataProvider =
        Provider.of<TextsDataProvider>(context, listen: false);
    final selectedClass =
        Provider.of<ClassProvider>(context, listen: false).selectedClass;

    _voiceService.savePendingTextOnStop(selectedClass, textsDataProvider);

    recognitionProvider.stopListening();
    timer?.cancel();
    stopFlashing();
    resetKeywordDisplay();

    print("🛑 音声認識を停止しました");
  }

  // リソースの解放
  @override
  void dispose() {
    timer?.cancel();
    flashTimer?.cancel();
    autoResetTimer?.cancel();
    classController.dispose();
    super.dispose();
  }
}
