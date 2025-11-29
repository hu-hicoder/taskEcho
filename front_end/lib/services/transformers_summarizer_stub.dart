/// Android/iOS用のスタブ（何もしない）
class TransformersSummarizer {
  static bool _isInitialized = false;

  /// Android/iOSでは初期化不要
  static Future<bool> initialize() async {
    print('ℹ️ TransformersSummarizer は Web 専用です（Android/iOS ではスキップ）');
    _isInitialized = true;
    return true;
  }

  /// Android/iOSでは常に null を返す
  static Future<String?> summarize(String text) async {
    print('ℹ️ TransformersSummarizer は Web 専用です（Android/iOS ではスキップ）');
    return null;
  }

  /// 初期化状態をリセット（テスト用）
  static void reset() {
    _isInitialized = false;
  }
}