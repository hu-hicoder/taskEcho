import 'package:flutter/material.dart';

void showKeywordSettingDialog(BuildContext context) {
  final TextEditingController keywordController = TextEditingController();
  final List<String> keywords = [
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

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('キーワードの設定'),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // キーワードの一覧を表示
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: keywords.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(keywords[index]),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                keywords.removeAt(index); // キーワードを削除
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  TextField(
                    controller: keywordController,
                    decoration: InputDecoration(hintText: "新しいキーワードを入力"),
                  ),
                  SizedBox(height: 8), // テキストフィールドと注意書きの間にスペースを追加
                  Align(
                    alignment: Alignment.centerRight, //右寄せ
                    child: Text(
                      "※「保存」を押さなければ変更が反映されません", //←ということもないかもしれない
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                },
                child: Text("キャンセル"),
              ),
              TextButton(
                onPressed: () {
                  // 新しいキーワードを追加
                  setState(() {
                    if (keywordController.text.isNotEmpty) {
                      keywords.add(keywordController.text);
                      keywordController.clear();
                    }
                  });
                },
                child: Text("追加"),
              ),
              TextButton(
                onPressed: () async {
                  // キーワードを保存（バックエンドに送信）
                  // await sendKeywords();
                  Navigator.of(context).pop(); // ダイアログを閉じる
                },
                child: Text("保存"),
              ),
            ],
          );
        },
      );
    },
  );
}
