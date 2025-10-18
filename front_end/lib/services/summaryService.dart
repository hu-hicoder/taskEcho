import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';
import '../services/geminiService.dart';

/// 要約処理を管理するサービス（フロントエンド/バックエンド切り替え対応）
class SummaryService {
  // 設定関連
  static bool get useBackend => dotenv.env['USE_BACKEND']?.toLowerCase() == 'true';
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:8080';
  
  /// 2段階処理を使用した要約とイベント抽出
  /// [text] 要約したいテキスト
  /// [keyword] キーワード（オプション）
  /// [maxLength] 最大文字数（オプション）
  /// 戻り値: TwoStageResponse（段階別の結果とCalendarEventリスト）
  static Future<TwoStageResponse?> summarizeWithTwoStage(String text, {String? keyword, int? maxLength}) async {
    _printConfig();
    
    if (useBackend) {
      print('バックエンドAPIを使用して2段階要約します');
      return await _summarizeWithBackendTwoStage(text, keyword: keyword, maxLength: maxLength);
    } else {
      print('フロントエンドでGemini APIを直接使用して2段階要約します');
      return await _summarizeWithFrontendTwoStage(text, keyword: keyword, maxLength: maxLength);
    }
  }

  /// 設定に応じて適切な要約サービスを使用してテキストを要約
  /// [text] 要約したいテキスト
  /// [keyword] キーワード（オプション）
  /// [maxLength] 最大文字数（オプション）
  /// 戻り値: ExtendedSummarizeResponse（要約テキストとCalendarEventリスト）
  static Future<ExtendedSummarizeResponse?> summarizeWithEvents(String text, {String? keyword, int? maxLength}) async {
    // 2段階処理を使用して、結果をExtendedSummarizeResponseに変換
    final twoStageResult = await summarizeWithTwoStage(text, keyword: keyword, maxLength: maxLength);
    
    if (twoStageResult == null) return null;
    
    return ExtendedSummarizeResponse(
      summarizedText: twoStageResult.summarizedText,
      events: twoStageResult.calendarEvents,
    );
  }

  /// 既存のsummarizeメソッド（後方互換性のため）
  /// [text] 要約したいテキスト
  /// [keyword] キーワード（オプション）
  /// [maxLength] 最大文字数（オプション）
  static Future<String?> summarize(String text, {String? keyword, int? maxLength}) async {
    final result = await summarizeWithEvents(text, keyword: keyword, maxLength: maxLength);
    return result?.summarizedText;
  }
  
  /// キーワード周辺のテキストを抽出して要約する（設定に応じて切り替え）
  /// [fullText] 全体のテキスト
  /// [keywords] 検索するキーワードのリスト
  /// [contextLength] 前後の文脈の長さ（デフォルト200文字）
  static Future<String> extractAndSummarize(
    String fullText, 
    List<String> keywords, 
    {int contextLength = 200}
  ) async {
    if (keywords.isEmpty) {
      return fullText;
    }
    
    String keyword = keywords.first;
    
    // キーワードの位置を見つける
    int keywordIndex = fullText.indexOf(keyword);
    if (keywordIndex == -1) {
      print('キーワード「$keyword」が見つかりません');
      return fullText;
    }
    
    // 前後の文脈を含めるための範囲を計算
    int startIndex = (keywordIndex - contextLength) < 0 ? 0 : keywordIndex - contextLength;
    int endIndex = (keywordIndex + keyword.length + contextLength) > fullText.length
        ? fullText.length
        : keywordIndex + keyword.length + contextLength;
    
    // 抽出したテキスト
    String extractedText = fullText.substring(startIndex, endIndex);
    String fallbackText = "【キーワード「$keyword」の周辺テキスト】: $extractedText";
    
    // 要約を試行
    final summary = await summarize(extractedText, keyword: keyword);
    
    if (summary != null && summary.isNotEmpty) {
      return "【キーワード「$keyword」の要約】: $summary";
    } else {
      // 要約が失敗した場合は抽出したテキストをそのまま返す
      return fallbackText;
    }
  }
  
  /// バックエンドAPIを使用して2段階要約
  static Future<TwoStageResponse?> _summarizeWithBackendTwoStage(String text, {String? keyword, int? maxLength}) async {
    try {
      final url = Uri.parse('$backendUrl/summarize');
      
      final request = SummarizeRequest(
        text: text,
        keyword: keyword,
        maxLength: maxLength,
      );
      
      print('バックエンド2段階APIリクエスト: ${url.toString()}');
      print('リクエストデータ: ${jsonEncode(request.toJson())}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          print('バックエンドAPI呼び出しがタイムアウトしました（30秒）');
          throw Exception('Backend API timeout');
        },
      );
      
      print('バックエンド2段階APIレスポンス: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('2段階レスポンスデータ: $responseData');
        
        final twoStageResponse = TwoStageResponse.fromJson(responseData);
        print('2段階要約結果: ${twoStageResponse.summarizedText}');
        print('イベント数: ${twoStageResponse.calendarEvents.length}');
        
        return twoStageResponse;
      } else {
        print('Backend API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Backend API exception: $e');
      return null;
    }
  }

  /// フロントエンドでGemini APIを直接使用して2段階要約
  static Future<TwoStageResponse?> _summarizeWithFrontendTwoStage(String text, {String? keyword, int? maxLength}) async {
    try {
      // 第1段階：要約生成
      final summaryText = await GeminiService.summarize(text, keyword: keyword, maxLength: maxLength);
      if (summaryText == null) return null;
      
      // 第2段階：カレンダーイベント抽出（簡易版）
      // フロントエンドではExtendedSummarizeResponseを利用
      final extendedResponse = ExtendedSummarizeResponse.fromText(summaryText);
      
      return TwoStageResponse(
        summarizedText: summaryText,
        calendarEvents: extendedResponse.events ?? [],
      );
    } catch (e) {
      print('Frontend Gemini API exception: $e');
      return null;
    }
  }

  /// バックエンドの接続状況を確認
  static Future<bool> checkBackendConnection() async {
    if (!useBackend) {
      print('バックエンドモードが無効になっています');
      return false;
    }
    
    try {
      final url = Uri.parse('$backendUrl/health');
      final response = await http.get(url).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('バックエンド接続確認がタイムアウトしました');
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        print('バックエンドへの接続が正常です');
        return true;
      } else {
        print('バックエンドからエラーレスポンス: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('バックエンド接続確認エラー: $e');
      return false;
    }
  }
  
  /// 現在の設定で利用可能かどうかを確認
  static Future<bool> checkAvailability() async {
    if (useBackend) {
      return await checkBackendConnection();
    } else {
      // フロントエンドの場合はGeminiServiceの初期化状況を確認
      if (!GeminiService.isInitialized) {
        print('GeminiServiceが初期化されていません。初期化を試行します...');
        return await GeminiService.initialize();
      }
      return true;
    }
  }
  
  /// 設定情報を出力（デバッグ用）
  static void _printConfig() {
    print('=== Summary Service 設定 ===');
    print('USE_BACKEND: $useBackend');
    print('BACKEND_URL: $backendUrl');
    print('現在のモード: ${useBackend ? "バックエンド" : "フロントエンド"}');
    print('===========================');
  }
  
  /// 設定情報を取得
  static Map<String, dynamic> getConfig() {
    return {
      'useBackend': useBackend,
      'backendUrl': backendUrl,
      'currentMode': useBackend ? 'backend' : 'frontend',
      'geminiApiKeySet': GeminiService.geminiApiKey != null,
    };
  }
}
