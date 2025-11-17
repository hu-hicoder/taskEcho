import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'i_semantic_search_service.dart';
import 'japanese_semantic_search_service.dart';

/// MediaPipe Text Embedder スタイルのシンプルなAPI
/// 内部的にはTFLiteを使用しますが、MediaPipeのような使いやすいインターフェースを提供
class MediaPipeStyleTextEmbedder implements ISemanticSearchService {
  JapaneseBertTokenizer? _tokenizer;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // モデル設定
  static const int MAX_SEQ_LENGTH = 128;
  static const int EMBEDDING_DIM = 768;
  static const String MODEL_PATH = 'assets/models/sentence_bert_ja.tflite';

  @override
  bool get isInitialized => _isInitialized;

  /// テキストエンベッダーの初期化
  /// MediaPipe風のシンプルな初期化メソッド
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      print('MediaPipeStyleTextEmbedder is already initialized');
      return;
    }

    try {
      print('Initializing MediaPipe-style Text Embedder...');

      // トークナイザーの初期化
      _tokenizer = JapaneseBertTokenizer();
      await _tokenizer!.initialize();
      print('✓ Tokenizer initialized');

      // TFLiteインタープリターの初期化
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      print('✓ Model loaded: $MODEL_PATH');

      // 入出力テンソルのサイズ確認
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('✓ Input shape: $inputShape');
      print('✓ Output shape: $outputShape');

      _isInitialized = true;
      print('MediaPipe-style Text Embedder initialized successfully!');
    } catch (e) {
      print('Error initializing MediaPipe-style Text Embedder: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// テキストをエンベディング（ベクトル化）
  /// 
  /// MediaPipe Text Embedder の embed() メソッドに相当
  /// [text] エンベディングするテキスト
  /// 戻り値: テキストのベクトル表現
  @override
  Future<Float32List?> encodeText(String text) async {
    if (!_isInitialized) {
      throw StateError(
          'MediaPipeStyleTextEmbedder is not initialized. Call initialize() first.');
    }

    if (text.isEmpty) {
      print('Warning: Empty text provided');
      return null;
    }

    try {
      // 1. テキストをトークン化してIDに変換
      final encoded = _tokenizer!.encode(text, maxLength: MAX_SEQ_LENGTH);
      final inputIds = encoded['input_ids']!;
      final attentionMask = encoded['attention_mask']!;

      // 2. 出力バッファの準備
      final output = List.generate(
        1,
        (_) => List.filled(EMBEDDING_DIM, 0.0),
      );

      // 3. 推論実行
      _interpreter!.runForMultipleInputs([inputIds, attentionMask], {0: output});

      // 6. Float32Listに変換して返す
      final embedding = Float32List(EMBEDDING_DIM);
      for (int i = 0; i < EMBEDDING_DIM; i++) {
        embedding[i] = output[0][i];
      }

      return embedding;
    } catch (e) {
      print('Error encoding text: $e');
      return null;
    }
  }

  /// 2つのテキスト間の類似度を計算
  /// 
  /// MediaPipe の CosineSimilarity に相当
  /// [text1] 最初のテキスト
  /// [text2] 2番目のテキスト
  /// 戻り値: 類似度スコア（0.0〜1.0）
  Future<double> calculateTextSimilarity(String text1, String text2) async {
    final embedding1 = await encodeText(text1);
    final embedding2 = await encodeText(text2);

    if (embedding1 == null || embedding2 == null) {
      return 0.0;
    }

    return calculateCosineSimilarity(embedding1, embedding2);
  }

  /// コサイン類似度の計算
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

    final similarity = dotProduct / (sqrt(norm1) * sqrt(norm2));
    
    // コサイン類似度を0〜1の範囲に正規化
    return (similarity + 1.0) / 2.0;
  }

  double sqrt(double x) => x < 0 ? 0 : x == 0 ? 0 : _sqrtHelper(x);

  double _sqrtHelper(double x) {
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

  /// 検索キーワードとタスクテキストの類似度を計算
  /// 
  /// MediaPipe の Search/Retrieval 機能に相当
  /// [searchKeyword] 検索キーワード
  /// [taskText] 検索対象のテキスト
  /// 戻り値: 類似度スコア（0.0〜1.0）
  @override
  Future<double?> calculateSimilarity(String searchKeyword, String taskText) async {
    return await calculateTextSimilarity(searchKeyword, taskText);
  }

  /// キーワード検索: 類似度が閾値以上かチェック
  /// 
  /// [keyword] 検索キーワード
  /// [taskText] 検索対象のテキスト
  /// [threshold] 類似度の閾値（デフォルト: 0.7）
  /// 戻り値: キーワードが見つかった場合はtrue
  Future<bool> searchSimilarText(
    String keyword,
    String taskText, {
    double threshold = 0.7,
  }) async {
    final similarity = await calculateTextSimilarity(keyword, taskText);
    return similarity >= threshold;
  }

  /// バッチ処理: 複数のテキストをまとめてエンベディング
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

  /// リソースの解放
  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _tokenizer = null;
    _isInitialized = false;
    print('MediaPipe-style Text Embedder disposed');
  }

  /// モデル情報を出力
  @override
  void printModelInfo() {
    if (!_isInitialized) {
      print('MediaPipe-style Text Embedder is not initialized');
      return;
    }

    print('=== MediaPipe-style Text Embedder Info ===');
    print('Model: sentence-bert-base-ja-mean-tokens-v2');
    print('Model Path: $MODEL_PATH');
    print('Max Sequence Length: $MAX_SEQ_LENGTH');
    print('Embedding Dimension: $EMBEDDING_DIM');
    
    if (_interpreter != null) {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      print('Input Shape: $inputShape');
      print('Output Shape: $outputShape');
    }
    
    print('Tokenizer: Japanese BERT Tokenizer');
    print('Initialized: $_isInitialized');
    print('=========================================');
  }
}
