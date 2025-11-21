import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'i_semantic_search_service.dart';
import 'japanese_bert_tokenizer.dart';

/// 日本語セマンティック検索サービス
/// Japanese Sentence-BERT モデルを使用してテキストをベクトル化し、
/// 類似度計算を行うサービス
class JapaneseSemanticSearchService implements ISemanticSearchService {
  Interpreter? _interpreter;
  JapaneseBertTokenizer? _tokenizer;
  bool _isInitialized = false;

  /// サービスが初期化済みかどうか
  @override
  bool get isInitialized => _isInitialized;

  /// モデルの初期化
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      // トークナイザーの初期化
      _tokenizer = JapaneseBertTokenizer();
      await _tokenizer!.initialize();
      
      // TFLiteモデルの初期化
      final options = InterpreterOptions();
      options.threads = 4;
      
      _interpreter = await Interpreter.fromAsset(
        'assets/models/sentence_bert_ja.tflite',
        options: options,
      );
      
      _isInitialized = true;
      print('✅ 日本語セマンティック検索: 初期化完了');
    } catch (e, stackTrace) {
      print('❌ 日本語セマンティック検索: 初期化失敗: $e');
      print('スタックトレース: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  /// リソースの解放
  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _tokenizer = null;
    _isInitialized = false;
  }

  /// モデルの入出力情報を取得（デバッグ用）
  @override
  void printModelInfo() {
    if (!_isInitialized || _interpreter == null) {
      print('JapaneseSemanticSearchService: モデルが初期化されていません');
      return;
    }

    print('=== モデル情報 ===');
    
    final inputTensors = _interpreter!.getInputTensors();
    print('入力テンソル数: ${inputTensors.length}');
    for (var i = 0; i < inputTensors.length; i++) {
      final tensor = inputTensors[i];
      print('  入力[$i]: shape=${tensor.shape}, type=${tensor.type}, name=${tensor.name}');
    }
    
    final outputTensors = _interpreter!.getOutputTensors();
    print('出力テンソル数: ${outputTensors.length}');
    for (var i = 0; i < outputTensors.length; i++) {
      final tensor = outputTensors[i];
      print('  出力[$i]: shape=${tensor.shape}, type=${tensor.type}, name=${tensor.name}');
    }
    
    print('================');
  }

  /// テキストをベクトルに変換
  /// 
  /// [text] エンコードするテキスト
  /// 戻り値: テキストのベクトル表現（768次元のFloat32List）
  @override
  Future<Float32List?> encodeText(String text) async {
    if (!_isInitialized || _interpreter == null || _tokenizer == null) {
      print('❌ セマンティック検索: 初期化されていません');
      return null;
    }

    if (text.trim().isEmpty) {
      print('⚠️  セマンティック検索: 空のテキスト');
      return null;
    }

    try {
      // テキストをトークン化
      final encoded = _tokenizer!.encode(text, maxLength: 128);
      final inputIds = encoded['input_ids']!;
      final attentionMask = encoded['attention_mask']!;
      
      // 入力テンソルの準備
      // TFLiteモデルの入力:
      // 入力[0]: attention_mask, shape: [1, 128]
      // 入力[1]: input_ids, shape: [1, 128]
      var inputs = <int, List<List<int>>>{
        0: [attentionMask],  // attention_mask
        1: [inputIds],       // input_ids
      };
      
      // 出力バッファの準備
      // 出力形状: [1, 768]
      var outputs = <int, List<List<double>>>{
        0: List.generate(1, (_) => List.filled(768, 0.0)),
      };
      
      // 推論実行
      _interpreter!.runForMultipleInputs(inputs.values.toList(), outputs);
      
      // 結果を Float32List として返す
      return Float32List.fromList(outputs[0]![0]);
    } catch (e, stackTrace) {
      print('❌ セマンティック検索エラー: $e');
      print('スタックトレース: $stackTrace');
      return null;
    }
  }

  /// 2つのベクトル間のコサイン類似度を計算
  @override
  double calculateCosineSimilarity(Float32List vector1, Float32List vector2) {
    if (vector1.length != vector2.length) {
      throw ArgumentError('ベクトルの次元数が一致しません');
    }

    double dotProduct = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
    }

    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }
    norm1 = math.sqrt(norm1);
    norm2 = math.sqrt(norm2);

    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    return dotProduct / (norm1 * norm2);
  }

  /// 検索キーワードとタスクテキストの類似度を計算
  /// 
  /// [searchKeyword] 検索キーワード
  /// [taskText] タスクのテキスト
  /// 戻り値: 類似度スコア（0.0 ~ 1.0）
  @override
  Future<double?> calculateSimilarity(
    String searchKeyword,
    String taskText,
  ) async {
    if (!_isInitialized) {
      return null;
    }

    try {
      final keywordVector = await encodeText(searchKeyword);
      final taskVector = await encodeText(taskText);

      if (keywordVector == null || taskVector == null) {
        return null;
      }

      final similarity = calculateCosineSimilarity(keywordVector, taskVector);
      
      // 0.0 ~ 1.0 の範囲に正規化
      return (similarity + 1.0) / 2.0;
    } catch (e) {
      print('JapaneseSemanticSearchService: 類似度計算に失敗しました: $e');
      return null;
    }
  }
}
