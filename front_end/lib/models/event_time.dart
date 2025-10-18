/// Google Calendar APIのイベント時刻を表すデータモデル
///
/// `dateTime`か`date`のいずれかが設定されます：
/// - `dateTime`: 特定の時刻を持つイベント（例：2025-10-11T14:30:00+09:00）
/// - `date`: 終日イベント（例：2025-10-11）
class EventTime {
  /// ISO 8601形式の日時文字列（タイムゾーン情報を含む）
  final String? dateTime;

  /// 終日イベント用の日付文字列（YYYY-MM-DD形式）
  final String? date;

  /// タイムゾーン（例：'Asia/Tokyo'）
  final String? timeZone;

  EventTime({
    this.dateTime,
    this.date,
    this.timeZone,
  });

  /// `dateTime`または`date`をDartの`DateTime`オブジェクトに変換
  ///
  /// `dateTime`が設定されている場合はそれをパース、
  /// そうでなければ`date`をパースして返します。
  DateTime? get toDateTime {
    if (dateTime != null && dateTime!.isNotEmpty) {
      try {
        return DateTime.parse(dateTime!);
      } catch (e) {
        print('Error parsing dateTime: $e');
        return null;
      }
    } else if (date != null && date!.isNotEmpty) {
      try {
        return DateTime.parse(date!);
      } catch (e) {
        print('Error parsing date: $e');
        return null;
      }
    }
    return null;
  }

  /// JSONからEventTimeオブジェクトを作成
  factory EventTime.fromJson(Map<String, dynamic> json) {
    return EventTime(
      dateTime: json['dateTime'] as String?,
      date: json['date'] as String?,
      timeZone: json['timeZone'] as String?,
    );
  }

  /// EventTimeオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (dateTime != null) data['dateTime'] = dateTime;
    if (date != null) data['date'] = date;
    if (timeZone != null) data['timeZone'] = timeZone;
    return data;
  }

  @override
  String toString() {
    return 'EventTime(dateTime: $dateTime, date: $date, timeZone: $timeZone)';
  }
}
