import '../models/calendar_event_proposal.dart';
import '../models/event_time.dart' as proposal_time;
import '../models/models.dart' as api_models;
import '../models/reminder.dart' as proposal_reminder;

/// カレンダー追加フローを手元で確認するためのモックデータ。
/// UI テストやデモで `CalendarInboxProvider.addAll` に流し込む用途を想定。
class CalendarMockData {
  static final List<_EventSeed> _seeds = [
    _EventSeed(
      summary: 'プロジェクトキックオフ',
      description: '進行方法の合意と役割分担を決定するミーティング',
      startDateTime: '2025-12-15T10:00:00+09:00',
      endDateTime: '2025-12-15T11:00:00+09:00',
      timeZone: 'Asia/Tokyo',
      location: 'オンライン (Meet)',
      attendees: ['pm@example.com', 'dev@example.com'],
      useDefaultReminders: false,
      reminders: const [
        ReminderSeed(method: 'popup', minutes: 10),
        ReminderSeed(method: 'email', minutes: 60),
      ],
    ),
    _EventSeed(
      summary: 'チーム週次スタンドアップ',
      description: '進捗共有とブロッカー確認',
      startDateTime: '2025-12-17T09:30:00+09:00',
      endDateTime: '2025-12-17T10:00:00+09:00',
      timeZone: 'Asia/Tokyo',
      location: 'A会議室',
      attendees: ['lead@example.com'],
      useDefaultReminders: true,
      reminders: const [],
    ),
    _EventSeed(
      summary: '有休申請',
      description: '終日扱いの休暇申請',
      startDate: '2025-12-01',
      endDate: '2025-12-01',
      timeZone: 'Asia/Tokyo',
      location: null,
      attendees: const [],
      useDefaultReminders: false,
      reminders: const [
        ReminderSeed(method: 'popup', minutes: 1440), // 前日通知
      ],
    ),
  ];

  /// バックエンドレスポンスを模した CalendarEvent 一覧。
  static List<api_models.CalendarEvent> get calendarEvents =>
      _seeds.map((seed) => seed.toCalendarEvent()).toList();

  /// ボトムシート表示用の CalendarEventProposal 一覧。
  static List<CalendarEventProposal> get proposals =>
      _seeds.map((seed) => seed.toProposal()).toList();

  /// TwoStageResponse にまとめたモックレスポンス。
  static api_models.TwoStageResponse buildTwoStageResponse({
    String summarizedText = '音声入力から抽出されたイベントのサンプルです。',
  }) {
    return api_models.TwoStageResponse(
      summarizedText: summarizedText,
      calendarEvents: calendarEvents,
    );
  }
}

class _EventSeed {
  final String summary;
  final String? description;
  final String? startDateTime;
  final String? startDate;
  final String? endDateTime;
  final String? endDate;
  final String? timeZone;
  final String? location;
  final List<String> attendees;
  final bool useDefaultReminders;
  final List<ReminderSeed> reminders;

  const _EventSeed({
    required this.summary,
    required this.description,
    this.startDateTime,
    this.startDate,
    this.endDateTime,
    this.endDate,
    this.timeZone,
    this.location,
    this.attendees = const [],
    required this.useDefaultReminders,
    this.reminders = const [],
  }) : assert(
          startDateTime != null || startDate != null,
          'startDateTimeまたはstartDateのいずれかは必須です',
        );

  api_models.CalendarEvent toCalendarEvent() {
    return api_models.CalendarEvent(
      summary: summary,
      description: description,
      start: api_models.EventTime(
        dateTime: startDateTime,
        date: startDate,
        timeZone: timeZone,
      ),
      end: api_models.EventTime(
        dateTime: endDateTime,
        date: endDate,
        timeZone: timeZone,
      ),
      location: location,
      attendees: attendees.isNotEmpty ? attendees : null,
      reminders: api_models.Reminders(
        useDefault: useDefaultReminders,
        overrides: reminders.isNotEmpty
            ? reminders
                .map((r) => api_models.ReminderMethod(
                      method: r.method,
                      minutes: r.minutes,
                    ))
                .toList()
            : null,
      ),
    );
  }

  CalendarEventProposal toProposal() {
    return CalendarEventProposal(
      summary: summary,
      description: description,
      start: proposal_time.EventTime(
        dateTime: startDateTime,
        date: startDate,
        timeZone: timeZone,
      ),
      end: proposal_time.EventTime(
        dateTime: endDateTime,
        date: endDate,
        timeZone: timeZone,
      ),
      location: location,
      attendees: attendees.isNotEmpty ? attendees : null,
      reminders: proposal_reminder.Reminders(
        useDefault: useDefaultReminders,
        overrides: reminders.isNotEmpty
            ? reminders
                .map((r) => proposal_reminder.ReminderMethod(
                      method: r.method,
                      minutes: r.minutes,
                    ))
                .toList()
            : null,
      ),
    );
  }
}

class ReminderSeed {
  final String method;
  final int minutes;

  const ReminderSeed({
    required this.method,
    required this.minutes,
  });
}
