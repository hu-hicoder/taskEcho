import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 本番用バックエンドサービス
/// 音声認識テキストをバックエンドに送信し、要約とカレンダーイベントを取得する
class BackendService {
  static String? get backendUrl => dotenv.env['BACKEND_URL'];
  static bool get useBackend => dotenv.env['USE_BACKEND']?.toLowerCase() == 'true';

  /// バックエンドに音声認識テキストを送信し、要約とカレンダーイベントを取得する
  ///
  /// [text] 音声認識で取得したテキスト
  /// [keyword] キーワード（オプション）
  /// [maxLength] 要約の最大文字数（オプション）
  ///
  /// 戻り値: TwoStageResponse（要約テキストとカレンダーイベントのリスト）
  static Future<TwoStageResponse?> processVoiceText({
    required String text,
    String? keyword,
    int? maxLength,
  }) async {
    try {
      print('🎤 音声テキストをバックエンドで処理中...');
      print('  テキスト: $text');
      print('  キーワード: ${keyword ?? "なし"}');

      // バックエンドが有効かチェック
      if (!useBackend) {
        print('⚠️ バックエンドモードが無効です。USE_BACKEND=trueに設定してください。');
        return null;
      }

      if (backendUrl == null || backendUrl!.isEmpty) {
        throw Exception('BACKEND_URLが設定されていません。assets/.envファイルを確認してください。');
      }

      final url = Uri.parse('$backendUrl/summarize');

      // リクエストボディを作成
      final request = SummarizeRequest(
        text: text,
        keyword: keyword,
        maxLength: maxLength,
      );

      print('🔄 バックエンドにリクエスト送信中...');
      print('  URL: $url');
      print('  リクエストボディ: ${jsonEncode(request.toJson())}');

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
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

        // TwoStageResponseをパース
        final twoStageResponse = TwoStageResponse.fromJson(responseData);
        print('📝 要約テキスト: ${twoStageResponse.summarizedText}');
        print('📅 ${twoStageResponse.calendarEvents.length}個のカレンダーイベントを取得しました');

        for (var event in twoStageResponse.calendarEvents) {
          print('  - ${event.summary}: ${event.start?.dateTime}');
        }

        return twoStageResponse;
      } else {
        throw Exception('バックエンドエラー: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ エラーが発生しました: $e');
      rethrow;
    }
  }

  /// バックエンドの接続確認
  static Future<bool> checkConnection() async {
    if (!useBackend) {
      print('⚠️ バックエンドモードが無効です');
      return false;
    }

    if (backendUrl == null || backendUrl!.isEmpty) {
      print('⚠️ BACKEND_URLが設定されていません');
      return false;
    }

    try {
      final url = Uri.parse('$backendUrl/health');
      print('🔍 バックエンド接続確認: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('接続タイムアウト');
        },
      );

      if (response.statusCode == 200) {
        print('✅ バックエンド接続成功');
        return true;
      } else {
        print('❌ バックエンドエラー: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ バックエンド接続失敗: $e');
      return false;
    }
  }

  /// 設定情報を取得
  static Map<String, dynamic> getConfig() {
    return {
      'useBackend': useBackend,
      'backendUrl': backendUrl ?? 'not set',
      'isConfigured': backendUrl != null && backendUrl!.isNotEmpty && useBackend,
    };
  }
}
