import 'package:flutter_dotenv/flutter_dotenv.dart';

/// アプリケーション設定クラス
class AppConfig {
  // バックエンドを使用するかどうかのフラグ
  static bool get useBackend {
    final useBackendStr = dotenv.env['USE_BACKEND'] ?? 'false';
    return useBackendStr.toLowerCase() == 'true';
  }

  // バックエンドのURL
  static String get backendUrl {
    return dotenv.env['BACKEND_URL'] ?? 'http://localhost:8080';
  }

  // Gemini APIキー
  static String? get geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'];
  }

  // Google Client ID
  static String? get googleClientId {
    return dotenv.env['GOOGLE_CLIENT_ID'];
  }

  /// 設定情報をコンソールに出力（デバッグ用）
  static void printConfig() {
    print('=== アプリ設定 ===');
    print('USE_BACKEND: $useBackend');
    print('BACKEND_URL: $backendUrl');
    print('GEMINI_API_KEY: ${geminiApiKey != null ? "設定済み" : "未設定"}');
    print('GOOGLE_CLIENT_ID: ${googleClientId != null ? "設定済み" : "未設定"}');
    print('================');
  }
}
