import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'i_semantic_search_service.dart';

/// セマンティック検索サービス
/// Universal Sentence Encoderモデルを使用してテキストをベクトル化し、
/// 類似度計算を行うサービス
class SemanticSearchService implements ISemanticSearchService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  /// サービスが初期化済みかどうか
  @override
  bool get isInitialized => _isInitialized;

  /// モデルの初期化
  /// アプリ起動時に一度だけ呼び出す
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      print('SemanticSearchService: モデルの初期化を開始します...');
      
      // InterpreterOptions を設定
      // SELECT_TF_OPS を使用するための設定
      final options = InterpreterOptions();
      
      // スレッド数を設定
      options.threads = 4;
      
      // Flex Delegate を追加（SELECT_TF_OPS のため）
      // Android で SentencePiece オペレーションを使用可能にします
      try {
        // Note: tflite_flutter パッケージが自動的に Flex delegate を
        // ロードしますが、明示的に指定することも可能です
        print('SemanticSearchService: Flex delegate を有効化します');
      } catch (e) {
        print('SemanticSearchService: Flex delegate の設定中に警告: $e');
      }
      
      print('SemanticSearchService: モデルファイルを読み込み中...');
      
      // モデルファイルのロード
      _interpreter = await Interpreter.fromAsset(
        'assets/models/universal_sentence_encoder_multilingual.tflite',
        options: options,
      );
      
      print('SemanticSearchService: インタプリタの作成に成功しました');
      
      // モデル情報を表示（デバッグ用）
      printModelInfo();
      
      _isInitialized = true;
      print('SemanticSearchService: モデルの初期化に成功しました');
    } catch (e, stackTrace) {
      print('SemanticSearchService: モデルの初期化に失敗しました: $e');
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
    _isInitialized = false;
  }

  /// モデルの入出力情報を取得（デバッグ用）
  @override
  void printModelInfo() {
    if (!_isInitialized || _interpreter == null) {
      print('SemanticSearchService: モデルが初期化されていません');
      return;
    }

    print('=== モデル情報 ===');
    
    // 入力テンソルの情報
    final inputTensors = _interpreter!.getInputTensors();
    print('入力テンソル数: ${inputTensors.length}');
    for (var i = 0; i < inputTensors.length; i++) {
      final tensor = inputTensors[i];
      print('  入力[$i]: shape=${tensor.shape}, type=${tensor.type}, name=${tensor.name}');
    }
    
    // 出力テンソルの情報
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
  /// 戻り値: テキストのベクトル表現（Float32List）
  @override
  Future<Float32List?> encodeText(String text) async {
    if (!_isInitialized || _interpreter == null) {
      print('SemanticSearchService: モデルが初期化されていません');
      return null;
    }

    if (text.trim().isEmpty) {
      print('SemanticSearchService: 空のテキストはエンコードできません');
      return null;
    }

    try {
      // 入力の準備
      // Universal Sentence Encoder は文字列を直接受け取ります
      // 入力形状: [1] (1つの文字列)
      var input = [text];
      
      // 出力バッファの準備
      // 出力形状: [1, 512] (512次元のベクトル)
      var output = List.filled(1 * 512, 0.0).reshape([1, 512]);
      
      // 推論実行
      _interpreter!.run(input, output);
      
      // 結果を Float32List として返す
      // output[0] は List<double> なので、Float32List に変換
      return Float32List.fromList(output[0].cast<double>());
    } catch (e) {
      print('SemanticSearchService: テキストのエンコードに失敗しました: $e');
      return null;
    }
  }

  /// 2つのベクトル間のコサイン類似度を計算
  /// 
  /// [vector1] 最初のベクトル
  /// [vector2] 2番目のベクトル
  /// 戻り値: 類似度スコア（-1.0 ~ 1.0、1.0が最も類似）
  @override
  double calculateCosineSimilarity(Float32List vector1, Float32List vector2) {
    if (vector1.length != vector2.length) {
      throw ArgumentError('ベクトルの次元数が一致しません');
    }

    // ドット積の計算
    double dotProduct = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      dotProduct += vector1[i] * vector2[i];
    }

    // ベクトルのノルム（大きさ）を計算
    double norm1 = 0.0;
    double norm2 = 0.0;
    for (int i = 0; i < vector1.length; i++) {
      norm1 += vector1[i] * vector1[i];
      norm2 += vector2[i] * vector2[i];
    }
    norm1 = math.sqrt(norm1);
    norm2 = math.sqrt(norm2);

    // ゼロ除算を防ぐ
    if (norm1 == 0.0 || norm2 == 0.0) {
      return 0.0;
    }

    // コサイン類似度を計算
    return dotProduct / (norm1 * norm2);
  }

  /// 検索キーワードとタスクテキストの類似度を計算
  /// 
  /// [searchKeyword] 検索キーワード
  /// [taskText] タスクのテキスト（タイトル、説明など）
  /// 戻り値: 類似度スコア（0.0 ~ 1.0）、エラー時はnull
  @override
  Future<double?> calculateSimilarity(
    String searchKeyword,
    String taskText,
  ) async {
    if (!_isInitialized) {
      return null;
    }

    try {
      // 両方のテキストをエンコード
      final keywordVector = await encodeText(searchKeyword);
      final taskVector = await encodeText(taskText);

      if (keywordVector == null || taskVector == null) {
        return null;
      }

      // 類似度を計算
      final similarity = calculateCosineSimilarity(keywordVector, taskVector);
      
      // 0.0 ~ 1.0 の範囲に正規化（コサイン類似度は-1~1なので）
      return (similarity + 1.0) / 2.0;
    } catch (e) {
      print('SemanticSearchService: 類似度計算に失敗しました: $e');
      return null;
    }
  }
}
