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
            title: Text('キーワードの設定'),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // キーワードの一覧を表示
                  Expanded(
                    child: Consumer<KeywordProvider>(
                      builder: (context, keywordProvider, child) {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: keywordProvider.keywords.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(keywordProvider.keywords[index]),
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
                    decoration: InputDecoration(hintText: "新しいキーワードを入力"),
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
                child: Text("閉じる"),
              ),
              TextButton(
                onPressed: () {
                  // 新しいキーワードを追加
                  if (keywordController.text.isNotEmpty) {
                    context
                        .read<KeywordProvider>()
                        .addKeyword(keywordController.text);
                    keywordController.clear();
                  }
                },
                child: Text("追加"),
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
