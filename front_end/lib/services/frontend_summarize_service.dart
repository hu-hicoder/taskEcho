import 'package:flutter_gemini/flutter_gemini.dart';
import '../config/app_config.dart';

/// フロントエンドでGemini APIを直接使用するサービス
class FrontendSummarizeService {
  static Gemini? _gemini;
  static bool _initialized = false;

  /// Gemini APIの初期化
  static Future<bool> initialize() async {
    if (_initialized) return true;
    
    try {
      final apiKey = AppConfig.geminiApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        print('GEMINI_API_KEY が設定されていません');
        return false;
      }
      
      Gemini.init(apiKey: apiKey, enableDebugging: true);
      _gemini = Gemini.instance;
      
      // 初期化テスト
      final testResult = await _gemini!.text('テスト');
      if (testResult != null && testResult.output != null) {
        _initialized = true;
        print('Gemini API初期化成功');
        return true;
      } else {
        print('Gemini APIテスト失敗');
        return false;
      }
    } catch (e) {
      print('Gemini API初期化エラー: $e');
      return false;
    }
  }

  /// フロントエンドでGemini APIを使用して要約を取得
  static Future<String?> summarize(String text, {String? keyword}) async {
    try {
      if (!_initialized || _gemini == null) {
        final initSuccess = await initialize();
        if (!initSuccess) {
          return null;
        }
      }

      String prompt;
      if (keyword != null) {
        prompt = '''
以下のテキストを要約してください。キーワード「$keyword」に関連する重要な情報を保持しつつ、100文字以内で簡潔にまとめてください：

$text
''';
      } else {
        prompt = '''
以下のテキストを100文字以内で簡潔に要約してください：

$text
''';
      }

      final result = await _gemini!.text(prompt);
      
      if (result != null && result.output != null) {
        return result.output!.trim();
      } else {
        print('Gemini API からの応答が空です');
        return null;
      }
    } catch (e) {
      print('フロントエンド要約エラー: $e');
      return null;
    }
  }
}
