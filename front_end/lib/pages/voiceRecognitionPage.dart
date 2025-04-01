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
import 'package:speech_to_text_ultra/speech_to_text_ultra.dart';

class VoiceRecognitionPage extends StatefulWidget {
  @override
  _VoiceRecognitionPageState createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends State<VoiceRecognitionPage> {
  //String recognizedText = "認識結果がここに表示されます";
  //String summarizedText = "要約データがここに表示されます";
  String recognizedTexts = "";
  bool mIsListening = false; // 音声認識中かどうかのフラグ
  List<String> summarizedTexts = ["要約1", "要約2", "要約3"];
  //bool isRecognizing = false;
  String keyword = "授業中";
  Timer? timer;
  Timer? flashTimer;
  bool isFlashing = false; // 点滅フラグ
  bool showGradient = true; // デフォルトの背景をグラデーションに戻すためのフラグ
  //bool canFlash = true; // フラグを追加
  bool existKeyword = false; // キーワードが存在するかのフラグ
  Color backgroundColor = Colors.indigoAccent; // 点滅中の背景色管理用
  List<String> keywords = [
    "重要",
    "大事",
    "課題",
    "提出",
    "テスト",
    "レポート",
    "締め切り",
    "期限",
    "動作確認"
  ];
  int currentIndex = 0; //要約とかの文章を受け取るリストのインデックスを管理する変数
  TextEditingController classController = TextEditingController();
  // 呼び出し済みのsummarizedTextsを追跡するセットを定義
  Set<String> calledeventTime = {};

  // //キーワードをapp.pyに送信
  // Future<void> sendKeywords() async {
  //   final response = await http.post(
  //     Uri.parse('http://localhost:5000/set_keywords'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'keywords': keywords}),
  //   );

  //   if (response.statusCode == 200) {
  //     print("キーワードを送信しました");
  //   } else {
  //     print("キーワードの送信に失敗しました");
  //   }
  // }

  // @override
  // void initState() {
  //   super.initState();
  //   sendKeywords(); // ウィジェットの初期化時にキーワードを送信
  // }

  // サーバーからデータを取得する関数
  // Future<void> fetchRecognizedText() async {
  //   final textsDataProvider =
  //       Provider.of<TextsDataProvider>(context, listen: false);
  //   final selectedClass =
  //       Provider.of<ClassProvider>(context, listen: false).selectedClass;
  //   final recognitionProvider =
  //       Provider.of<RecognitionProvider>(context, listen: false);

  //   try {
  //     // 🎙 認識結果を取得
  //     String newRecognizedText = recognitionProvider.lastWords;

  //     if (newRecognizedText.isNotEmpty) {
  //       // 要約処理だけど今のところそのまま返す
  //       String newSummarizedText = newRecognizedText;

  //       existKeyword = checkForKeyword(newRecognizedText);

  //       // 📝 Providerのデータを更新
  //       textsDataProvider.addRecognizedText(selectedClass, newRecognizedText);
  //       textsDataProvider.addSummarizedText(selectedClass, newSummarizedText);

  //       // 🔄 リストの更新
  //       setState(() {

  //         if (recognizedTexts.length > 500) {
  //           recognizedTexts = "";
  //           summarizedTexts.removeAt(0);
  //         }
  //         recognizedTexts.add(newRecognizedText);
  //         summarizedTexts.add(newSummarizedText);
  //         if (newRecognizedText.length > 100){
  //           recognizedTexts = ["", "", ""];
  //           summarizedTexts = ["", "", ""];
  //         }
  //         currentIndex = recognizedTexts.length - 1;

  //         // キーワードに応じて点滅処理を実行
  //         if (existKeyword) {
  //           startFlashing();
  //         } else {
  //           stopFlashing();
  //         }
  //       });

  //       print('認識結果：${summarizedTexts[currentIndex]}');

  //       // 📅 Googleカレンダー連携
  //       // String? eventTime = await extractTime(newSummarizedText);
  //       // if (eventTime != null && !calledeventTime.contains(eventTime)) {
  //       //   await createEvent(eventTime, "授業予定");
  //       //   calledeventTime.add(eventTime);
  //       // }
  //     }
  //   } catch (e) {
  //     print('エラーが発生しました: $e');
  //     setState(() {
  //       recognizedTexts[currentIndex] = "データ取得エラー";
  //     });
  //   }
  // }

  // キーワード検出だけど動くように仮においてる
  bool checkForKeyword(String text) {
    return text.contains("授業");
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
    keyword = "授業中"; // キーワードをリセット
    setState(() {
      showGradient = true; // 背景をグラデーションに戻す
    });
  }

  // // 文字列から時刻情報を抽出する関数
  // String? extractTime(String text) {
  //   final timeRegExp = RegExp(r'(\d{1,2}:\d{2})');
  //   final match = timeRegExp.firstMatch(text);
  //   return match?.group(0);
  // }

  // gooラボの時刻情報正規化APIを呼び出す関数
  // Future<String?> extractTime(String text) async {
  //   final apiKey = dotenv.env['API_KEY']; // 環境変数からAPIキーを取得
  //   print("=====extractTime=====");
  //   if (apiKey == null) {
  //     print('APIキーが設定されていません');
  //     return null;
  //   }

  //   final url = Uri.parse('https://labs.goo.ne.jp/api/chrono');
  //   final headers = {'Content-Type': 'application/json'};
  //   final body = jsonEncode({'app_id': apiKey, 'sentence': text});

  //   try {
  //     print('Sending request to $url with body: $body');
  //     final response = await http.post(url, headers: headers, body: body);
  //     print('Received response with status code: ${response.statusCode}');
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       print('Received data: $data');
  //       if (data['datetime_list'] != null && data['datetime_list'].isNotEmpty) {
  //         final datetime = data['datetime_list'][0][1].toString();
  //         print('Extracted datetime: $datetime');
  //         return datetime;
  //       } else {
  //         print('datetime_listが空です。');
  //       }
  //     } else {
  //       print('時刻情報正規化APIの呼び出しに失敗しました。ステータスコード: ${response.statusCode}');
  //       print('レスポンスボディ: ${response.body}');
  //     }
  //   } catch (e) {
  //     print('エラーが発生しました: $e');
  //     setState(() {
  //       recognizedTexts[currentIndex] = "データ取得エラー";
  //     });
  //   }
  //   print("==========");
  //   return null;
  // }

  // // GoogleカレンダーのURLを生成する関数
  // Future<void> createEvent(String eventTime, String currentIndex) async {
  //   try {
  //     final url = Uri.parse('http://localhost:5000/create_event');
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'eventTime': eventTime,
  //         'currentIndex': currentIndex,
  //       }),
  //     );
  //     print("=====createEvent=====");
  //     if (response.statusCode == 200) {
  //       // 成功時の処理
  //       print('Event created successfully');
  //     } else {
  //       // エラーハンドリング
  //       print(
  //           'Failed to create event with status code: ${response.statusCode}');
  //       print('Response body: ${response.body}');
  //     }
  //   } catch (e) {
  //     // ネットワークエラーやその他の例外をキャッチ
  //     print('An error occurred: $e');
  //   }
  //   print("==========");
  // }

  // // 音声認識の開始
  // Future<void> startListening() async {

  //   if (!_speechEnabled || _speechToText.isListening) {
  //     print("音声認識が使用できないか、既にリスニング中です");
  //     return;
  //   }

  //   bool available = await _speechToText.initialize();

  //   if (available) {
  //     print("音声認識を開始します...");
  //     _isRecognizing = true; // 🔥 `true` に変更して UI を更新
  //     notifyListeners();

  //     await _speechToText.listen(
  //       onResult: _onSpeechResult,
  //       partialResults: true,
  //       localeId: "ja_JP",
  //       listenMode: ListenMode.dictation,
  //     );

  //     print("SpeechToText のリスニング開始");
  //   } else {
  //     print("SpeechToText の初期化に失敗");
  //   }
  // }

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
    keyword = "授業中"; // キーワードをリセット

    print("🛑 音声認識を停止しました");
  }

  // void showSettingsDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('設定'),
  //         content: SingleChildScrollView(
  //           child: ListBody(
  //             children: <Widget>[
  //               ElevatedButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop(); // 設定ダイアログを閉じる
  //                   //showKeywordSettingDialog(context); // キーワード設定ダイアログを表示
  //                 },
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.cyanAccent, // ボタンの背景色
  //                   padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(30),
  //                   ),
  //                 ),
  //                 child: Text(
  //                   'キーワードを設定',
  //                   style: TextStyle(color: Colors.black),
  //                 ),
  //               ),
  //               SizedBox(height: 20),
  //               ElevatedButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop(); // 設定ダイアログを閉じる
  //                   //showClassSettingDialog(context); // 授業設定ダイアログを表示
  //                 },
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: Colors.cyanAccent, // ボタンの背景色
  //                   padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(30),
  //                   ),
  //                 ),
  //                 child: Text(
  //                   '授業の設定',
  //                   style: TextStyle(color: Colors.black),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: <Widget>[
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop(); // ダイアログを閉じる
  //             },
  //             child: Text('閉じる'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // // キーワード設定ダイアログを表示する関数
  // void showKeywordSettingDialog(BuildContext context) {
  //   final TextEditingController keywordController = TextEditingController();

  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           return AlertDialog(
  //             title: Text('キーワードの設定'),
  //             content: Container(
  //               width: MediaQuery.of(context).size.width * 0.5,
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   // キーワードの一覧を表示
  //                   Expanded(
  //                     child: ListView.builder(
  //                       shrinkWrap: true,
  //                       itemCount: keywords.length,
  //                       itemBuilder: (context, index) {
  //                         return ListTile(
  //                           title: Text(keywords[index]),
  //                           trailing: IconButton(
  //                             icon: Icon(Icons.delete, color: Colors.redAccent),
  //                             onPressed: () {
  //                               setState(() {
  //                                 keywords.removeAt(index); // キーワードを削除
  //                               });
  //                             },
  //                           ),
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                   TextField(
  //                     controller: keywordController,
  //                     decoration: InputDecoration(hintText: "新しいキーワードを入力"),
  //                   ),
  //                   SizedBox(height: 8), // テキストフィールドと注意書きの間にスペースを追加
  //                   Align(
  //                     alignment: Alignment.centerRight, //右寄せ
  //                     child: Text(
  //                       "※「保存」を押さなければ変更が反映されません",
  //                       style: TextStyle(color: Colors.redAccent, fontSize: 12),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop(); // ダイアログを閉じる
  //                 },
  //                 child: Text("キャンセル"),
  //               ),
  //               TextButton(
  //                 onPressed: () {
  //                   // 新しいキーワードを追加
  //                   setState(() {
  //                     if (keywordController.text.isNotEmpty) {
  //                       keywords.add(keywordController.text);
  //                       keywordController.clear();
  //                     }
  //                   });
  //                 },
  //                 child: Text("追加"),
  //               ),
  //               TextButton(
  //                 onPressed: () async {
  //                   // キーワードを保存（バックエンドに送信）
  //                   await sendKeywords();
  //                   Navigator.of(context).pop(); // ダイアログを閉じる
  //                 },
  //                 child: Text("保存"),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  // // 授業設定ダイアログを表示する関数
  // void showClassSettingDialog(BuildContext context) {
  //   final classProvider = Provider.of<ClassProvider>(context, listen: false);
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           return AlertDialog(
  //             title: Text('授業の設定'),
  //             content: Container(
  //               height: MediaQuery.of(context).size.height * 0.6, // ダイアログの高さを指定
  //               width: MediaQuery.of(context).size.width * 0.6,
  //               child: Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   //授業の削除
  //                   SizedBox(height: 8),
  //                   Expanded(
  //                     child: SingleChildScrollView(
  //                       child: Column(
  //                         children: classProvider.classes.map((className) {
  //                           return ListTile(
  //                             title: Text(className),
  //                             trailing: PopupMenuButton<String>(
  //                               onSelected: (String result) {
  //                                 if (result == '削除') {
  //                                   setState(() {
  //                                     classProvider.removeClass(className);
  //                                   });
  //                                 }
  //                               },
  //                               itemBuilder: (BuildContext context) =>
  //                                   <PopupMenuEntry<String>>[
  //                                 PopupMenuItem<String>(
  //                                   value: '削除',
  //                                   child: Text('削除'),
  //                                   enabled: classProvider.selectedClass !=
  //                                       className,
  //                                 ),
  //                               ],
  //                             ),
  //                           );
  //                         }).toList(),
  //                       ),
  //                     ),
  //                   ),
  //                   //授業の追加
  //                   SizedBox(height: 16),
  //                   TextField(
  //                     controller: classController,
  //                     decoration: InputDecoration(hintText: "新しい授業を入力"),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () {
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: Text("キャンセル"),
  //               ),
  //               TextButton(
  //                 onPressed: () {
  //                   setState(() {
  //                     if (classController.text.isNotEmpty) {
  //                       classProvider.addClass(classController.text);
  //                       classController.clear();
  //                     }
  //                   });
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: Text("追加"),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final double cardHeight =
        MediaQuery.of(context).size.height / 6; // 画面の高さの1/6
    final classProvider = Provider.of<ClassProvider>(context);
    final recognitionProvider = Provider.of<RecognitionProvider>(context);

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
                                      summarizedTexts.isNotEmpty
                                          ? summarizedTexts[0]
                                          : '',
                                      style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.yellow),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      recognizedTexts!=""
                                          ? recognizedTexts
                                          : '',
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
                                summarizedTexts.isNotEmpty
                                    ? summarizedTexts[0]
                                    : '',
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
                    SpeechToTextUltra(
                      ultraCallback: (String liveText, String finalText, bool isListening) {
                        setState(() {
                          if (!isListening) {
                            // finalTextが空なら、liveTextをmEntireResponseにセット
                            if (finalText.isNotEmpty) {
                              recognizedTexts = finalText;
                            } else if (liveText.isNotEmpty) {
                              recognizedTexts = liveText;
                            }
                          } else {
                            // リアルタイムのテキストを更新
                            recognizedTexts = liveText;
                          }
                          mIsListening = isListening;
                          // ターミナルにデバッグ情報を表示
                          print("----- SpeechToTextUltra Callback -----");
                          print("isListening: $mIsListening");
                          print("liveText: $recognizedTexts");
                          print("finalText: $finalText");
                          print("mEntireResponse: $recognizedTexts");
                          print("-------------------------------------");
                        });
                      },
                      toPauseIcon: const Icon(Icons.stop, size: 50, color: Colors.red),
                      toStartIcon: const Icon(Icons.mic, size: 50, color: Colors.green),
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
                      child: Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 24,
                          color: (keyword == "授業中")
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                        textAlign: TextAlign.center,
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
