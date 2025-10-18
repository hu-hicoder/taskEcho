import 'package:flutter/material.dart';
import '../providers/classProvider.dart';
import '../providers/keywordProvider.dart';
import '../models/calendar_event_proposal.dart';
import '../services/voiceRecognitionUIService.dart';
import 'editable_calendar_event_sheet.dart';

class VoiceRecognitionWidgets {
  // 認識結果を表示するシンプルなカード
  static Widget buildRecognitionCard({
    required BuildContext context,
    required List<String> recognizedTexts,
    // required List<String> summarizedTexts,
    required double cardHeight,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Text(
        recognizedTexts.isEmpty ||
                recognizedTexts[0].isEmpty ||
                recognizedTexts[0] == 'ここに認識結果が表示されます'
            ? '音声認識結果がここに表示されます'
            : recognizedTexts[0],
        style: TextStyle(
          color: (recognizedTexts.isEmpty ||
                  recognizedTexts[0].isEmpty ||
                  recognizedTexts[0] == 'ここに認識結果が表示されます')
              ? Colors.grey[400]
              : Colors.black87,
          fontSize: 16,
          height: 1.5,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // シンプルな録音ボタン（大きめ、中央配置向け）
  static Widget buildRecordingButton({
    required BuildContext context,
    required bool isRecognizing,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecognizing ? Colors.red[400] : Colors.blue[500],
        ),
        child: Icon(
          isRecognizing ? Icons.stop_rounded : Icons.mic_rounded,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }

  // キーワード表示（インライン編集対応）
  static Widget buildKeywordContainer({
    required BuildContext context,
    required String keyword,
    required KeywordProvider keywordProvider,
    bool existKeyword = false,
  }) {
    final TextEditingController _keywordController = TextEditingController();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: existKeyword ? Colors.orange[300]! : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // キーワード追加用のテキストフィールドとボタン
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: InputDecoration(
                    hintText: 'キーワードを入力',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.blue[500]!, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _keywordController.text.trim();
                  if (text.isNotEmpty) {
                    keywordProvider.addKeyword(text);
                    _keywordController.clear();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[500],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text('追加',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 登録済みキーワードの表示（×ボタン付き）
          if (keywordProvider.keywords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'キーワードを追加してください',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywordProvider.keywords.asMap().entries.map((entry) {
                final index = entry.key;
                final keyword = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.only(
                      left: 4, right: 8, top: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          keywordProvider.removeKeyword(index);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        keyword,
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          // キーワード検出通知
          if (existKeyword) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active,
                      color: Colors.orange[700], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '検出: $keyword',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // クラス選択ドロップダウン（シンプル）
  static Widget buildClassDropdown({
    required BuildContext context,
    required ClassProvider classProvider,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.school_outlined, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                hint: Text("授業を選択", style: TextStyle(color: Colors.grey[600])),
                // 選択中のテキストのスタイル（ここで色を変更）
                style: TextStyle(color: Colors.blue[700], fontSize: 16),
                // ドロップダウンのポップアップ背景色を黒にする（ポップ時は背景黒、テキストは白に）
                dropdownColor: Colors.black,
                // 選択時に表示されるウィジェットをカスタムして、非ポップ状態では黒いテキストにする
                selectedItemBuilder: (BuildContext context) {
                  return classProvider.classes.map<Widget>((String value) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: TextStyle(color: Colors.black, fontSize: 16)),
                    );
                  }).toList();
                },
                value: classProvider.selectedClass,
                isExpanded: true,
                onChanged: (String? newValue) {
                  if (newValue == '+ 新しい授業を追加') {
                    _showAddClassDialog(context, classProvider);
                  } else if (newValue != null) {
                    classProvider.setSelectedClass(newValue);
                  }
                },
                items: [
                  // 既存のクラス
                  ...classProvider.classes
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      // ドロップダウン内の各アイテムのテキスト色を白に変更
                      child: Text(value, style: TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  // 新しい授業を追加するオプション
                  DropdownMenuItem<String>(
                    value: '+ 新しい授業を追加',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline,
                            size: 18, color: Colors.blue[300]),
                        const SizedBox(width: 8),
                        Text(
                          '新しい授業を追加',
                          style: TextStyle(
                            color: Colors.blue[300],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 新しい授業を追加するダイアログ
  static void _showAddClassDialog(
      BuildContext context, ClassProvider classProvider) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しい授業を追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '授業名を入力',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              classProvider.addClass(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                classProvider.addClass(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  // カレンダーイベント確認用のボトムシート
  static void showCalendarEventBottomSheet({
    required BuildContext context,
    required CalendarEventProposal proposal,
    required VoiceRecognitionUIService uiService,
    required ValueChanged<CalendarEventProposal> onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bottomSheetContext) {
        return EditableCalendarEventSheet(
          proposal: proposal,
          uiService: uiService,
          onConfirm: onConfirm,
        );
      },
    );
  }
}
