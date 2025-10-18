import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendar_event_proposal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// バックエンドからのレスポンスをテストするためのサービス
class BackendTestService {
  // final String backendUrl;

  /// backendUrl が渡されなければ `assets/.env` の `BACKEND_URL` を参照し、
  /// それもなければローカルのフォールバックを使用する
  // BackendTestService({String? backendUrl})
  //     : backendUrl =
  //           backendUrl ?? dotenv.env['BACKEND_URL'] ?? 'http://localhost:8080';

  static String? get backendUrl => dotenv.env['BACKEND_URL'];

  /// バックエンドの /summarize エンドポイントをテストして、
  /// カレンダーイベントのリストを取得する
  Future<List<CalendarEventProposal>> testSummarizeEndpoint(
      String text, String keyword) async {
    try {
      print('🔍 環境変数の確認:');
      print('  BACKEND_URL: $backendUrl');
      print('  dotenv.env: ${dotenv.env}');

      if (backendUrl == null || backendUrl!.isEmpty) {
        throw Exception('BACKEND_URLが設定されていません。assets/.envファイルを確認してください。');
      }

      final url = Uri.parse('$backendUrl/summarize');

      // print('🔄 バックエンドにリクエスト送信中...');
      // print('URL: $url');
      // print('リクエストボディ: {"text": "$text", "keyword": "$keyword"}');

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'keyword': keyword,
        }),
      )
          .timeout(
        const Duration(seconds: 120), // Renderの起動を待つため120秒に延長
        onTimeout: () {
          throw Exception('バックエンドへのリクエストがタイムアウトしました(120秒)\n'
              'Renderの無料プランはスリープから起動するのに時間がかかる場合があります。\n'
              'もう一度試してみてください。');
        },
      );

      print('📥 レスポンス受信: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ レスポンスデータ: $responseData');

        // calendar_events フィールドからイベントリストを取得
        if (responseData['calendar_events'] != null) {
          final eventsJson = responseData['calendar_events'] as List;
          final events = eventsJson
              .map((eventJson) => CalendarEventProposal.fromJson(
                  eventJson as Map<String, dynamic>))
              .toList();

          print('📅 ${events.length}個のカレンダーイベントを取得しました');
          for (var event in events) {
            print('  - ${event.summary}: ${event.start.dateTime}');
          }

          return events;
        } else {
          print('⚠️ calendar_events フィールドが見つかりません');
          return [];
        }
      } else {
        throw Exception('バックエンドエラー: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ エラーが発生しました: $e');
      rethrow;
    }
  }

  /// 事前に定義されたテストケースでバックエンドをテストする
  Future<List<CalendarEventProposal>> runTestCase() async {
    const testText =
        'レポートの提出期限は来週の金曜日です。数学の宿題は明後日までに終わらせて、英語のスピーチ発表は来月の第2週に予定されています。';
    const testKeyword = '課題';

    print('🧪 テストケース実行中...');
    print('テキスト: $testText');
    print('キーワード: $testKeyword');

    return await testSummarizeEndpoint(testText, testKeyword);
  }
}
