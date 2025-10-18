import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/classProvider.dart';
import '../providers/textsDataProvider.dart';
import '../providers/recognitionProvider.dart';
import '../providers/keywordProvider.dart';
import '../models/calendar_event_proposal.dart';
import '../models/event_time.dart';
import '../models/reminder.dart';
import 'voiceRecognitionService.dart';
import 'backend_service.dart';

class VoiceRecognitionUIService extends ChangeNotifier {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();

  // UI状態管理用の変数
  List<String> recognizedTexts = ["ここに認識結果が表示されます"];
  // List<String> summarizedTexts = ["要約1", "要約2", "要約3"];
  String keyword = "キーワード検出待機中";
  List<String> detectedKeywords = [];

  // カレンダーイベント提案の状態
  CalendarEventProposal? _pendingEventProposal;

  // イベントキュー（複数イベントの管理用）
  List<CalendarEventProposal> _eventQueue = [];
  // スキップされたイベントを一時保存するスタック（Undo用）
  List<CalendarEventProposal> _skippedEvents = [];

  /// 現在保留中のカレンダーイベント提案を取得
  CalendarEventProposal? get pendingEventProposal => _pendingEventProposal;

  /// 現在のキューに残っているイベント数を取得
  int get eventQueueLength => _eventQueue.length;

  /// まだ表示していないイベントがあるかどうか
  bool get hasMoreEvents => _eventQueue.isNotEmpty;

  /// 現在何個目のイベントを表示しているか（1から始まる）
  int _totalEventsCount = 0;
  int get currentEventNumber => _totalEventsCount - _eventQueue.length;

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

          // 【本番】バックエンドに音声テキストを送信して要約とカレンダー情報を取得
          final firstKeyword =
              detectedKeywords.isNotEmpty ? detectedKeywords.first : null;
          processVoiceTextWithBackend(
            context,
            text: newRecognizedText,
            keyword: firstKeyword,
          );

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
        }
        // 注: 点滅は10秒の自動停止タイマー (autoResetTimer) で管理される

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
    // カードが1つだけなので、常に最新のテキストで上書き
    recognizedTexts = [recognizedText];
    currentIndex = 0;
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

  /// カレンダーイベント提案を設定する
  ///
  /// この関数が呼ばれると、UIはボトムシートを表示すべきと判断できます
  void proposeCalendarEvent(CalendarEventProposal proposal) {
    _pendingEventProposal = proposal;
    notifyListeners(); // UIに変更を通知
    print('📅 カレンダーイベント提案: ${proposal.summary} at ${proposal.start}');
  }

  /// カレンダーイベント提案をクリアする
  ///
  /// ユーザーが承諾または却下した後に呼び出されます
  void clearEventProposal() {
    _pendingEventProposal = null;
    notifyListeners(); // UIに変更を通知
  }

  /// 複数のカレンダーイベントをキューに追加して順番に表示する
  ///
  /// バックエンドから複数イベントを取得した場合に使用
  void proposeMultipleEvents(List<CalendarEventProposal> events) {
    if (events.isEmpty) {
      print('⚠️ イベントリストが空です');
      return;
    }

    _eventQueue.clear(); // 既存のキューをクリア
    _eventQueue.addAll(events);
    _totalEventsCount = events.length;

    print('📅 ${events.length}個のイベントをキューに追加しました');

    // 最初のイベントを表示
    _showNextEvent();
  }

  /// キューから次のイベントを取り出して表示する（内部用）
  void _showNextEvent() {
    if (_eventQueue.isNotEmpty) {
      _pendingEventProposal = _eventQueue.removeAt(0);
      notifyListeners();
      print(
          '📅 イベント表示 (${currentEventNumber}/${_totalEventsCount}): ${_pendingEventProposal?.summary}');
    } else {
      _pendingEventProposal = null;
      _totalEventsCount = 0;
      notifyListeners();
      print('✅ すべてのイベントを処理しました');
    }
  }

  /// 現在のイベントをスキップして次のイベントへ
  ///
  /// ユーザーが「スキップ」ボタンを押した時に呼ばれる
  void skipCurrentEvent() {
    print('⏭️ イベントをスキップ: ${_pendingEventProposal?.summary}');
    if (_pendingEventProposal != null) {
      _skippedEvents.add(_pendingEventProposal!);
    }
    _showNextEvent();
  }

  /// 現在のイベントを承認して次のイベントへ
  ///
  /// カレンダーに登録が成功した後に呼ばれる
  void confirmAndNext() {
    print('✅ イベントを承認: ${_pendingEventProposal?.summary}');
    _showNextEvent();
  }

  /// イベントキューをすべてクリアする
  void clearEventQueue() {
    _eventQueue.clear();
    _pendingEventProposal = null;
    _totalEventsCount = 0;
    _skippedEvents.clear();
    notifyListeners();
    print('🗑️ イベントキューをクリアしました');
  }

  /// 【本番用】音声認識テキストをバックエンドに送信し、要約とカレンダーイベントを取得する
  ///
  /// [context] BuildContext
  /// [text] 音声認識で取得したテキスト
  /// [keyword] キーワード（オプション）
  ///
  /// 戻り値: 処理が成功した場合はtrue、失敗した場合はfalse
  Future<bool> processVoiceTextWithBackend(
    BuildContext context, {
    required String text,
    String? keyword,
  }) async {
    try {
      print('🎤 音声テキストをバックエンドで処理開始...');
      print('  テキスト: $text');
      print('  キーワード: ${keyword ?? "なし"}');

      // バックエンドに送信
      final result = await BackendService.processVoiceText(
        text: text,
        keyword: keyword,
      );

      if (result == null) {
        print('❌ バックエンドからの応答がありませんでした');
        return false;
      }

      // 要約テキストを表示用に保存
      if (result.summarizedText.isNotEmpty) {
        print('📝 要約: ${result.summarizedText}');
        // 必要に応じて要約テキストをUIに表示
        _updateTextLists(text, result.summarizedText);
      }

      // カレンダーイベントがある場合は表示
      if (result.calendarEvents.isNotEmpty) {
        print('📅 ${result.calendarEvents.length}個のカレンダーイベントを取得');

        // CalendarEventからCalendarEventProposalに変換
        final proposals = result.calendarEvents.map((event) {
          // event.startとevent.endをEventTimeに変換
          EventTime? startTime;
          if (event.start != null) {
            final startJson = (event.start as dynamic).toJson();
            startTime = EventTime.fromJson(startJson);
          }

          EventTime? endTime;
          if (event.end != null) {
            final endJson = (event.end as dynamic).toJson();
            endTime = EventTime.fromJson(endJson);
          }

          Reminders? reminders;
          if (event.reminders != null) {
            final remindersJson = (event.reminders as dynamic).toJson();
            reminders = Reminders.fromJson(remindersJson);
          }

          return CalendarEventProposal(
            summary: event.summary ?? 'イベント',
            description: event.description,
            start: startTime ??
                EventTime(dateTime: DateTime.now().toIso8601String()),
            end: endTime,
            location: event.location,
            attendees: event.attendees,
            reminders: reminders,
          );
        }).toList();

        // 複数イベントをキューに追加して順番に表示
        proposeMultipleEvents(proposals);
      } else {
        print('ℹ️ カレンダーイベントはありませんでした');
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('❌ バックエンド処理エラー: $e');
      return false;
    }
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

    // recognizedTextsを初期化
    recognizedTexts = ["ここに認識結果が表示されます"];
    detectedKeywords = [];
    currentIndex = 0;
    notifyListeners();

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
