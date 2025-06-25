import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_speech_to_text/services/googleCalendarService.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart'
    show CalendarApi, Event, EventDateTime;
import 'basePage.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../providers/classProvider.dart';
import '../providers/textsDataProvider.dart';
import '../providers/recognitionProvider.dart';
import '../providers/keywordProvider.dart';
import '../dialogs/settingDialog.dart';
import '../dialogs/keywordSettingDialog.dart';
import '../dialogs/classSettingDialog.dart';
import '/auth/googleSignIn.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signIn.dart'; // SignInPageをインポート

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

// サイレントサインイン用インスタンス
final GoogleSignIn _calendarSignIn = GoogleSignIn(
  clientId: dotenv.env['GOOGLE_CLIENT_ID'],
  scopes: [CalendarApi.calendarScope],
);

class VoiceRecognitionPage extends StatefulWidget {
  @override
  _VoiceRecognitionPageState createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends State<VoiceRecognitionPage> {
  List<String> recognizedTexts = ["認識結果1", "認識結果2", "認識結果3"];
  List<String> summarizedTexts = ["要約1", "要約2", "要約3"];
  String keyword = "キーワード検出待機中";
  List<String> detectedKeywords = [];
  Timer? timer;
  Timer? flashTimer;
  Timer? autoResetTimer; // 10秒後に自動的に画面変化を解除するタイマー
  bool isFlashing = false; // 点滅フラグ
  bool showGradient = true; // デフォルトの背景をグラデーションに戻すためのフラグ
  bool existKeyword = false; // キーワードが存在するかのフラグ
  Color backgroundColor = Colors.indigoAccent; // 点滅中の背景色管理用
  int currentIndex = 0; //要約とかの文章を受け取るリストのインデックスを管理する変数
  TextEditingController classController = TextEditingController();
  // 呼び出し済みのsummarizedTextsを追跡するセットを定義
  Set<String> calledeventTime = {};
  // キーワード保存の重複を防ぐためのマップ
  // キー: "キーワード:クラス名", 値: 最後に保存した時間
  Map<String, DateTime> _lastSavedKeywords = {};
  // キーワード保存のクールダウン時間（秒）
  final int _keywordSaveCooldown = 60;
  int maxWords = 100; // 最大文字数を設定
  String _previousRecognizedText = ""; // 前回の認識テキストを保持
  String _pendingText = ""; // 保留中のテキスト（同じフレーズの最終版を保持）
  String _currentPhrasePrefix = ""; // 現在のフレーズの最初の5文字

  @override
  void dispose() {
    timer?.cancel();
    flashTimer?.cancel();
    autoResetTimer?.cancel();
    super.dispose();
  }

  // 遅延保存用のデータを保持するマップ
  Map<String, DelayedKeywordData> _pendingKeywordData = {};

  // フレーズ変更時の更新処理
  void _updatePhraseIfNeeded(String newRecognizedText, String selectedClass,
      TextsDataProvider textsDataProvider) {
    if (_previousRecognizedText != newRecognizedText &&
        newRecognizedText.length > 5) {
      // 新しいテキストの最初の5文字を取得
      String newPrefix = newRecognizedText.substring(0, 5);

      // 現在のフレーズの最初の5文字が変わったかチェック
      if (_currentPhrasePrefix != newPrefix) {
        // 新しいフレーズに変わった！

        // 前のフレーズの最終版があれば更新
        if (_pendingText.isNotEmpty) {
          textsDataProvider.addRecognizedText(selectedClass, _pendingText);
          textsDataProvider.addSummarizedText(selectedClass, _pendingText);
          // print("前のフレーズの最終版を更新しました: $_pendingText");
        }

        // 新しいフレーズの情報を保存
        _currentPhrasePrefix = newPrefix;
        _pendingText = newRecognizedText;
        _previousRecognizedText = newRecognizedText;
        // print("新しいフレーズを検出しました: $newRecognizedText (保留中)");
      } else {
        // 同じフレーズの延長
        _pendingText = newRecognizedText; // より長いバージョンを保持
        _previousRecognizedText = newRecognizedText;
        // print("同じフレーズの延長のため、保留中テキストを更新: $newRecognizedText");
      }
    } else if (_previousRecognizedText == newRecognizedText) {
      // print("同じテキストが連続しているため、更新をスキップします。");
    } else {
      // print("5文字未満のため、更新をスキップします。");
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
      Future.delayed(Duration(seconds: 60), () async {
        // Androidでも1分間の遅延を確保
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
              keyword, selectedClass, snippet);

          print('キーワード "$keyword" を保存しました: $snippet');

          // ── ここから日時パターン検出とカレンダー登録 ──
          final now = keywordData.detectionTime;
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
              eventDt = DateTime(base.year, base.month, base.day,
                  int.parse(p[0]), int.parse(p[1]));
            } else {
              eventDt = DateTime(base.year, base.month, base.day, 9, 0);
            }
          }
          // 2. 「YYYY/MM/DD [HH:mm]」
          else {
            final ymd = RegExp(
                    r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:\s*(\d{1,2}:\d{2}))?')
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
                  eventDt = DateTime(
                      now.year, m, d, int.parse(p[0]), int.parse(p[1]));
                } else {
                  eventDt = DateTime(now.year, m, d, 9, 0);
                }
              }
              // 4. 時刻のみ「HH:mm」
              else {
                final t = RegExp(r'(\d{1,2}:\d{2})').firstMatch(snippet);
                if (t != null) {
                  final p = t.group(1)!.split(':');
                  eventDt = DateTime(now.year, now.month, now.day,
                      int.parse(p[0]), int.parse(p[1]));
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

          // // Google カレンダー登録
          // final user = FirebaseAuth.instance.currentUser;
          // if (eventDt != null && user != null && !user.isAnonymous) {
          //   // 1. サイレントサインインを試みる
          //   GoogleSignInAccount? googleUser = await _calendarSignIn.signInSilently();
          //   // 2. もし取得できなければインタラクティブサインイン
          //   googleUser ??= await _calendarSignIn.signIn();
          //   if (googleUser != null) {
          //     Map<String, String> headers = {};
          //     try {
          //       if (kIsWeb) {
          //         headers = await googleUser.authHeaders;
          //       } else {
          //         final googleAuth = await googleUser.authentication;
          //         if (googleAuth.accessToken != null) {
          //           headers = {'Authorization': 'Bearer ${googleAuth.accessToken}'};
          //         }
          //       }
          //     } catch (e) {
          //       print('認証情報取得エラー: $e');
          //     }

          //     if (headers.isNotEmpty) {
          //       final client = GoogleHttpClient(headers);
          //       final cal = CalendarApi(client);
          //       final ev = Event()
          //         ..summary = snippet
          //         ..start = EventDateTime(dateTime: eventDt.toUtc(), timeZone: 'UTC')
          //         ..end   = EventDateTime(
          //           dateTime: eventDt.add(Duration(hours: 1)).toUtc(),
          //           timeZone: 'UTC',
          //         );
          //       try {
          //         await cal.events.insert(ev, 'primary');
          //         print('Googleカレンダーにイベントを追加しました');
          //       } catch (e) {
          //           print('カレンダー登録エラー: $e');
          //         }
          //       } else {
          //         print('カレンダー用の認証情報が取得できませんでした。');
          //       }
          //     }
          // }

          // 保存が完了したらマップから削除
          _pendingKeywordData.remove(uniqueKey);
        } catch (e) {
          print('キーワード "$keyword" の保存中にエラーが発生しました: $e');
          // エラーが発生した場合もマップから削除
          _pendingKeywordData.remove(uniqueKey);
        }
      });
    } else {
      // クールダウン中の場合
      int secondsLeft =
          _keywordSaveCooldown - now.difference(lastSaved).inSeconds;
      print('キーワード "$keyword" は最近検出されました。'
          '次の検出まで約${secondsLeft}秒待機します。');
    }
  }

  // 音声認識結果を取得する関数
  Future<void> fetchRecognizedText() async {
    final textsDataProvider =
        Provider.of<TextsDataProvider>(context, listen: false);
    final selectedClass =
        Provider.of<ClassProvider>(context, listen: false).selectedClass;
    final recognitionProvider =
        Provider.of<RecognitionProvider>(context, listen: false);
    final keywordProvider =
        Provider.of<KeywordProvider>(context, listen: false);

    try {
      // 🎙 認識結果を取得
      String newRecognizedText = recognitionProvider.lastWords;

      if (newRecognizedText.isNotEmpty) {
        // 要約処理だけど今のところそのまま返す
        String newSummarizedText = "";

        // 結合テキストを使用してキーワード検出
        String textForKeywordDetection =
            recognitionProvider.combinedText.isNotEmpty
                ? recognitionProvider.combinedText
                : newRecognizedText;

        // キーワード検出（結合テキストを使用）
        List<String> keywords = keywordProvider.keywords;
        detectedKeywords =
            keywords.where((k) => textForKeywordDetection.contains(k)).toList();
        existKeyword = detectedKeywords.isNotEmpty;

        /* if (newRecognizedText.length > maxWords) {
          // print("文字数が${maxWords}を超えています。切り取ります。");
          newRecognizedText = newRecognizedText.substring(
              newRecognizedText.length - maxWords,
              newRecognizedText.length); // 指定した文字数で切る
        } */

        // ...existing code...

        // 📝 Providerのデータを更新（フレーズ変更時に前のフレーズの最終版を更新）
        _updatePhraseIfNeeded(
            newRecognizedText, selectedClass, textsDataProvider);

// ...existing code...

        // 🔄 リストの更新
        setState(() {
          if (recognizedTexts.length > 3) {
            recognizedTexts.removeAt(0);
            summarizedTexts.removeAt(0);
          }
          recognizedTexts.add(newRecognizedText);
          summarizedTexts.add(newSummarizedText);
          if (newRecognizedText.length > 100) {
            recognizedTexts = ["", "", ""];
            summarizedTexts = ["", "", ""];
          }
          currentIndex = recognizedTexts.length - 1;

          // キーワードに応じて点滅処理を実行
          if (existKeyword) {
            keyword = "検出: ${detectedKeywords.join(', ')}";
            startFlashing();

            // キーワードごとに1分後にDBに保存（完全なテキストを使用）
            for (String detectedKeyword in detectedKeywords) {
              saveKeywordWithDelay(newRecognizedText, detectedKeyword,
                  selectedClass, keywordProvider, recognitionProvider);
            }
          } else {
            stopFlashing();
          }
        });
      }
    } catch (e) {
      print('エラーが発生しました: $e');
      setState(() {
        recognizedTexts[currentIndex] = "データ取得エラー";
      });
    }
  }

  // キーワード検出
  bool checkForKeyword(String text) {
    final keywordProvider =
        Provider.of<KeywordProvider>(context, listen: false);
    List<String> keywords = keywordProvider.keywords;
    return keywords.any((keyword) => text.contains(keyword));
  }

  // 点滅を開始する（keywordの状態によって切り替え）
  void startFlashing() {
    if (!isFlashing) {
      isFlashing = true;
      showGradient = false; // 点滅中はグラデーションを非表示に

      // 既存のタイマーをキャンセル
      flashTimer?.cancel();
      autoResetTimer?.cancel();

      // 点滅タイマーを開始
      flashTimer = Timer.periodic(Duration(milliseconds: 500), (Timer t) {
        setState(() {
          // 交互に赤と白を切り替える
          backgroundColor = (backgroundColor == Colors.redAccent)
              ? Colors.white
              : Colors.redAccent;
        });
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
      flashTimer?.cancel(); // タイマーをキャンセルする
      flashTimer = null;
    }
    isFlashing = false;
    flashTimer?.cancel();

    // キーワードのリセットは行わない（検出されたキーワードを表示し続ける）
    // 代わりに、新しいキーワードが検出されるか、音声認識が停止されるまで表示を維持

    setState(() {
      showGradient = true; // 背景をグラデーションに戻す
    });
  }

  // 音声認識停止時にキーワード表示をリセットする
  void resetKeywordDisplay() {
    keyword = "キーワード検出待機中";
    existKeyword = false;
  }

  // 音声認識の開始
  Future<void> startRecording() async {
    final recognitionProvider =
        Provider.of<RecognitionProvider>(context, listen: false);

    if (recognitionProvider.isRecognizing) {
      print("⚠️ すでに音声認識中です。");
      return;
    }

    recognitionProvider.startListening(); // 音声認識を開始
    print("🎤 音声認識を開始しました");

    // 定期的にデータを取得するためのタイマーを設定
    timer?.cancel(); // 既存のタイマーを停止
    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      if (recognitionProvider.isRecognizing) {
        fetchRecognizedText(); // 認識したテキストを取得
      } else {
        t.cancel();
      }
    });
  }

  // 音声認識の停止
  Future<void> stopRecording() async {
    final recognitionProvider =
        Provider.of<RecognitionProvider>(context, listen: false);

    if (!recognitionProvider.isRecognizing) {
      print("⚠️ 音声認識は開始されていません。");
      return;
    }

    // 最後の保留中テキストがあれば保存
    if (_pendingText.isNotEmpty) {
      final textsDataProvider =
          Provider.of<TextsDataProvider>(context, listen: false);
      final selectedClass =
          Provider.of<ClassProvider>(context, listen: false).selectedClass;

      textsDataProvider.addRecognizedText(selectedClass, _pendingText);
      textsDataProvider.addSummarizedText(selectedClass, _pendingText);
      print("音声認識停止時に最後のフレーズを保存しました: $_pendingText");

      // リセット
      _pendingText = "";
      _currentPhrasePrefix = "";
    }

    recognitionProvider.stopListening(); // 音声認識を停止
    timer?.cancel(); // タイマーを停止
    stopFlashing(); // 点滅停止
    resetKeywordDisplay(); // キーワード表示をリセット

    print("🛑 音声認識を停止しました");
  }

  @override
  Widget build(BuildContext context) {
    final double cardHeight =
        MediaQuery.of(context).size.height / 6; // 画面の高さの1/6
    final classProvider = Provider.of<ClassProvider>(context);
    final recognitionProvider = Provider.of<RecognitionProvider>(context);
    final keywordProvider = Provider.of<KeywordProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('TaskEcho'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await GoogleAuth.signOut();
              // サインアウト後はタイトル画面へ戻す
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => SignInPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: BasePage(
        body: Stack(
          children: [
            // グラデーション背景または点滅する背景の表示
            showGradient
                ? AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.indigoAccent, Colors.deepPurpleAccent],
                      ),
                    ),
                  )
                : AnimatedContainer(
                    duration: Duration(milliseconds: 500),
                    color: backgroundColor, // 点滅する背景色
                  ),
            SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 40),
                      // 認識結果を表示するカード（縦に広\く調整）

                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                content: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      Text(
                                        // summarizedTexts[0], //一旦戦闘の要素を表示
                                        recognizedTexts[0], //一旦要約はなくす
                                        style: TextStyle(
                                            fontSize: 20, color: Colors.yellow),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 20),
                                      Text(
                                        recognizedTexts[0],
                                        style: TextStyle(
                                            fontSize: 24, color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('閉じる'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: cardHeight,
                          padding: EdgeInsets.all(20.0),
                          margin: EdgeInsets.symmetric(vertical: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Text(
                                  // summarizedTexts[0],
                                  recognizedTexts[0], //一旦要約はなくす
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),
                      // 録音開始/停止ボタン（色と視認性の改善）
                      ElevatedButton.icon(
                        icon: Icon(
                          recognitionProvider.isRecognizing
                              ? Icons.stop
                              : Icons.mic,
                          color: Colors.black,
                        ),
                        label: Text(
                          recognitionProvider.isRecognizing ? '停止' : '開始',
                          style: TextStyle(color: Colors.black),
                        ),
                        onPressed: () {
                          if (recognitionProvider.isRecognizing) {
                            stopRecording(); // 音声認識を停止
                          } else {
                            startRecording(); // 音声認識を開始
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recognitionProvider.isRecognizing
                              ? Colors.redAccent
                              : Colors.tealAccent, // より視認性の高い色に変更
                          padding: EdgeInsets.symmetric(
                              horizontal: 45, vertical: 21),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10,
                        ),
                      ),
                      SizedBox(height: 20),
                      // キーワード表示
                      Container(
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              keyword,
                              style: TextStyle(
                                fontSize: 24,
                                color: existKeyword
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                            // 登録済みキーワード一覧
                            if (keywordProvider.keywords.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "登録キーワード:",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      children: keywordProvider.keywords
                                          .map((k) => Chip(
                                                label: Text(k),
                                                backgroundColor:
                                                    Colors.blueGrey,
                                                labelStyle: TextStyle(
                                                    color: Colors.white),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 10),
                            // キーワード設定ボタンを追加
                            ElevatedButton(
                              onPressed: () {
                                showKeywordSettingDialog(
                                    context); // キーワード設定ダイアログを表示
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'キーワード設定',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      DropdownButton<String>(
                        hint: Text("授業を選択"),
                        value: context.watch<ClassProvider>().selectedClass,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              context
                                  .read<ClassProvider>()
                                  .setSelectedClass(newValue);
                              print(
                                  "選択された授業: ${context.read<ClassProvider>().selectedClass}");
                            });
                          }
                        },
                        items: classProvider.classes
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            //設定ボタンの追加
            Positioned(
              bottom: 20,
              left: 20,
              child: ElevatedButton(
                onPressed: () {
                  showSettingsDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  padding: EdgeInsets.all(16),
                  shape: CircleBorder(),
                  elevation: 0,
                ),
                child: Icon(
                  Icons.settings,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
