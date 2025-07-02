import 'package:flutter/material.dart';
import '../providers/classProvider.dart';
import '../providers/keywordProvider.dart';

class VoiceRecognitionWidgets {
  // 認識結果を表示するカード
  static Widget buildRecognitionCard({
    required BuildContext context,
    required List<String> recognizedTexts,
    required List<String> summarizedTexts,
    required double cardHeight,
  }) {
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
                      recognizedTexts[0],
                      style: TextStyle(fontSize: 20, color: Colors.yellow),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Text(
                      recognizedTexts[0],
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
                recognizedTexts[0],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24, // フォントサイズを大きく
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 録音開始/停止ボタン
  static Widget buildRecordingButton({
    required BuildContext context,
    required bool isRecognizing,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(
        isRecognizing ? Icons.stop : Icons.mic,
        color: Colors.black,
      ),
      label: Text(
        isRecognizing ? '停止' : '開始',
        style: TextStyle(color: Colors.black),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isRecognizing ? Colors.redAccent : Colors.tealAccent,
        padding: EdgeInsets.symmetric(horizontal: 45, vertical: 21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 10,
      ),
    );
  }

  // キーワード表示コンテナ
  static Widget buildKeywordContainer({
    required BuildContext context,
    required String keyword,
    required KeywordProvider keywordProvider,
    bool existKeyword = false, // キーワード存在フラグを追加
  }) {
    return Container(
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
              color: existKeyword ? Colors.redAccent : Colors.greenAccent,
              fontSize: 24,
              // fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }

  // クラス選択ドロップダウン
  static Widget buildClassDropdown({
    required BuildContext context,
    required ClassProvider classProvider,
  }) {
    return DropdownButton<String>(
      hint: Text("授業を選択"),
      value: classProvider.selectedClass,
      onChanged: (String? newValue) {
        if (newValue != null) {
          classProvider.setSelectedClass(newValue);
        }
      },
      items:
          classProvider.classes.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }

  // 設定ボタン
  static Widget buildSettingsButton({
    required BuildContext context,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
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
    );
  }

  // 背景コンテナ（グラデーションまたは点滅）
  static Widget buildBackground({
    required bool showGradient,
    required Color backgroundColor,
    required Widget child,
  }) {
    return Stack(
      children: [
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
                color: backgroundColor,
              ),
        child,
      ],
    );
  }
}
