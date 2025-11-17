import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'i_semantic_search_service.dart';

/// MediaPipe Text Embedder (ネイティブ実装)
/// 
/// Android と iOS のネイティブ MediaPipe Tasks Text API を使用して
/// テキストの意味的埋め込みと類似度計算を行います。
class MediaPipeTextEmbedder implements ISemanticSearchService {
  static const MethodChannel _channel = MethodChannel('mediapipe_text_embedder');
  
  bool _isInitialized = false;
  String? _modelPath;
  bool _quantize = false;

  @override
  bool get isInitialized => _isInitialized;

  /// MediaPipe Text Embedder を初期化
  /// 
  /// [modelPath] モデルファイルのパス（assets内、拡張子なし）
  /// [quantize] 量子化を使用するか（メモリ使用量削減、わずかに精度低下）
  @override
  Future<void> initialize({
    String modelPath = 'universal_sentence_encoder',
    bool quantize = false,
  }) async {
    if (_isInitialized) {
      print('⚠️ MediaPipe TextEmbedder is already initialized');
      return;
    }

    try {
      print('🚀 Initializing MediaPipe Text Embedder...');
      print('   Model: $modelPath');
      print('   Quantize: $quantize');

      final result = await _channel.invokeMethod('initialize', {
        'modelPath': modelPath,
        'quantize': quantize,
      });

      if (result is Map && result['success'] == true) {
        _isInitialized = true;
        _modelPath = modelPath;
        _quantize = quantize;
        print('✅ ${result['message']}');
      } else {
        throw Exception('Initialization failed: $result');
      }
    } on PlatformException catch (e) {
      print('❌ Platform Error: ${e.code} - ${e.message}');
      print('   Details: ${e.details}');
      _isInitialized = false;
      rethrow;
    } catch (e) {
      print('❌ Failed to initialize MediaPipe Text Embedder: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// テキストをベクトル埋め込みに変換
  /// 
  /// [text] エンコードするテキスト
  /// 戻り値: テキストのベクトル表現（Float32List）
  @override
  Future<Float32List?> encodeText(String text) async {
    if (!_isInitialized) {
      throw StateError(
        'MediaPipe TextEmbedder is not initialized. Call initialize() first.'
      );
    }

    if (text.isEmpty) {
      print('⚠️ Warning: Empty text provided to encodeText');
      return null;
    }

    try {
      final result = await _channel.invokeMethod('embed', {'text': text});
      
      if (result is List) {
        // List<dynamic> を Float32List に変換
        final floatList = result.map((e) => (e as num).toDouble()).toList();
        return Float32List.fromList(floatList);
      }
      
      print('⚠️ Unexpected result type from embed: ${result.runtimeType}');
      return null;
    } on PlatformException catch (e) {
      print('❌ Embed Error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ Error encoding text: $e');
      return null;
    }
  }

  /// 2つのテキスト間の意味的類似度を計算
  /// 
  /// [text1] 最初のテキスト
  /// [text2] 2番目のテキスト
  /// 戻り値: コサイン類似度 (-1.0 ~ 1.0、1.0が最も類似)
  Future<double> calculateTextSimilarity(String text1, String text2) async {
    if (!_isInitialized) {
      throw StateError(
        'MediaPipe TextEmbedder is not initialized. Call initialize() first.'
      );
    }

    try {
      final result = await _channel.invokeMethod('cosineSimilarity', {
        'text1': text1,
        'text2': text2,
      });
      
      return (result as num).toDouble();
    } on PlatformException catch (e) {
      print('❌ Similarity Error: ${e.code} - ${e.message}');
      return 0.0;
    } catch (e) {
      print('❌ Error calculating similarity: $e');
      return 0.0;
    }
  }

  /// ISemanticSearchService インターフェースの実装
  /// 
  /// [searchKeyword] 検索キーワード
  /// [taskText] 検索対象のテキスト
  /// 戻り値: 類似度スコア (0.0 ~ 1.0)
  @override
  Future<double?> calculateSimilarity(String searchKeyword, String taskText) async {
    final similarity = await calculateTextSimilarity(searchKeyword, taskText);
    // -1~1 の範囲を 0~1 に正規化
    return (similarity + 1.0) / 2.0;
  }

  /// 2つのベクトル間のコサイン類似度を計算（ローカル計算）
  /// 
  /// ネイティブ側で計算する方が効率的ですが、
  /// すでにベクトルを持っている場合はこちらを使用
  @override
  double calculateCosineSimilarity(Float32List vector1, Float32List vector2) {
    if (vector1.length != vector2.length) {
      throw ArgumentError('Vectors must have the same length');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (_sqrt(norm1) * _sqrt(norm2));
  }

  /// 平方根の計算（dart:math を使わずに実装）
  double _sqrt(double x) {
    if (x < 0) return 0;
    if (x == 0) return 0;
    
    double result = x / 2;
    double previous;
    int iterations = 0;
    const maxIterations = 50;

    do {
      previous = result;
      result = (result + x / result) / 2;
      iterations++;
    } while ((result - previous).abs() > 0.0001 && iterations < maxIterations);

    return result;
  }

  /// バッチ処理: 複数のテキストを一度にエンベディング
  /// 
  /// [texts] エンベディングするテキストのリスト
  /// 戻り値: 各テキストのベクトル表現のリスト
  Future<List<Float32List?>> embedBatch(List<String> texts) async {
    final results = <Float32List?>[];
    
    for (final text in texts) {
      final embedding = await encodeText(text);
      results.add(embedding);
    }
    
    return results;
  }

  /// キーワード検索: 閾値ベースの類似度判定
  /// 
  /// [keyword] 検索キーワード
  /// [text] 検索対象のテキスト
  /// [threshold] 類似度の閾値（デフォルト: 0.7）
  /// 戻り値: 閾値以上の類似度がある場合は true
  Future<bool> searchSimilarText(
    String keyword,
    String text, {
    double threshold = 0.7,
  }) async {
    final similarity = await calculateTextSimilarity(keyword, text);
    // -1~1 の範囲を 0~1 に正規化
    final normalizedSimilarity = (similarity + 1.0) / 2.0;
    return normalizedSimilarity >= threshold;
  }

  /// モデル情報を取得
  Future<Map<String, dynamic>?> getModelInfo() async {
    if (!_isInitialized) {
      print('⚠️ MediaPipe TextEmbedder is not initialized');
      return null;
    }

    try {
      final result = await _channel.invokeMethod('getModelInfo');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (e) {
      print('❌ Error getting model info: $e');
      return null;
    }
  }

  /// モデル情報を出力（デバッグ用）
  @override
  void printModelInfo() {
    if (!_isInitialized) {
      print('MediaPipe TextEmbedder is not initialized');
      return;
    }

    print('╔════════════════════════════════════════════════╗');
    print('║   MediaPipe Text Embedder (Native)            ║');
    print('╠════════════════════════════════════════════════╣');
    print('║ Model: $_modelPath');
    print('║ Quantize: $_quantize');
    print('║ Status: ${_isInitialized ? "Initialized ✅" : "Not Initialized ❌"}');
    print('╚════════════════════════════════════════════════╝');

    // ネイティブ側の情報を取得して表示
    getModelInfo().then((info) {
      if (info != null) {
        print('Platform: ${info['platform']}');
        print('MediaPipe Version: ${info['mediapipe_version']}');
      }
    });
  }

  /// リソースを解放
  @override
  void dispose() {
    if (!_isInitialized) {
      return;
    }

    try {
      _channel.invokeMethod('dispose');
      _isInitialized = false;
      _modelPath = null;
      print('✅ MediaPipe TextEmbedder disposed');
    } catch (e) {
      print('❌ Error disposing MediaPipe TextEmbedder: $e');
    }
  }
}
