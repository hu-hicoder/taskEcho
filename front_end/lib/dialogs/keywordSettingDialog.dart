import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keywordProvider.dart';

void showKeywordSettingDialog(BuildContext context) {
  final TextEditingController keywordController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[850],
            title: Text(
              'キーワードの設定',
              style: TextStyle(color: Colors.white),
            ),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // キーワードの一覧を表示
                  Container(
                    height: 200, // 固定高さを設定
                    child: Consumer<KeywordProvider>(
                      builder: (context, keywordProvider, child) {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: keywordProvider.keywords.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                keywordProvider.keywords[index],
                                style: TextStyle(color: Colors.white),
                              ),
                              trailing: IconButton(
                                icon:
                                    Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () {
                                  keywordProvider
                                      .deleteKeywords(index); //キーワードの削除
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  TextField(
                    controller: keywordController,
                    decoration: InputDecoration(
                      hintText: "新しいキーワードを入力",
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.cyanAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 8), // テキストフィールドと注意書きの間にスペースを追加
                  /* Align(
                    alignment: Alignment.centerRight, //右寄せ
                    child: Text(
                      "※「保存」を押さなければ変更が反映されません", //←ということもないかもしれない
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ), */
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                },
                child: Text(
                  "閉じる",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // 新しいキーワードを追加
                  if (keywordController.text.isNotEmpty) {
                    context
                        .read<KeywordProvider>()
                        .addKeyword(keywordController.text);
                    keywordController.clear();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  "追加",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              /* TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                },
                child: Text("保存"),
              ), */
            ],
          );
        },
      );
    },
  );
}
