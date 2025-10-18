import 'package:flutter/material.dart';
import '../models/calendar_event_proposal.dart';
import '../models/event_time.dart';
import '../models/reminder.dart';
import '../services/voiceRecognitionUIService.dart';
import '../services/googleCalendarService.dart';

/// 編集可能なカレンダーイベント確認用ボトムシート
class EditableCalendarEventSheet extends StatefulWidget {
  final CalendarEventProposal proposal;
  final VoiceRecognitionUIService uiService;
  final ValueChanged<CalendarEventProposal> onConfirm;

  const EditableCalendarEventSheet({
    Key? key,
    required this.proposal,
    required this.uiService,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _EditableCalendarEventSheetState createState() =>
      _EditableCalendarEventSheetState();
}

class _EditableCalendarEventSheetState
    extends State<EditableCalendarEventSheet> {
  late TextEditingController _summaryController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late DateTime _startDateTime;
  late DateTime? _endDateTime;

  bool _isAllDay = false; // 終日フラグ
  bool _enableReminder = false; // デフォルトはオフ
  String _reminderPreset = '1時間前'; // プリセット選択
  int _reminderMinutes = 60; // リマインダーの分数
  bool _isCustomReminder = false; // カスタム入力かどうか

  @override
  void initState() {
    super.initState();

    // コントローラーの初期化
    _summaryController = TextEditingController(text: widget.proposal.summary);
    _descriptionController = TextEditingController(
      text: widget.proposal.description ?? '',
    );
    _locationController = TextEditingController(
      text: widget.proposal.location ?? '',
    );

    // 終日フラグの初期化（dateプロパティが設定されていれば終日）
    _isAllDay = widget.proposal.start.date != null;

    // 日時の初期化
    _startDateTime = widget.proposal.start.toDateTime ?? DateTime.now();
    _endDateTime = widget.proposal.end?.toDateTime;

    // リマインダーの初期化
    _enableReminder = widget.proposal.reminders != null &&
        !widget.proposal.reminders!.useDefault &&
        widget.proposal.reminders!.overrides != null &&
        widget.proposal.reminders!.overrides!.isNotEmpty;

    // 既存のリマインダーから時間を取得
    if (_enableReminder && widget.proposal.reminders!.overrides!.isNotEmpty) {
      final minutes = widget.proposal.reminders!.overrides!.first.minutes;
      _reminderMinutes = minutes;

      // プリセットに該当するか確認
      if (minutes == 10) {
        _reminderPreset = '10分前';
      } else if (minutes == 60) {
        _reminderPreset = '1時間前';
      } else if (minutes == 1440) {
        _reminderPreset = '1日前';
      } else {
        _reminderPreset = 'カスタム';
        _isCustomReminder = true;
      }
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // 日付選択ダイアログを表示
  Future<void> _selectDate(bool isStart) async {
    final DateTime initialDate =
        isStart ? _startDateTime : (_endDateTime ?? _startDateTime);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          _startDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _startDateTime.hour,
            _startDateTime.minute,
          );
          // 開始日が終了日より後になった場合、終了日を調整
          if (_endDateTime != null && _startDateTime.isAfter(_endDateTime!)) {
            _endDateTime = _startDateTime.add(Duration(hours: 1));
          }
        } else {
          _endDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _endDateTime?.hour ?? _startDateTime.hour,
            _endDateTime?.minute ?? _startDateTime.minute,
          );
        }
      });
    }
  }

  // 時間選択ダイアログを表示
  Future<void> _selectTime(bool isStart) async {
    final DateTime initialDate =
        isStart ? _startDateTime : (_endDateTime ?? _startDateTime);

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime != null) {
      setState(() {
        if (isStart) {
          _startDateTime = DateTime(
            _startDateTime.year,
            _startDateTime.month,
            _startDateTime.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          // 開始時刻が終了時刻より後になった場合、終了時刻を調整
          if (_endDateTime != null && _startDateTime.isAfter(_endDateTime!)) {
            _endDateTime = _startDateTime.add(Duration(hours: 1));
          }
        } else {
          _endDateTime = DateTime(
            _endDateTime!.year,
            _endDateTime!.month,
            _endDateTime!.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        }
      });
    }
  }

  // 日付を読みやすい形式にフォーマット
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }

  // 日付を短縮形式でフォーマット（月/日のみ）
  String _formatDateShort(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}';
  }

  // 時間を読みやすい形式にフォーマット
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ヘッダー（固定）
          _buildHeader(),

          // 区切り線
          Divider(height: 1, thickness: 1),

          // スクロール可能なコンテンツ
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 予定名
                  TextField(
                    controller: _summaryController,
                    style: TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: '予定名',
                      labelStyle: TextStyle(color: Colors.black),
                      hintText: '予定のタイトルを入力',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  SizedBox(height: 20),

                  // 2. 日時設定エリア
                  Container(
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 終日スイッチ
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '終日',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          value: _isAllDay,
                          onChanged: (bool? value) {
                            setState(() {
                              _isAllDay = value ?? false;
                              if (_isAllDay) {
                                // 終日ONの場合、時刻を00:00にリセット
                                _startDateTime = DateTime(
                                  _startDateTime.year,
                                  _startDateTime.month,
                                  _startDateTime.day,
                                );
                                if (_endDateTime != null) {
                                  _endDateTime = DateTime(
                                    _endDateTime!.year,
                                    _endDateTime!.month,
                                    _endDateTime!.day,
                                  );
                                }
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        SizedBox(height: 12),

                        // 日付・時刻を1行で表示
                        Row(
                          children: [
                            // 日付ボタン
                            Expanded(
                              child: _buildDateTimeButton(
                                icon: Icons.calendar_today,
                                label: _isAllDay
                                    ? _formatDate(_startDateTime)
                                    : _formatDateShort(_startDateTime),
                                onTap: () => _selectDate(true),
                              ),
                            ),
                            if (!_isAllDay) ...[
                              SizedBox(width: 8),
                              // 開始時刻
                              Expanded(
                                child: _buildDateTimeButton(
                                  icon: Icons.access_time,
                                  label: _formatTime(_startDateTime),
                                  onTap: () => _selectTime(true),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('-',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.black)),
                              SizedBox(width: 8),
                              // 終了時刻
                              Expanded(
                                child: _buildDateTimeButton(
                                  icon: Icons.access_time,
                                  label: _endDateTime != null
                                      ? _formatTime(_endDateTime!)
                                      : _formatTime(_startDateTime),
                                  onTap: () => _selectTime(false),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_isAllDay && _endDateTime != null) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text('〜', style: TextStyle(color: Colors.black)),
                              SizedBox(width: 8),
                              Expanded(
                                child: _buildDateTimeButton(
                                  icon: Icons.calendar_today,
                                  label: _formatDate(_endDateTime!),
                                  onTap: () => _selectDate(false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // 3. 説明
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: '説明',
                      labelStyle: TextStyle(color: Colors.black),
                      hintText: '予定の説明を入力（任意）',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  SizedBox(height: 20),

                  // 4. リマインダー
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'リマインダー',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          value: _enableReminder,
                          onChanged: (value) {
                            setState(() {
                              _enableReminder = value;
                            });
                          },
                        ),
                        if (_enableReminder) ...[
                          SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: _reminderPreset,
                            dropdownColor: Colors.white,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            items: ['10分前', '1時間前', '1日前', 'カスタム']
                                .map((preset) => DropdownMenuItem(
                                      value: preset,
                                      child: Text(preset,
                                          style:
                                              TextStyle(color: Colors.black)),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _reminderPreset = value!;
                                _isCustomReminder = value == 'カスタム';

                                // プリセット値を分数に変換
                                if (value == '10分前') {
                                  _reminderMinutes = 10;
                                } else if (value == '1時間前') {
                                  _reminderMinutes = 60;
                                } else if (value == '1日前') {
                                  _reminderMinutes = 1440;
                                }
                              });
                            },
                          ),
                          if (_isCustomReminder) ...[
                            SizedBox(height: 12),
                            TextField(
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: '通知時間（分）',
                                labelStyle: TextStyle(color: Colors.black),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                suffixText: '分前',
                                suffixStyle: TextStyle(color: Colors.black),
                              ),
                              onChanged: (value) {
                                final minutes = int.tryParse(value);
                                if (minutes != null && minutes >= 0) {
                                  setState(() {
                                    _reminderMinutes = minutes;
                                  });
                                }
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ヘッダーウィジェット
  Widget _buildHeader() {
    final totalEvents =
        widget.uiService.currentEventNumber + widget.uiService.eventQueueLength;
    final hasMultipleEvents = totalEvents > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左側：スキップボタン（以前は閉じるボタン）
              IconButton(
                icon: Icon(Icons.close, color: Colors.black),
                tooltip: 'スキップして次へ',
                onPressed: () {
                  // ボトムシートを閉じてスキップ処理を行い、Undoを表示する
                  Navigator.pop(context);
                  widget.uiService.skipCurrentEvent();
                },
              ),

              // 中央：進捗表示またはドラッグハンドル
              if (hasMultipleEvents)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalEvents個中${widget.uiService.currentEventNumber}個目',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

              // 右側：保存ボタン
              TextButton(
                onPressed: _handleConfirm,
                child: Text(
                  '保存',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),

        // （スキップボタンはヘッダーの左側に統合したため、下のボタンは削除）
      ],
    );
  }

  // 日付・時刻ボタンのヘルパーウィジェット
  Widget _buildDateTimeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 確認処理
  void _handleConfirm() async {
    // 予定名チェック
    if (_summaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('予定名を入力してね！')),
      );
      return;
    }

    // 更新されたproposalを作成
    final updatedProposal = CalendarEventProposal(
      summary: _summaryController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      start: _isAllDay
          ? EventTime(
              date: _formatDate(_startDateTime), // 終日の場合はdateプロパティを使用
              timeZone: widget.proposal.start.timeZone,
            )
          : EventTime(
              dateTime: _startDateTime.toIso8601String(), // 通常の場合はdateTimeプロパティ
              timeZone: widget.proposal.start.timeZone,
            ),
      end: _endDateTime != null
          ? (_isAllDay
              ? EventTime(
                  date: _formatDate(_endDateTime!), // 終日の場合はdateプロパティを使用
                  timeZone: widget.proposal.end?.timeZone,
                )
              : EventTime(
                  dateTime:
                      _endDateTime!.toIso8601String(), // 通常の場合はdateTimeプロパティ
                  timeZone: widget.proposal.end?.timeZone,
                ))
          : null,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      reminders: _enableReminder
          ? Reminders(
              useDefault: false,
              overrides: [
                ReminderMethod(
                  method: 'email',
                  minutes: _reminderMinutes, // 分数をそのまま使用
                ),
              ],
            )
          : null,
    );

    // カレンダーに追加
    try {
      final calendarService = GoogleCalendarService();
      await calendarService.createEventFromProposal(updatedProposal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ カレンダーに追加しました: ${updatedProposal.summary}'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ カレンダー追加エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ カレンダー追加に失敗しました: $e'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onConfirm(updatedProposal);
      // 次のイベントを表示（キューが空なら何もしない）
      widget.uiService.confirmAndNext();
    }
  }
}
