import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'i_semantic_search_service.dart';

/// Web用: Gemini API 直接利用版
/// Goサーバーを経由せず、Flutterから直接Gemini APIを叩いてベクトル化します。
class JapaneseSemanticSearchService implements ISemanticSearchService {
  GenerativeModel? _embeddingModel;
  
  // キャッシュ: 単語 -> ベクトル
  final Map<String, Float32List> _cache = {};
  
  bool _isInitialized = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. 環境変数の読み込み
      // Webでは .env ファイルの読み込みに失敗することがあるため、
      // --dart-define で渡された値を優先し、なければ .env を読みに行きます。
      String apiKey = const String.fromEnvironment('GEMINI_API_KEY');
      
      if (apiKey.isEmpty) {
        try {
          await dotenv.load(fileName: "assets/.env");
          apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
        } catch (e) {
          print('⚠️ .env load failed: $e');
        }
      }

      if (apiKey.isEmpty) {
        print('❌ Error: GEMINI_API_KEY is missing.');
        // キーがない場合は初期化失敗とするが、アプリをクラッシュさせないために
        // フォールバック（文字マッチング）のみで動作するようにする手もある
        return;
      }

      // 2. Geminiモデルの初期化 (Embedding専用モデル)
      _embeddingModel = GenerativeModel(
        model: 'gemini-embedding-001',
        apiKey: apiKey,
      );

      _isInitialized = true;
      print('✅ Web: Gemini API Direct Mode (Model: gemini-embedding-001)');
      
    } catch (e) {
      print('❌ Gemini API Initialization Error: $e');
    }
  }

  @override
  void dispose() {
    _cache.clear();
  }

  @override
  void printModelInfo() {
    print('Model: Gemini gemini-embedding-001 (Direct)');
  }

  @override
  Future<Float32List?> encodeText(String text) async {
    // 初期化されていない、またはモデルがない場合はnull
    if (!_isInitialized || _embeddingModel == null) {
      print('⚠️ Gemini API not initialized. Using fallback.');
      return null;
    }

    // 短すぎるテキストはスキップ
    if (text.trim().length < 2) return null;

    // キャッシュチェック
    if (_cache.containsKey(text)) {
      return _cache[text];
    }

    try {
      final content = Content.text(text);
      final result = await _embeddingModel!.embedContent(content);
      
      if (result.embedding.values.isEmpty) return null;

      // DoubleのリストをFloat32Listに変換
      final vector = Float32List.fromList(result.embedding.values.map((e) => e.toDouble()).toList());
      
      // キャッシュ保存
      if (_cache.length > 100) _cache.remove(_cache.keys.first);
      _cache[text] = vector;

      return vector;
    } catch (e) {
      print('⚠️ Gemini API Error: $e');
      return null;
    }
  }

  @override
  double calculateCosineSimilarity(Float32List vector1, Float32List vector2) {
    if (vector1.length != vector2.length) return 0.0;
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }
    norm1 = math.sqrt(norm1);
    norm2 = math.sqrt(norm2);
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    return dotProduct / (norm1 * norm2);
  }

  @override
  Future<double?> calculateSimilarity(String searchKeyword, String taskText) async {
    // 初期化待ち (念のため)
    if (!_isInitialized) await initialize();

    // 1. Gemini APIでベクトル化を試みる
    final v1 = await encodeText(searchKeyword);
    final v2 = await encodeText(taskText);
    
    if (v1 != null && v2 != null) {
      return (calculateCosineSimilarity(v1, v2) + 1.0) / 2.0;
    }

    // 2. 失敗時はローカルの文字マッチング (Bi-gram)
    return _calculateFallbackSimilarity(searchKeyword, taskText);
  }

  double _calculateFallbackSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final str1 = s1.replaceAll(RegExp(r'\s+'), '');
    final str2 = s2.replaceAll(RegExp(r'\s+'), '');
    if (str2.contains(str1)) return 1.0;

    Set<String> bigrams(String str) {
      final result = <String>{};
      for (int i = 0; i < str.length - 1; i++) {
        result.add(str.substring(i, i + 2));
      }
      return result;
    }

    final set1 = bigrams(str1);
    final set2 = bigrams(str2);

    if (set1.isEmpty || set2.isEmpty) return 0.0;

    final intersection = set1.intersection(set2).length;
    return (2.0 * intersection) / (set1.length + set2.length);
  }
}

// import 'dart:convert';
// import 'dart:typed_data';
// import 'dart:math' as math;
// import 'package:http/http.dart' as http;
// import 'package:firebase_auth/firebase_auth.dart'; // 認証用
// import 'i_semantic_search_service.dart';

// /// Web用: ハイブリッド検索版
// /// 通常はGoサーバー(AI)を使用し、接続できない場合はローカル(文字マッチング)に自動で切り替えます。
// class JapaneseSemanticSearchService implements ISemanticSearchService {
//   // GoバックエンドのURL
//   static const String backendUrl = String.fromEnvironment(
//     'BACKEND_URL',
//     defaultValue: 'http://127.0.0.1:8080',
//   );
//   final Uri _apiUrl = Uri.parse('$backendUrl/api/encode');
  
//   bool _isInitialized = false;

//   @override
//   bool get isInitialized => _isInitialized;

//   @override
//   Future<void> initialize() async {
//     _isInitialized = true;
//     print('✅ Web: ハイブリッド検索モード (優先: $_apiUrl, フォールバック: Bi-gram)');
//   }

//   @override
//   void dispose() {}

//   @override
//   void printModelInfo() {
//     print('Backend API: $_apiUrl');
//   }

//   @override
//   Future<Float32List?> encodeText(String text) async {
//     try {
//       // 認証トークンの取得 (ログインしている場合)
//       String? token;
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         token = await user.getIdToken();
//       }

//       final response = await http.post(
//         _apiUrl,
//         headers: {
//           'Content-Type': 'application/json',
//           if (token != null) 'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({'text': text}),
//       ).timeout(const Duration(seconds: 3)); // 3秒でタイムアウトさせる

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final List<dynamic> embedding = data['embedding'];
//         return Float32List.fromList(embedding.cast<double>());
//       } else {
//         // 404や500エラーの場合はログを控えめにする
//         if (response.statusCode != 404) {
//           print('⚠️ API Error: ${response.statusCode}');
//         }
//         return null;
//       }
//     } catch (e) {
//       // print('⚠️ バックエンド接続不可: $e (フォールバックを使用します)');
//       return null;
//     }
//   }

//   @override
//   double calculateCosineSimilarity(Float32List vector1, Float32List vector2) {
//     if (vector1.length != vector2.length) return 0.0;
//     double dotProduct = 0.0;
//     double norm1 = 0.0;
//     double norm2 = 0.0;
//     for (int i = 0; i < vector1.length; i++) {
//       dotProduct += vector1[i] * vector2[i];
//       norm1 += vector1[i] * vector1[i];
//       norm2 += vector2[i] * vector2[i];
//     }
//     norm1 = math.sqrt(norm1);
//     norm2 = math.sqrt(norm2);
//     if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
//     return dotProduct / (norm1 * norm2);
//   }

//   @override
//   Future<double?> calculateSimilarity(String searchKeyword, String taskText) async {
//     if (!_isInitialized) return null;
    
//     // 1. まずバックエンドでのベクトル化を試みる
//     final v1 = await encodeText(searchKeyword);
//     final v2 = await encodeText(taskText);
    
//     // 2. バックエンドが成功した場合
//     if (v1 != null && v2 != null) {
//       return (calculateCosineSimilarity(v1, v2) + 1.0) / 2.0;
//     }

//     // 3. バックエンドが失敗した場合、ローカルの簡易計算に切り替える
//     // 注意: ここでは「宿題」=「課題」のような意味検索はできませんが、文字の一致は検知できます。
//     return _calculateFallbackSimilarity(searchKeyword, taskText);
//   }

//   /// フォールバック用: Bi-gram (2文字ごとの分割) による類似度計算
//   /// サーバーが死んでいても、最低限のキーワードマッチングを提供します。
//   double _calculateFallbackSimilarity(String s1, String s2) {
//     if (s1.isEmpty || s2.isEmpty) return 0.0;
    
//     // 文字列を正規化（空白削除）
//     final str1 = s1.replaceAll(RegExp(r'\s+'), '');
//     final str2 = s2.replaceAll(RegExp(r'\s+'), '');

//     // 完全一致なら 1.0
//     if (str2.contains(str1)) return 1.0;

//     Set<String> bigrams(String str) {
//       final result = <String>{};
//       for (int i = 0; i < str.length - 1; i++) {
//         result.add(str.substring(i, i + 2));
//       }
//       return result;
//     }

//     final set1 = bigrams(str1);
//     final set2 = bigrams(str2);

//     if (set1.isEmpty || set2.isEmpty) return 0.0;

//     final intersection = set1.intersection(set2).length;
//     // Dice係数: 2 * (共通部分) / (全要素数)
//     return (2.0 * intersection) / (set1.length + set2.length);
//   }
// }