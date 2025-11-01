import '../config/app_config.dart';
import 'backend_summarize_service.dart';
import 'frontend_summarize_service.dart';

/// 要約サービスのファクトリークラス
/// 設定に応じてバックエンドまたはフロントエンドのサービスを使用
class SummarizeServiceFactory {
  
  /// 設定に応じて適切な要約サービスを使用してテキストを要約
  static Future<String?> summarize(String text, {String? keyword}) async {
    // 設定情報をログ出力
    AppConfig.printConfig();
    
    if (AppConfig.useBackend) {
      print('バックエンドAPIを使用して要約します');
      return await BackendSummarizeService.summarize(text, keyword: keyword);
    } else {
      print('フロントエンドでGemini APIを直接使用して要約します');
      return await FrontendSummarizeService.summarize(text, keyword: keyword);
    }
  }
}
