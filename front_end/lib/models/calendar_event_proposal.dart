import 'event_time.dart';
import 'reminder.dart';

/// カレンダーイベント提案のデータモデル
///
/// 音声認識で検出した日時情報をユーザーに確認してもらうための
/// データを保持します。
/// バックエンドのGoの構造体に対応しています。
class CalendarEventProposal {
  /// 予定のタイトル
  final String summary;

  /// 予定の説明（オプション）
  final String? description;

  /// 予定の開始日時
  final EventTime start;

  /// 予定の終了日時（オプション）
  final EventTime? end;

  /// 予定の場所（オプション）
  final String? location;

  /// 参加者のメールアドレスリスト（オプション）
  final List<String>? attendees;

  /// リマインダー設定（オプション）
  final Reminders? reminders;

  CalendarEventProposal({
    required this.summary,
    required this.start,
    this.description,
    this.end,
    this.location,
    this.attendees,
    this.reminders,
  });

  /// JSONからCalendarEventProposalオブジェクトを作成
  factory CalendarEventProposal.fromJson(Map<String, dynamic> json) {
    return CalendarEventProposal(
      summary: json['summary'] as String,
      description: json['description'] as String?,
      start: EventTime.fromJson(json['start'] as Map<String, dynamic>),
      end: json['end'] != null
          ? EventTime.fromJson(json['end'] as Map<String, dynamic>)
          : null,
      location: json['location'] as String?,
      attendees: json['attendees'] != null
          ? List<String>.from(json['attendees'] as List)
          : null,
      reminders: json['reminders'] != null
          ? Reminders.fromJson(json['reminders'] as Map<String, dynamic>)
          : null,
    );
  }

  /// CalendarEventProposalオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'summary': summary,
      'start': start.toJson(),
    };
    if (description != null) data['description'] = description;
    if (end != null) data['end'] = end!.toJson();
    if (location != null) data['location'] = location;
    if (attendees != null) data['attendees'] = attendees;
    if (reminders != null) data['reminders'] = reminders!.toJson();
    return data;
  }

  /// デバッグ用の文字列表現
  @override
  String toString() {
    return 'CalendarEventProposal('
        'summary: $summary, '
        'description: $description, '
        'start: $start, '
        'end: $end, '
        'location: $location, '
        'attendees: $attendees, '
        'reminders: $reminders'
        ')';
  }
}
