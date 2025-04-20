import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

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
    clientId: dotenv.env['GOOGLE_CLIENT_ID'],
    scopes: [cal.CalendarApi.calendarScope],
  );

  /// GoogleSignInAccount → 認証ヘッダーつき HTTP クライアント を返す
  Future<http.Client> _getClient() async {
    // (1) 既存ユーザー or サイレントサインイン
    GoogleSignInAccount? account = _googleSignIn.currentUser
        ?? await _googleSignIn.signInSilently();
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
      ..start = cal.EventDateTime(dateTime: eventTime.toUtc(), timeZone: timeZone)
      ..end   = cal.EventDateTime(dateTime: eventTime.add(duration).toUtc(), timeZone: timeZone);
    await api.events.insert(event, 'primary');
    client.close();
  }
}