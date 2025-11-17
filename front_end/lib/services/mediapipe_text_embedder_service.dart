import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'i_semantic_search_service.dart';

/// MediaPipe Text Embedder を使用したセマンティック検索サービス
/// 
/// 本物の MediaPipe を使用した実装です。
class MediaPipeTextEmbedderService implements ISemanticSearchService {
  TextEmbedder? _embedder;
  bool _isInitialized = false;

  static const String MODEL_PATH = 'assets/models/universal_sentence_encoder.tflite';

  @override
  bool get isInitialized => _isInitialized;

  /// MediaPipe Text Embedder を初期化
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      print('MediaPipe Text Embedder is already initialized');
      return;
    }

    try {
      print('🚀 Initializing MediaPipe Text Embedder...');

      // モデルをメモリに読み込む
      final ByteData modelBytes = await rootBundle.load(MODEL_PATH);
      print('✓ Model loaded: $MODEL_PATH (${modelBytes.lengthInBytes} bytes)');

      // TextEmbedder のオプションを設定
      final options = TextEmbedderOptions.fromAssetBuffer(
        modelBytes.buffer.asUint8List(),
      );

      // TextEmbedder を作成
      _embedder = TextEmbedder(options);
      print('✓ TextEmbedder created');

      _isInitialized = true;
      print('✅ MediaPipe Text Embedder initialized successfully!');
    } catch (e, stackTrace) {
      print('❌ Error initializing MediaPipe Text Embedder: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  /// テキストをベクトルに変換（エンベディング）
  /// 
  /// [text] エンコードするテキスト
  /// 戻り値: テキストのベクトル表現
  @override
  Future<Float32List?> encodeText(String text) async {
    if (!_isInitialized || _embedder == null) {
      throw StateError(
          'MediaPipe Text Embedder is not initialized. Call initialize() first.');
    }

    if (text.isEmpty) {
      print('Warning: Empty text provided');
      return null;
    }

    try {
      // MediaPipe でテキストをエンベディング
      final result = await _embedder!.embed(text);

      if (result.embeddings.isEmpty) {
        print('Warning: No embeddings generated');
        return null;
      }

      // 最初のエンベディングを取得
      final embedding = result.embeddings.first;
      
      // Float32List に変換
      final floatEmbedding = embedding.floatEmbedding;
      if (floatEmbedding == null) {
        print('Warning: Float embedding is null');
        return null;
      }
      
      final floatList = Float32List.fromList(
        floatEmbedding.map((e) => e.toDouble()).toList(),
      );

      return floatList;
    } catch (e) {
      print('Error encoding text: $e');
      return null;
    }
  }

  /// 2つのテキスト間の意味的類似度を計算
  /// 
  /// [searchKeyword] 検索キーワード
  /// [taskText] 検索対象のテキスト
  /// 戻り値: 類似度スコア（0.0〜1.0）
  @override
  Future<double?> calculateSimilarity(
      String searchKeyword, String taskText) async {
    if (!_isInitialized || _embedder == null) {
      throw StateError('MediaPipe Text Embedder is not initialized');
    }

    try {
      // 両方のテキストをエンベディング
      final result1 = await _embedder!.embed(searchKeyword);
      final result2 = await _embedder!.embed(taskText);

      if (result1.embeddings.isEmpty || result2.embeddings.isEmpty) {
        return null;
      }

      // MediaPipe の組み込みコサイン類似度関数を使用
      final similarityValue = await _embedder!.cosineSimilarity(
        result1.embeddings.first,
        result2.embeddings.first,
      );

      // -1.0〜1.0 の範囲を 0.0〜1.0 に正規化
      return (similarityValue + 1.0) / 2.0;
    } catch (e) {
      print('Error calculating similarity: $e');
      return null;
    }
  }

  /// 2つのベクトル間のコサイン類似度を計算
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

    final similarity = dotProduct / (_sqrt(norm1) * _sqrt(norm2));
    
    // -1.0〜1.0 の範囲を 0.0〜1.0 に正規化
    return (similarity + 1.0) / 2.0;
  }

  /// 平方根の計算（ニュートン法）
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

  /// キーワード検索: 類似度が閾値以上かチェック
  /// 
  /// [keyword] 検索キーワード
  /// [taskText] 検索対象のテキスト
  /// [threshold] 類似度の閾値（デフォルト: 0.7）
  /// 戻り値: キーワードが見つかった場合は true
  Future<bool> searchSimilarText(
    String keyword,
    String taskText, {
    double threshold = 0.7,
  }) async {
    final similarity = await calculateSimilarity(keyword, taskText);
    return similarity != null && similarity >= threshold;
  }

  /// バッチ処理: 複数のテキストをまとめてエンベディング
  Future<List<Float32List?>> embedBatch(List<String> texts) async {
    final results = <Float32List?>[];

    for (final text in texts) {
      final embedding = await encodeText(text);
      results.add(embedding);
    }

    return results;
  }

  /// モデル情報を出力
  @override
  void printModelInfo() {
    if (!_isInitialized) {
      print('MediaPipe Text Embedder is not initialized');
      return;
    }

    print('=== MediaPipe Text Embedder Info ===');
    print('Model: Universal Sentence Encoder');
    print('Model Path: $MODEL_PATH');
    print('Framework: Google MediaPipe');
    print('Initialized: $_isInitialized');
    print('Multi-language Support: Yes');
    print('=====================================');
  }

  /// リソースを解放
  @override
  void dispose() {
    // MediaPipe TextEmbedder には close メソッドがないため、null に設定するのみ
    _embedder = null;
    _isInitialized = false;
    print('MediaPipe Text Embedder disposed');
  }
}
