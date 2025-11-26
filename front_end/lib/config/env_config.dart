import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // --dart-defineで指定された値を優先、なければ.envから取得
  static String get geminiApiKey {
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    // フォールバック: .envから取得
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }
  
  static String get googleClientId {
    const fromDefine = String.fromEnvironment('GOOGLE_CLIENT_ID');
    if (fromDefine.isNotEmpty) return fromDefine;
    
    // フォールバック: .envから取得
    return dotenv.env['GOOGLE_CLIENT_ID'] ?? '';
  }
  
  static bool get isConfigured {
    return geminiApiKey.isNotEmpty && googleClientId.isNotEmpty;
  }
}