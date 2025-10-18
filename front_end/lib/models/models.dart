import 'dart:convert';

/// 音声認識テキストから抽出した
/// スケジュール候補を表すモデル
class ScheduleCandidate {
  final DateTime time;
  final String summary;

  ScheduleCandidate({
    required this.time,
    required this.summary,
  });

  @override
  String toString() => '$summary @ $time';
}

/// 要約のために文字列を送信するためのモデル
class RecognitionObject {
  final String keyword;
  final String text;

  RecognitionObject({
    required this.keyword,
    required this.text,
  });

  // JSONに変換するメソッド（バックエンドAPI送信用）
  Map<String, dynamic> toJson() {
    return {
      'keyword': keyword,
      'text': text,
    };
  }

  // JSONから変換するメソッド（必要に応じて）
  factory RecognitionObject.fromJson(Map<String, dynamic> json) {
    return RecognitionObject(
      keyword: json['keyword'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

/// バックエンドAPIへの要約リクエスト用モデル
class SummarizeRequest {
  final String text;
  final String? keyword;  // この行を追加
  final int? maxLength;

  SummarizeRequest({
    required this.text,
    this.keyword,  // この行を追加
    this.maxLength,
  });

  // JSONに変換するメソッド（バックエンドAPI送信用）
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (keyword != null) 'keyword': keyword,  // この行を追加
      if (maxLength != null) 'max_length': maxLength,
    };
  }
}

/// バックエンドAPIからの要約レスポンス用モデル
class SummarizeResponse {
  final String summarizedText;

  SummarizeResponse({
    required this.summarizedText,
  });

  // JSONから変換するメソッド
  factory SummarizeResponse.fromJson(Map<String, dynamic> json) {
    return SummarizeResponse(
      summarizedText: json['summarized_text'] ?? '',
    );
  }

  // JSONに変換するメソッド（必要に応じて）
  Map<String, dynamic> toJson() {
    return {
      'summarized_text': summarizedText,
    };
  }
}

/// カレンダーイベントのモデル
class CalendarEvent {
  final String? summary;
  final String? description;
  final EventTime? start;
  final EventTime? end;
  final String? location;
  final List<String>? attendees;
  final Reminders? reminders;

  CalendarEvent({
    this.summary,
    this.description,
    this.start,
    this.end,
    this.location,
    this.attendees,
    this.reminders,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      summary: json['summary'],
      description: json['description'],
      start: json['start'] != null ? EventTime.fromJson(json['start']) : null,
      end: json['end'] != null ? EventTime.fromJson(json['end']) : null,
      location: json['location'],
      attendees: json['attendees'] != null ? List<String>.from(json['attendees']) : null,
      reminders: json['reminders'] != null ? Reminders.fromJson(json['reminders']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (summary != null) 'summary': summary,
      if (description != null) 'description': description,
      if (start != null) 'start': start!.toJson(),
      if (end != null) 'end': end!.toJson(),
      if (location != null) 'location': location,
      if (attendees != null) 'attendees': attendees,
      if (reminders != null) 'reminders': reminders!.toJson(),
    };
  }
}

/// イベント時間のモデル
class EventTime {
  final String? dateTime;
  final String? date;
  final String? timeZone;

  EventTime({
    this.dateTime,
    this.date,
    this.timeZone,
  });

  factory EventTime.fromJson(Map<String, dynamic> json) {
    return EventTime(
      dateTime: json['dateTime'],
      date: json['date'],
      timeZone: json['timeZone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (dateTime != null) 'dateTime': dateTime,
      if (date != null) 'date': date,
      if (timeZone != null) 'timeZone': timeZone,
    };
  }
}

/// リマインダー設定のモデル
class Reminders {
  final bool useDefault;
  final List<ReminderMethod>? overrides;

  Reminders({
    required this.useDefault,
    this.overrides,
  });

  factory Reminders.fromJson(Map<String, dynamic> json) {
    return Reminders(
      useDefault: json['useDefault'] ?? false,
      overrides: json['overrides'] != null
          ? (json['overrides'] as List).map((e) => ReminderMethod.fromJson(e)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'useDefault': useDefault,
      if (overrides != null) 'overrides': overrides!.map((e) => e.toJson()).toList(),
    };
  }
}

/// リマインダー方法のモデル
class ReminderMethod {
  final String method;
  final int minutes;

  ReminderMethod({
    required this.method,
    required this.minutes,
  });

  factory ReminderMethod.fromJson(Map<String, dynamic> json) {
    return ReminderMethod(
      method: json['method'] ?? '',
      minutes: json['minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'minutes': minutes,
    };
  }
}

/// 拡張されたSummarizeResponseモデル（CalendarEventを含む）
class ExtendedSummarizeResponse {
  final String summarizedText;
  final List<CalendarEvent>? events;

  ExtendedSummarizeResponse({
    required this.summarizedText,
    this.events,
  });

  factory ExtendedSummarizeResponse.fromJson(Map<String, dynamic> json) {
    return ExtendedSummarizeResponse(
      summarizedText: json['summarized_text'] ?? '',
      events: null, // JSONからのパースは別途実装
    );
  }

  /// レスポンステキストからCalendarEventを抽出
  factory ExtendedSummarizeResponse.fromText(String summarizedText) {
    List<CalendarEvent>? extractedEvents;
    
    // JSONブロックの抽出を試行
    final jsonRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonRegex.firstMatch(summarizedText);
    
    if (match != null) {
      try {
        final jsonString = match.group(1);
        if (jsonString != null) {
          final dynamic jsonData = json.decode(jsonString);
          if (jsonData is List) {
            extractedEvents = jsonData.map((e) => CalendarEvent.fromJson(e)).toList();
          }
        }
      } catch (e) {
        print('JSONパースエラー: $e');
      }
    }
    
    return ExtendedSummarizeResponse(
      summarizedText: summarizedText,
      events: extractedEvents,
    );
  }
}

/// 2段階処理のレスポンスモデル
class TwoStageResponse {
  final String summarizedText;
  final List<CalendarEvent> calendarEvents;

  TwoStageResponse({
    required this.summarizedText,
    required this.calendarEvents,
  });

  factory TwoStageResponse.fromJson(Map<String, dynamic> json) {
    return TwoStageResponse(
      summarizedText: json['summarized_text'] ?? '',
      calendarEvents: (json['calendar_events'] as List?)
          ?.map((e) => CalendarEvent.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summarized_text': summarizedText,
      'calendar_events': calendarEvents.map((e) => e.toJson()).toList(),
    };
  }
}