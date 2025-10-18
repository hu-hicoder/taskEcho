/// リマインダーの通知方法を表すデータモデル
class ReminderMethod {
  /// 通知方法（'email' または 'popup'）
  final String method;

  /// イベント開始前の何分前に通知するか
  final int minutes;

  ReminderMethod({
    required this.method,
    required this.minutes,
  });

  /// JSONからReminderMethodオブジェクトを作成
  factory ReminderMethod.fromJson(Map<String, dynamic> json) {
    return ReminderMethod(
      method: json['method'] as String,
      minutes: json['minutes'] as int,
    );
  }

  /// ReminderMethodオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'minutes': minutes,
    };
  }

  @override
  String toString() {
    return 'ReminderMethod(method: $method, minutes: $minutes)';
  }
}

/// リマインダー設定を表すデータモデル
class Reminders {
  /// デフォルトのリマインダーを使用するかどうか
  final bool useDefault;

  /// カスタムリマインダーのリスト
  final List<ReminderMethod>? overrides;

  Reminders({
    required this.useDefault,
    this.overrides,
  });

  /// JSONからRemindersオブジェクトを作成
  factory Reminders.fromJson(Map<String, dynamic> json) {
    return Reminders(
      useDefault: json['useDefault'] as bool,
      overrides: json['overrides'] != null
          ? (json['overrides'] as List)
              .map((item) => ReminderMethod.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  /// RemindersオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'useDefault': useDefault,
    };
    if (overrides != null) {
      data['overrides'] = overrides!.map((item) => item.toJson()).toList();
    }
    return data;
  }

  @override
  String toString() {
    return 'Reminders(useDefault: $useDefault, overrides: $overrides)';
  }
}
