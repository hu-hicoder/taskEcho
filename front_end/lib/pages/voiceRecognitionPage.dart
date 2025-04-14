import 'package:flutter/material.dart';
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
  bool isFlashing = false; // 点滅フラグ
  bool showGradient = true; // デフォルトの背景をグラデーションに戻すためのフラグ
  bool existKeyword = false; // キーワードが存在するかのフラグ
  Color backgroundColor = Colors.indigoAccent; // 点滅中の背景色管理用
  int currentIndex = 0; //要約とかの文章を受け取るリストのインデックスを管理する変数
  TextEditingController classController = TextEditingController();
  // 呼び出し済みのsummarizedTextsを追跡するセットを定義
  Set<String> calledeventTime = {};

  // サーバーからデータを取得する関数
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
        String newSummarizedText = newRecognizedText;

        // キーワード検出
        List<String> keywords = keywordProvider.keywords;
        detectedKeywords = keywords.where((k) => newRecognizedText.contains(k)).toList();
        existKeyword = detectedKeywords.isNotEmpty;

        // 📝 Providerのデータを更新
        textsDataProvider.addRecognizedText(selectedClass, newRecognizedText);
        textsDataProvider.addSummarizedText(selectedClass, newSummarizedText);

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
          } else {
            stopFlashing();
          }
        });

        print('認識結果：${summarizedTexts[currentIndex]}');
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
    final keywordProvider = Provider.of<KeywordProvider>(context, listen: false);
    List<String> keywords = keywordProvider.keywords;
    return keywords.any((keyword) => text.contains(keyword));
  }

  // 点滅を開始する（keywordの状態によって切り替え）
  void startFlashing() {
    if (!isFlashing) {
      isFlashing = true;
      showGradient = false; // 点滅中はグラデーションを非表示に
      flashTimer = Timer.periodic(Duration(milliseconds: 500), (Timer t) {
        setState(() {
          // 交互に赤と白を切り替える
          backgroundColor = (backgroundColor == Colors.redAccent)
              ? Colors.white
              : Colors.redAccent;
        });
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
    keyword = "キーワード検出待機中"; // キーワードをリセット
    setState(() {
      showGradient = true; // 背景をグラデーションに戻す
    });
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

    recognitionProvider.stopListening(); // 音声認識を停止
    timer?.cancel(); // タイマーを停止
    stopFlashing(); // 点滅停止
    keyword = "キーワード検出待機中"; // キーワードをリセット

    print("🛑 音声認識を停止しました");
  }

  @override
  Widget build(BuildContext context) {
    final double cardHeight =
        MediaQuery.of(context).size.height / 6; // 画面の高さの1/6
    final classProvider = Provider.of<ClassProvider>(context);
    final recognitionProvider = Provider.of<RecognitionProvider>(context);
    final keywordProvider = Provider.of<KeywordProvider>(context);

    return BasePage(
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
                    // 認識結果を表示するカード（縦に広く調整）
                    Column(
                      children: List.generate(summarizedTexts.length, (index) {
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  content: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        Text(
                                          summarizedTexts[index],
                                          style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.yellow),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: 20),
                                        Text(
                                          recognizedTexts[index],
                                          style: TextStyle(
                                              fontSize: 24,
                                              color: Colors.white),
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
                                    summarizedTexts[index],
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
                        );
                      }),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                                              backgroundColor: Colors.blueGrey,
                                              labelStyle: TextStyle(color: Colors.white),
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
                              showKeywordSettingDialog(context); // キーワード設定ダイアログを表示
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    SizedBox(height: 20),
                    //設定ボタンの追加
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: ElevatedButton(
                        onPressed: () {
                          showSettingsDialog(context); // 設定ダイアログを表示
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent, // ボタンの背景色
                          padding: EdgeInsets.all(16), // アイコンの周りのパディング
                          shape: CircleBorder(), // ボタンを円形にする
                          elevation: 0, // 影を削除
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
            ),
          ),
        ],
      ),
    );
  }
}
