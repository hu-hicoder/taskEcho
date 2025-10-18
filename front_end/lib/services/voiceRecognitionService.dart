import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speech_to_text/services/googleCalendarService.dart';
import 'package:http/http.dart' as http;
import '../providers/textsDataProvider.dart';
import '../providers/recognitionProvider.dart';
import '../providers/keywordProvider.dart';

// 遅延保存用のデータを保持するクラス
class DelayedKeywordData {
  final String keyword;
  final String className;
  final DateTime detectionTime;
  final String initialText;

  DelayedKeywordData({
    required this.keyword,
    required this.className,
    required this.detectionTime,
    required this.initialText,
  });
}

// Google カレンダー API 用 HTTP クライアント
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  GoogleHttpClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }
}

// データ処理結果を格納するクラス
class ProcessedData {
  final String recognizedText;
  final String summarizedText;
  final List<String> detectedKeywords;
  final bool hasKeyword;

  ProcessedData({
    required this.recognizedText,
    required this.summarizedText,
    required this.detectedKeywords,
    required this.hasKeyword,
  });
}

class VoiceRecognitionService {
  // キーワード保存の重複を防ぐためのマップ
  Map<String, DateTime> _lastSavedKeywords = {};
  // キーワード保存のクールダウン時間（秒）
  final int _keywordSaveCooldown = 60;
  // 遅延保存用のデータを保持するマップ
  Map<String, DelayedKeywordData> _pendingKeywordData = {};

  // 現在のフレーズで検出済みのキーワード（点滅の重複防止用）
  Set<String> _detectedKeywordsInCurrentPhrase = {};

  // フレーズ管理用の変数
  String _previousRecognizedText = "";
  String _pendingText = "";
  String _currentPhrasePrefix = "";
  int maxWords = 100;

  // 呼び出し済みのsummarizedTextsを追跡するセット
  Set<String> calledeventTime = {};

  // フレーズ変更時の更新処理
  void updatePhraseIfNeeded(String newRecognizedText, String selectedClass,
      TextsDataProvider textsDataProvider) {
    if (_previousRecognizedText != newRecognizedText &&
        newRecognizedText.length > 5) {
      // 新しいテキストの最初の5文字を取得
      String newPrefix = newRecognizedText.substring(0, 5);

      // 現在のフレーズの最初の5文字が変わったかチェック
      if (_currentPhrasePrefix != newPrefix) {
        // 新しいフレーズに変わった！

        // 新しいフレーズになったので検出済みキーワードをリセット
        _detectedKeywordsInCurrentPhrase.clear();

        // 前のフレーズの最終版があれば更新
        if (_pendingText.isNotEmpty) {
          textsDataProvider.addRecognizedText(selectedClass, _pendingText);
          textsDataProvider.addSummarizedText(selectedClass, _pendingText);
        }

        // 新しいフレーズの情報を保存
        _currentPhrasePrefix = newPrefix;
        _pendingText = newRecognizedText;
        _previousRecognizedText = newRecognizedText;
      } else {
        // 同じフレーズの延長
        _pendingText = newRecognizedText; // より長いバージョンを保持
        _previousRecognizedText = newRecognizedText;
      }
    }
  }

  // キーワード検出時に1分後にDBに保存するための関数
  void saveKeywordWithDelay(
      String text,
      String keyword,
      String selectedClass,
      KeywordProvider keywordProvider,
      RecognitionProvider recognitionProvider) {
    // キーワードとクラス名の組み合わせで一意のキーを作成
    String uniqueKey = "$keyword:$selectedClass";
    DateTime now = DateTime.now();

    // 前回の保存時間を取得
    DateTime? lastSaved = _lastSavedKeywords[uniqueKey];

    // 前回の保存から指定時間が経過しているか、または初めての保存の場合
    if (lastSaved == null ||
        now.difference(lastSaved).inSeconds > _keywordSaveCooldown) {
      // 保存時間を更新（重複防止のため先に記録）
      _lastSavedKeywords[uniqueKey] = now;

      // 保存予定のデータを記録
      _pendingKeywordData[uniqueKey] = DelayedKeywordData(
        keyword: keyword,
        className: selectedClass,
        detectionTime: now,
        initialText: text,
      );

      print('キーワード "$keyword" を検出: 1分後に保存します');

      // 1分後に保存を実行
      Future.delayed(Duration(seconds: 20), () async {
        await _executeDelayedSave(
            uniqueKey, keyword, keywordProvider, recognitionProvider);
      });
    } else {
      // クールダウン中の場合
      int secondsLeft =
          _keywordSaveCooldown - now.difference(lastSaved).inSeconds;
      print('キーワード "$keyword" は最近検出されました。'
          '次の検出まで約${secondsLeft}秒待機します。');
    }
  }

  // 遅延保存の実行
  Future<void> _executeDelayedSave(
      String uniqueKey,
      String keyword,
      KeywordProvider keywordProvider,
      RecognitionProvider recognitionProvider) async {
    try {
      // 保存予定のデータを取得
      final keywordData = _pendingKeywordData[uniqueKey];
      if (keywordData == null) {
        print('キーワード "$keyword" の保存データが見つかりません');
        return;
      }

      // 結合テキストまたは現在の認識テキストを取得（1分後の状態）
      String combinedText = recognitionProvider.combinedText;
      String currentText = recognitionProvider.lastWords;

      // 結合テキスト、現在のテキスト、1分前のテキストを比較し、最も情報量の多いテキストを使用
      String textToUse = combinedText.isNotEmpty
          ? combinedText
          : (currentText.length > keywordData.initialText.length
              ? currentText
              : keywordData.initialText);

      // キーワードを含むスニペットを抽出
      String snippet = await recognitionProvider
          .extractSnippetWithKeyword(textToUse, [keyword]);

      // SQLiteに保存
      await keywordProvider.saveKeywordDetection(
          keyword, keywordData.className, snippet);

      print('キーワード "$keyword" を保存しました: $snippet');

      // 日時パターン検出とカレンダー登録
      await _processCalendarRegistration(snippet, keywordData.detectionTime);

      // 保存が完了したらマップから削除
      _pendingKeywordData.remove(uniqueKey);
    } catch (e) {
      print('キーワード "$keyword" の保存中にエラーが発生しました: $e');
      // エラーが発生した場合もマップから削除
      _pendingKeywordData.remove(uniqueKey);
    }
  }

  // カレンダー登録処理
  Future<void> _processCalendarRegistration(
      String snippet, DateTime detectionTime) async {
    final now = detectionTime;
    DateTime? eventDt;

    // 1. 相対日＋時刻：「今日」「明日」「明後日」
    final rel =
        RegExp(r'(今日|明日|明後日)(?:\s*(\d{1,2}:\d{2}))?').firstMatch(snippet);
    if (rel != null) {
      int days = rel.group(1) == '明日'
          ? 1
          : rel.group(1) == '明後日'
              ? 2
              : 0;
      final base = now.add(Duration(days: days));
      if (rel.group(2) != null) {
        final p = rel.group(2)!.split(':');
        eventDt = DateTime(
            base.year, base.month, base.day, int.parse(p[0]), int.parse(p[1]));
      } else {
        eventDt = DateTime(base.year, base.month, base.day, 9, 0);
      }
    }
    // 2. 「YYYY/MM/DD [HH:mm]」
    else {
      final ymd =
          RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:\s*(\d{1,2}:\d{2}))?')
              .firstMatch(snippet);
      if (ymd != null) {
        final y = int.parse(ymd.group(1)!),
            m = int.parse(ymd.group(2)!),
            d = int.parse(ymd.group(3)!);
        if (ymd.group(4) != null) {
          final p = ymd.group(4)!.split(':');
          eventDt = DateTime(y, m, d, int.parse(p[0]), int.parse(p[1]));
        } else {
          eventDt = DateTime(y, m, d, 9, 0);
        }
      }
      // 3. 「M月D日 [HH:mm]」
      else {
        final md = RegExp(r'(\d{1,2})月(\d{1,2})日(?:\s*(\d{1,2}:\d{2}))?')
            .firstMatch(snippet);
        if (md != null) {
          final m = int.parse(md.group(1)!), d = int.parse(md.group(2)!);
          if (md.group(3) != null) {
            final p = md.group(3)!.split(':');
            eventDt =
                DateTime(now.year, m, d, int.parse(p[0]), int.parse(p[1]));
          } else {
            eventDt = DateTime(now.year, m, d, 9, 0);
          }
        }
        // 4. 時刻のみ「HH:mm」
        else {
          final t = RegExp(r'(\d{1,2}:\d{2})').firstMatch(snippet);
          if (t != null) {
            final p = t.group(1)!.split(':');
            eventDt = DateTime(
                now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
          }
        }
      }
    }

    if (eventDt != null && FirebaseAuth.instance.currentUser != null) {
      try {
        final service = GoogleCalendarService();
        await service.createEvent(
          eventTime: eventDt,
          summary: snippet,
          duration: Duration(hours: 1),
          timeZone: 'Asia/Tokyo',
        );
        print('Googleカレンダーにイベントを追加しました');
      } catch (e) {
        print('カレンダー登録エラー: $e');
      }
    }
  }

  // キーワード検出処理
  bool checkForKeyword(String text, KeywordProvider keywordProvider) {
    List<String> keywords = keywordProvider.keywords;
    return keywords.any((keyword) => text.contains(keyword));
  }

  // 音声認識停止時の最終テキスト保存
  void savePendingTextOnStop(
      String selectedClass, TextsDataProvider textsDataProvider) {
    if (_pendingText.isNotEmpty) {
      textsDataProvider.addRecognizedText(selectedClass, _pendingText);
      textsDataProvider.addSummarizedText(selectedClass, _pendingText);
      print("音声認識停止時に最後のフレーズを保存しました: $_pendingText");

      // リセット
      _pendingText = "";
      _currentPhrasePrefix = "";
    }

    // 音声認識停止時に検出済みキーワードもリセット
    _detectedKeywordsInCurrentPhrase.clear();
  }

  // 音声認識データの処理
  ProcessedData processRecognitionData(
    String newRecognizedText,
    String selectedClass,
    TextsDataProvider textsDataProvider,
    KeywordProvider keywordProvider,
    RecognitionProvider recognitionProvider,
  ) {
    String newSummarizedText = "";

    // フレーズ変更時に前のフレーズの最終版を更新（キーワード検出より先に実行）
    updatePhraseIfNeeded(newRecognizedText, selectedClass, textsDataProvider);

    // 結合テキストを使用してキーワード検出
    String textForKeywordDetection = recognitionProvider.combinedText.isNotEmpty
        ? recognitionProvider.combinedText
        : newRecognizedText;

    // キーワード検出（結合テキストを使用）
    List<String> keywords = keywordProvider.keywords;
    List<String> detectedKeywords =
        keywords.where((k) => textForKeywordDetection.contains(k)).toList();

    // 新規検出のキーワードのみを抽出（既に検出済みのものは除外）
    List<String> newKeywords = detectedKeywords
        .where((k) => !_detectedKeywordsInCurrentPhrase.contains(k))
        .toList();

    // 新規キーワードを検出済みセットに追加
    _detectedKeywordsInCurrentPhrase.addAll(newKeywords);

    bool existKeyword = newKeywords.isNotEmpty; // 新規キーワードがあるかチェック

    return ProcessedData(
      recognizedText: newRecognizedText,
      summarizedText: newSummarizedText,
      detectedKeywords: newKeywords, // 新規キーワードのみを返す
      hasKeyword: existKeyword,
    );
  }
}
