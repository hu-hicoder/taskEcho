import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/calendar_event_proposal.dart';

/// HTTP リクエスト時に Bearer トークンを付与するクライアント
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();
  GoogleHttpClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request..headers.addAll(_headers));
}

class GoogleCalendarService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        dotenv.env['GOOGLE_CLIENT_ID'], // AndroidではserverClientIdを使用
    scopes: [cal.CalendarApi.calendarScope],
  );

  /// GoogleSignInAccount → 認証ヘッダーつき HTTP クライアント を返す
  Future<http.Client> _getClient() async {
    // (1) 既存ユーザー or サイレントサインイン
    GoogleSignInAccount? account =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    // (2) 取れなければ明示的にサインイン
    account ??= await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google 認証情報が取得できませんでした。');
    }
    // (3) authHeaders を取得してクライアント生成
    final headers = await account.authHeaders;
    return GoogleHttpClient(headers);
  }

  /// カレンダーにイベントを作成
  Future<void> createEvent({
    required DateTime eventTime,
    required String summary,
    Duration duration = const Duration(hours: 1),
    String timeZone = 'Asia/Tokyo',
  }) async {
    // Web ではスキップ（Web版の authHeaders だと Calendar API が通らないため）
    if (kIsWeb) {
      print('Webプラットフォームではカレンダー登録をスキップ');
      return;
    }
    final client = await _getClient();
    final api = cal.CalendarApi(client);
    final event = cal.Event()
      ..summary = summary
      ..start =
          cal.EventDateTime(dateTime: eventTime.toUtc(), timeZone: timeZone)
      ..end = cal.EventDateTime(
          dateTime: eventTime.add(duration).toUtc(), timeZone: timeZone);
    await api.events.insert(event, 'primary');
    client.close();
  }

  /// CalendarEventProposalからカレンダーにイベントを作成
  Future<void> createEventFromProposal(CalendarEventProposal proposal) async {
    // Web ではスキップ（Web版の authHeaders だと Calendar API が通らないため）
    if (kIsWeb) {
      print('Webプラットフォームではカレンダー登録をスキップ');
      return;
    }

    final client = await _getClient();
    final api = cal.CalendarApi(client);

    // CalendarEventProposalからGoogle Calendar APIのEventオブジェクトを作成
    final event = cal.Event()
      ..summary = proposal.summary
      ..description = proposal.description;

    // 開始日時の設定
    final startDateTime = proposal.start.toDateTime;
    if (startDateTime != null) {
      event.start = cal.EventDateTime(
        dateTime: startDateTime.toUtc(),
        timeZone: proposal.start.timeZone ?? 'Asia/Tokyo',
      );
    }

    // 終了日時の設定
    if (proposal.end != null) {
      final endDateTime = proposal.end!.toDateTime;
      if (endDateTime != null) {
        event.end = cal.EventDateTime(
          dateTime: endDateTime.toUtc(),
          timeZone: proposal.end!.timeZone ?? 'Asia/Tokyo',
        );
      }
    } else if (startDateTime != null) {
      // 終了時刻が指定されていない場合は開始時刻+1時間
      event.end = cal.EventDateTime(
        dateTime: startDateTime.add(const Duration(hours: 1)).toUtc(),
        timeZone: proposal.start.timeZone ?? 'Asia/Tokyo',
      );
    }

    // 場所の設定
    if (proposal.location != null && proposal.location!.isNotEmpty) {
      event.location = proposal.location;
    }

    // 参加者の設定
    if (proposal.attendees != null && proposal.attendees!.isNotEmpty) {
      event.attendees = proposal.attendees!
          .map((email) => cal.EventAttendee()..email = email)
          .toList();
    }

    // リマインダーの設定
    if (proposal.reminders != null) {
      event.reminders = cal.EventReminders()
        ..useDefault = proposal.reminders!.useDefault;

      if (proposal.reminders!.overrides != null &&
          proposal.reminders!.overrides!.isNotEmpty) {
        event.reminders!.overrides = proposal.reminders!.overrides!
            .map((reminder) => cal.EventReminder()
              ..method = reminder.method
              ..minutes = reminder.minutes)
            .toList();
      }
    }

    // カレンダーにイベントを追加
    await api.events.insert(event, 'primary');
    client.close();

    print('✅ カレンダーにイベントを追加しました: ${proposal.summary}');
  }
}
