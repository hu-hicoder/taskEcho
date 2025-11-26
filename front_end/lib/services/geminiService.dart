// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_speech_to_text/config/env_config.dart';

/// フロントエンドでGemini APIを直接呼び出すサービス
class GeminiService {
  // Gemini instance
  static Gemini? _gemini;
  static bool _initialized = false;
  
  // API Key取得
  static String? get geminiApiKey => EnvConfig.geminiApiKey.isNotEmpty ? EnvConfig.geminiApiKey : null;
  
  // 初期化状態の確認
  static bool get isInitialized => _initialized;
  
  /// Gemini APIの初期化
  static Future<bool> initialize() async {
    if (_initialized) {
      print('Gemini APIは既に初期化済みです');
      return true;
    }
    
    try {
      if (geminiApiKey == null || geminiApiKey!.isEmpty) {
        print('GEMINI_API_KEYが設定されていません。.envファイルを確認してください。');
        return false;
      }
      
      print('Gemini APIの初期化を開始します');
      Gemini.init(apiKey: geminiApiKey!, enableDebugging: true);
      _gemini = Gemini.instance;
      
      // 初期化テスト
      final testResult = await _gemini!.text('テスト');
      if (testResult != null && testResult.output != null) {
        _initialized = true;
        print('Gemini API初期化成功: ${testResult.output}');
        return true;
      } else {
        print('Gemini API初期化テスト失敗');
        return false;
      }
    } catch (e) {
      print('Gemini API初期化エラー: $e');
      return false;
    }
  }
  
  /// テキストを要約する
  /// [text] 要約したいテキスト
  /// [keyword] キーワード（オプション）
  /// [maxLength] 最大文字数（オプション）
  static Future<String?> summarize(String text, {String? keyword, int? maxLength}) async {
    // 初期化確認
    if (!_initialized || _gemini == null) {
      print('Gemini APIが初期化されていません。initialize()を先に呼び出してください。');
      // 自動初期化を試行
      final initResult = await initialize();
      if (!initResult) {
        return null;
      }
    }
    
    try {
      // プロンプト作成
      String prompt = _createSummarizePrompt(text, keyword: keyword, maxLength: maxLength);
      
      // Gemini APIを呼び出し（タイムアウト付き）
      final resultFuture = _gemini!.text(prompt);
      final result = await resultFuture.timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Gemini API呼び出しがタイムアウトしました（10秒）');
          return null;
        },
      );
      
      if (result != null && result.output != null && result.output!.isNotEmpty) {
        final summary = result.output!.trim();
        print('要約完了: ${summary.substring(0, summary.length > 50 ? 50 : summary.length)}...');
        return summary;
      } else {
        print('Gemini APIからの応答が空です');
        return null;
      }
    } catch (e) {
      print('要約中にエラーが発生しました: $e');
      return null;
    }
  }
  
  /// キーワード周辺のテキストを抽出して要約する
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
  
  /// プロンプトを作成する
  static String _createSummarizePrompt(String text, {String? keyword, int? maxLength}) {
    String lengthInstruction = maxLength != null ? '${maxLength}文字以内で' : '簡潔に';
    
    if (keyword != null && keyword.isNotEmpty) {
      return '''
以下のテキストを$lengthInstruction要約してください。
キーワード「$keyword」に関連する重要な情報を保持しつつ、わかりやすくまとめてください。

テキスト: $text
''';
    } else {
      return '''
以下のテキストを${lengthInstruction}要約してください：

$text
''';
    }
  }
  
  /// 初期化状態をリセット（テスト用）
  static void reset() {
    _gemini = null;
    _initialized = false;
    print('Gemini APIの初期化状態をリセットしました');
  }
}
