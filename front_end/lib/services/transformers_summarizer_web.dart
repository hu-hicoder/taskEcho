import 'dart:js' as js;
import 'dart:async';

/// Transformers.js を使った要約サービス（Web専用）
class TransformersSummarizer {
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static Completer<bool>? _initializationCompleter;

  /// 要約モデルを初期化
  static Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ 要約モデルは既に初期化済みです');
      return true;
    }

    // 既に初期化中の場合は、その完了を待つ
    if (_isInitializing && _initializationCompleter != null) {
      print('⏳ 初期化中です。完了を待機します...');
      return await _initializationCompleter!.future;
    }

    try {
      _isInitializing = true;
      _initializationCompleter = Completer<bool>();

      print('🤖 Transformers.js 要約モデルを初期化中...');
      print('   ⚠️ 初回は1-2分かかります。しばらくお待ちください...');

      final result = await js.context.callMethod('initSummarizer')
          .timeout(
            const Duration(minutes: 3),
            onTimeout: () {
              print('⚠️ 初期化がタイムアウトしました（3分経過）');
              return false;
            },
          );

      _isInitialized = result == true;
      
      if (_isInitialized) {
        print('✅ Transformers.js 初期化完了');
      } else {
        print('⚠️ Transformers.js 初期化失敗');
      }

      _isInitializing = false;
      _initializationCompleter?.complete(_isInitialized);
      
      return _isInitialized;
    } catch (e) {
      print('❌ Transformers.js 初期化エラー: $e');
      _isInitialized = false;
      _isInitializing = false;
      _initializationCompleter?.complete(false);
      return false;
    }
  }

  /// テキストを要約
  static Future<String?> summarize(String text) async {
    if (text.trim().isEmpty) {
      return null;
    }

    try {
      // 初期化されていなければ初期化
      if (!_isInitialized) {
        print('📌 要約モデルを初期化します...');
        final initialized = await initialize();
        if (!initialized) {
          print('⚠️ 要約モデルが初期化されていません（フォールバック処理へ）');
          return null;
        }
      }

      print('📝 Transformers.js で要約を生成中...');
      
      final result = await js.context.callMethod('summarizeText', [text])
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('⚠️ 要約処理がタイムアウトしました（30秒経過）');
              return null;
            },
          );
      
      if (result == null) {
        print('⚠️ 要約結果が null です');
        return null;
      }

      final summary = result.toString();
      final displayText = summary.length > 50 
          ? '${summary.substring(0, 50)}...' 
          : summary;
      print('✅ 要約完了: $displayText');
      
      return summary;
    } catch (e) {
      print('❌ Transformers.js 要約エラー: $e');
      return null;
    }
  }

  /// 初期化状態をリセット（テスト用）
  static void reset() {
    _isInitialized = false;
    _isInitializing = false;
    _initializationCompleter = null;
  }
}