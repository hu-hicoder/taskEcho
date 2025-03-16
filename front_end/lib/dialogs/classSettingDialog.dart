import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/classProvider.dart';

void showClassSettingDialog(BuildContext context) {
  final classProvider = Provider.of<ClassProvider>(context, listen: false);
  final TextEditingController classController = TextEditingController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('授業の設定'),
            content: Container(
              height: MediaQuery.of(context).size.height * 0.6, // ダイアログの高さを指定
              width: MediaQuery.of(context).size.width * 0.6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  //授業の削除
                  SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: classProvider.classes.map((className) {
                          return ListTile(
                            title: Text(className),
                            trailing: PopupMenuButton<String>(
                              onSelected: (String result) {
                                if (result == '削除') {
                                  setState(() {
                                    classProvider.removeClass(className);
                                  });
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: '削除',
                                  child: Text('削除'),
                                  enabled:
                                      classProvider.selectedClass != className,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  //授業の追加
                  SizedBox(height: 16),
                  TextField(
                    controller: classController,
                    decoration: InputDecoration(hintText: "新しい授業を入力"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("キャンセル"),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (classController.text.isNotEmpty) {
                      classProvider.addClass(classController.text);
                      classController.clear();
                    }
                  });
                  Navigator.of(context).pop();
                },
                child: Text("追加"),
              ),
            ],
          );
        },
      );
    },
  );
}
