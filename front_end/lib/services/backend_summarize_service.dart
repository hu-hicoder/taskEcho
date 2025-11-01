import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/models.dart';

/// バックエンドAPIとの通信を管理するサービス
class BackendSummarizeService {
  
  /// バックエンドAPIを使用して要約を取得
  static Future<String?> summarize(String text, {String? keyword}) async {
    try {
      final url = Uri.parse('${AppConfig.backendUrl}/summarize');
      
      final request = SummarizeRequest(
        text: text,
        keyword: keyword,
      );
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final summarizeResponse = SummarizeResponse.fromJson(responseData);
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
}
