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
  
  /// 設定に応じて適切な要約サービスを使用してテキストを要約
  /// [text] 要約したいテキスト
  /// [keyword] キーワード（オプション）
  /// [maxLength] 最大文字数（オプション）
  static Future<String?> summarize(String text, {String? keyword, int? maxLength}) async {
    _printConfig();
    
    if (useBackend) {
      print('バックエンドAPIを使用して要約します');
      return await _summarizeWithBackend(text, keyword: keyword, maxLength: maxLength);
    } else {
      print('フロントエンドでGemini APIを直接使用して要約します');
      return await _summarizeWithFrontend(text, keyword: keyword, maxLength: maxLength);
    }
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
  
  /// バックエンドAPIを使用して要約
  static Future<String?> _summarizeWithBackend(String text, {String? keyword, int? maxLength}) async {
    try {
      final url = Uri.parse('$backendUrl/summarize');
      
      final request = SummarizeRequest(
        text: text,
        keyword: keyword,
        maxLength: maxLength,
      );
      
      print('バックエンドAPIリクエスト: ${url.toString()}');
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
      
      print('バックエンドAPIレスポンス: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('レスポンスデータ: $responseData');
        
        final summarizeResponse = SummarizeResponse.fromJson(responseData);
        print('要約結果: ${summarizeResponse.summarizedText}');
        return summarizeResponse.summarizedText;
      } else {
        print('Backend API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Backend API exception: $e');
      return null;
    }
  }
  
  /// フロントエンドでGemini APIを直接使用して要約
  static Future<String?> _summarizeWithFrontend(String text, {String? keyword, int? maxLength}) async {
    try {
      // GeminiServiceを使用
      return await GeminiService.summarize(text, keyword: keyword, maxLength: maxLength);
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
