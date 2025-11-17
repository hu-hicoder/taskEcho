import 'dart:io';
import 'package:flutter_gemma_embedder/flutter_gemma_embedder.dart';
import 'package:path_provider/path_provider.dart';
import 'i_semantic_search_service.dart';

/// EmbeddingGemma を使用したセマンティック検索サービス
/// 
/// Google の EmbeddingGemma 300M モデルを使用して、
/// オンデバイスでテキストエンベディングを生成します。
class GemmaEmbedderService implements ISemanticSearchService {
  EmbeddingModel? _model;
  bool _isInitialized = false;

  // モデルの設定
  static const String MODEL_FILENAME = 'embeddinggemma-300M_seq512_mixed-precision.tflite';
  static const int EMBEDDING_DIMENSIONS = 768;
  static const EmbeddingModelType MODEL_TYPE = EmbeddingModelType.embeddingGemma300M;
  static const EmbeddingTaskType TASK_TYPE = EmbeddingTaskType.retrieval;
  static const PreferredBackend BACKEND = PreferredBackend.gpu;

  @override
  bool get isInitialized => _isInitialized;

  /// EmbeddingGemma モデルを初期化
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ GemmaEmbedder is already initialized');
      return;
    }

    try {
      print('🚀 Initializing EmbeddingGemma...');

      // モデルのパスを取得
      final modelPath = await _getModelPath();
      
      // モデルファイルの存在確認
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file not found at: $modelPath\n'
            'Please download the EmbeddingGemma model first.');
      }

      print('✓ Model file found: $modelPath');
      final fileSize = await modelFile.length();
      print('✓ Model size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // FlutterGemmaEmbedder インスタンスを取得
      final embedder = FlutterGemmaEmbedder.instance;

      // モデルを作成
      _model = await embedder.createModel(
        modelPath: modelPath,
        modelType: MODEL_TYPE,
        dimensions: EMBEDDING_DIMENSIONS,
        taskType: TASK_TYPE,
        backend: BACKEND,
      );
      print('✓ EmbeddingModel created');

      // モデルを初期化
      await _model!.initialize();
      print('✓ Model initialized');

      _isInitialized = true;
      print('✅ EmbeddingGemma initialized successfully!');
      print('   - Model: EmbeddingGemma 300M (seq512)');
      print('   - Dimensions: $EMBEDDING_DIMENSIONS');
      print('   - Backend: ${BACKEND == PreferredBackend.gpu ? "GPU" : "CPU"}');
      print('   - Task: Retrieval (Semantic Search)');
    } catch (e, stackTrace) {
      print('❌ Error initializing EmbeddingGemma: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  /// モデルファイルのパスを取得
  Future<String> _getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$MODEL_FILENAME';
  }

  /// テキストをエンベディングに変換
  @override
  Future<List<double>> embed(String text) async {
    if (!_isInitialized || _model == null) {
      throw Exception('GemmaEmbedder not initialized. Call initialize() first.');
    }

    if (text.isEmpty) {
      throw ArgumentError('Text cannot be empty');
    }

    try {
      // EmbeddingGemma は自動的にタスク用のプロンプトを追加します
      // "Represent this sentence for searching relevant passages: {text}"
      final embedding = await _model!.encode(text);
      
      if (embedding.isEmpty) {
        throw Exception('Failed to generate embedding: empty result');
      }

      return embedding;
    } catch (e) {
      print('❌ Error embedding text: $e');
      rethrow;
    }
  }

  /// 複数のテキストを一括でエンベディングに変換
  Future<List<List<double>>> batchEmbed(List<String> texts) async {
    if (!_isInitialized || _model == null) {
      throw Exception('GemmaEmbedder not initialized. Call initialize() first.');
    }

    if (texts.isEmpty) {
      throw ArgumentError('Texts list cannot be empty');
    }

    try {
      final embeddings = await _model!.batchEncode(texts);
      return embeddings;
    } catch (e) {
      print('❌ Error batch embedding texts: $e');
      rethrow;
    }
  }

  /// 2つのテキストのコサイン類似度を計算
  @override
  Future<double> calculateSimilarity(String text1, String text2) async {
    if (!_isInitialized || _model == null) {
      throw Exception('GemmaEmbedder not initialized. Call initialize() first.');
    }

    try {
      // 両方のテキストをエンベディングに変換
      final embedding1 = await embed(text1);
      final embedding2 = await embed(text2);

      // コサイン類似度を計算
      final similarity = _model!.cosineSimilarity(embedding1, embedding2);
      
      return similarity;
    } catch (e) {
      print('❌ Error calculating similarity: $e');
      rethrow;
    }
  }

  /// キーワードリストとテキストの類似度を計算
  /// 最も類似度が高いキーワードとのスコアを返す
  @override
  Future<double> calculateKeywordSimilarity(
    String text,
    List<String> keywords,
  ) async {
    if (keywords.isEmpty) {
      return 0.0;
    }

    try {
      // テキストのエンベディングを生成
      final textEmbedding = await embed(text);

      // 各キーワードとの類似度を計算
      double maxSimilarity = 0.0;
      for (final keyword in keywords) {
        final keywordEmbedding = await embed(keyword);
        final similarity = _model!.cosineSimilarity(textEmbedding, keywordEmbedding);
        
        if (similarity > maxSimilarity) {
          maxSimilarity = similarity;
        }
      }

      return maxSimilarity;
    } catch (e) {
      print('❌ Error calculating keyword similarity: $e');
      return 0.0;
    }
  }

  /// リソースを解放
  @override
  Future<void> dispose() async {
    try {
      _model?.dispose();
      _model = null;
      _isInitialized = false;
      print('✅ GemmaEmbedder disposed');
    } catch (e) {
      print('❌ Error disposing GemmaEmbedder: $e');
    }
  }

  /// モデル情報を取得
  Future<Map<String, dynamic>> getModelInfo() async {
    return {
      'initialized': _isInitialized,
      'modelType': 'EmbeddingGemma 300M',
      'sequenceLength': 512,
      'dimensions': EMBEDDING_DIMENSIONS,
      'backend': BACKEND == PreferredBackend.gpu ? 'GPU' : 'CPU',
      'taskType': 'Retrieval',
      'modelFile': MODEL_FILENAME,
    };
  }
}
