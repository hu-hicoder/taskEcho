import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:mediapipe_text/mediapipe_text.dart';
import 'package:mediapipe_core/mediapipe_core.dart';
import 'i_semantic_search_service.dart';

/// MediaPipe Text を使用したセマンティック検索サービス
/// 
/// 公式の mediapipe_text パッケージを使用してテキストの意味的埋め込みと
/// 類似度計算を行います。
class MediaPipeTextService implements ISemanticSearchService {
  TextEmbedder? _textEmbedder;
  bool _isInitialized = false;
  String? _modelPath;

  @override
  bool get isInitialized => _isInitialized;

  /// MediaPipe Text Embedder を初期化
  /// 
  /// [modelAssetPath] モデルファイルのパス（assets内の相対パス）
  /// デフォルトは Universal Sentence Encoder
  @override
  Future<void> initialize({
    String modelAssetPath = 'assets/models/universal_sentence_encoder.tflite',
  }) async {
    if (_isInitialized) {
      print('⚠️ MediaPipe Text Service is already initialized');
      return;
    }

    try {
      print('🚀 Initializing MediaPipe Text Service...');
      print('   Model: $modelAssetPath');

      // モデルファイルを読み込み
      final modelData = await rootBundle.load(modelAssetPath);
      final modelBytes = modelData.buffer.asUint8List();

      // TextEmbedder を作成
      final options = TextEmbedderOptions.fromAssetBuffer(
        modelBytes,
        embedderOptions: EmbedderOptions(
          l2Normalize: true,  // L2正規化を有効化
          quantize: false,    // 量子化を無効化（精度優先）
        ),
      );
      
      _textEmbedder = TextEmbedder(options);

      _modelPath = modelAssetPath;
      _isInitialized = true;

      print('✅ MediaPipe Text Service initialized successfully!');
      printModelInfo();
    } catch (e, stackTrace) {
      print('❌ Failed to initialize MediaPipe Text Service: $e');
      print('Stack trace: $stackTrace');
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
    if (!_isInitialized || _textEmbedder == null) {
      throw StateError(
        'MediaPipe Text Service is not initialized. Call initialize() first.'
      );
    }

    if (text.isEmpty) {
      print('⚠️ Warning: Empty text provided to encodeText');
      return null;
    }

    try {
      // テキストをエンベディング
      final result = await _textEmbedder!.embed(text);
      
      if (result.embeddings.isEmpty) {
        print('⚠️ No embeddings generated for text: $text');
        return null;
      }

      // 最初の埋め込みを取得
      final embedding = result.embeddings.first;
      
      // Float32List に変換
      if (embedding.floatEmbedding != null) {
        return Float32List.fromList(embedding.floatEmbedding!);
      } else if (embedding.quantizedEmbedding != null) {
        // 量子化された埋め込みをfloatに変換
        return Float32List.fromList(
          embedding.quantizedEmbedding!.map((e) => e.toDouble()).toList()
        );
      }

      print('⚠️ No valid embedding data');
      return null;
    } catch (e) {
      print('❌ Error encoding text: $e');
      return null;
    }
  }

  /// 2つのテキスト間の意味的類似度を計算
  /// 
  /// MediaPipe の cosineSimilarity を使用
  /// [text1] 最初のテキスト
  /// [text2] 2番目のテキスト
  /// 戻り値: コサイン類似度 (-1.0 ~ 1.0、1.0が最も類似)
  Future<double> calculateTextSimilarity(String text1, String text2) async {
    if (!_isInitialized || _textEmbedder == null) {
      throw StateError(
        'MediaPipe Text Service is not initialized. Call initialize() first.'
      );
    }

    try {
      // 両方のテキストをエンベディング
      final result1 = await _textEmbedder!.embed(text1);
      final result2 = await _textEmbedder!.embed(text2);

      if (result1.embeddings.isEmpty || result2.embeddings.isEmpty) {
        print('⚠️ Failed to generate embeddings for similarity calculation');
        return 0.0;
      }

      // コサイン類似度を計算（instance method）
      final similarity = await _textEmbedder!.cosineSimilarity(
        result1.embeddings.first,
        result2.embeddings.first,
      );

      return similarity;
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

  /// 平方根の計算
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

  /// モデル情報を出力（デバッグ用）
  @override
  void printModelInfo() {
    if (!_isInitialized) {
      print('MediaPipe Text Service is not initialized');
      return;
    }

    print('╔════════════════════════════════════════════════╗');
    print('║   MediaPipe Text Service                       ║');
    print('╠════════════════════════════════════════════════╣');
    print('║ Package: mediapipe_text (pub.dev)');
    print('║ Model: $_modelPath');
    print('║ Status: ${_isInitialized ? "Initialized ✅" : "Not Initialized ❌"}');
    print('╚════════════════════════════════════════════════╝');
  }

  /// リソースを解放
  @override
  void dispose() {
    if (_textEmbedder != null) {
      _textEmbedder = null;
      _isInitialized = false;
      _modelPath = null;
      print('✅ MediaPipe Text Service disposed');
    }
  }
}
