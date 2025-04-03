import 'package:flutter/material.dart';
import 'keywordSettingDialog.dart';
import 'classSettingDialog.dart';

void showSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('設定'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 設定ダイアログを閉じる
                  showKeywordSettingDialog(context); // キーワード設定ダイアログを表示
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, // ボタンの背景色
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'キーワードを設定',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 設定ダイアログを閉じる
                  showClassSettingDialog(context); // 授業設定ダイアログを表示
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, // ボタンの背景色
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  '授業の設定',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // ダイアログを閉じる
            },
            child: Text('閉じる'),
          ),
        ],
      );
    },
  );
}
