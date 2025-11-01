import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'i_semantic_search_service.dart';

/// 日本語BERT Tokenizerの実装
/// sonoisa/sentence-bert-base-ja-mean-tokens-v2 用のトークナイザー
class JapaneseBertTokenizer {
  Map<String, int>? _vocab;
  Map<int, String>? _reverseVocab;
  
  // Special tokens
  static const String CLS_TOKEN = '[CLS]';
  static const String SEP_TOKEN = '[SEP]';
  static const String PAD_TOKEN = '[PAD]';
  static const String UNK_TOKEN = '[UNK]';
  
  int? _clsTokenId;
  int? _sepTokenId;
  int? _padTokenId;
  int? _unkTokenId;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// トークナイザーの初期化
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    
    try {
      // vocab.txt の読み込み
      final vocabString = await rootBundle.loadString(
        'assets/tokenizer/sentence_bert_ja/vocab.txt',
      );
      
      // 語彙マップの構築
      _vocab = {};
      _reverseVocab = {};
      
      final lines = vocabString.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab![token] = i;
          _reverseVocab![i] = token;
        }
      }
      
      // Special token IDs を取得
      _clsTokenId = _vocab![CLS_TOKEN];
      _sepTokenId = _vocab![SEP_TOKEN];
      _padTokenId = _vocab![PAD_TOKEN];
      _unkTokenId = _vocab![UNK_TOKEN];
      
      _isInitialized = true;
      print('✅ 日本語トークナイザー初期化完了 (語彙: ${_vocab!.length}語)');
    } catch (e, stackTrace) {
      print('❌ トークナイザー初期化失敗: $e');
      print('スタックトレース: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// テキストをトークン化
  List<String> tokenize(String text) {
    if (!_isInitialized || _vocab == null) {
      throw StateError('トークナイザーが初期化されていません');
    }
    
    final tokens = <String>[];
    
    // 基本的な前処理（trimのみ、小文字化はしない）
    text = text.trim();
    
    // 文字単位でトークン化（簡易版）
    // 本来は MeCab や形態素解析が必要ですが、まずは文字・単語単位で実装
    final words = _splitIntoWords(text);
    
    for (final word in words) {
      // WordPiece トークン化
      final wordTokens = _tokenizeWord(word);
      tokens.addAll(wordTokens);
    }
    
    return tokens;
  }
  
  /// テキストをトークンIDのリストに変換
  /// 
  /// [text] 入力テキスト
  /// [maxLength] 最大シーケンス長（デフォルト: 128）
  /// [padding] パディングを行うか（デフォルト: true）
  /// [truncation] 切り詰めを行うか（デフォルト: true）
  Map<String, List<int>> encode(
    String text, {
    int maxLength = 128,
    bool padding = true,
    bool truncation = true,
  }) {
    if (!_isInitialized) {
      throw StateError('Tokenizer is not initialized');
    }
    
    // テキストをトークン化
    final tokens = tokenize(text);
    
    // トークンIDに変換
    final tokenIds = <int>[_clsTokenId!];
    for (final token in tokens) {
      final id = _vocab![token] ?? _unkTokenId!;
      tokenIds.add(id);
    }
    tokenIds.add(_sepTokenId!);
    
    // Truncation
    if (truncation && tokenIds.length > maxLength) {
      tokenIds.length = maxLength - 1;
      tokenIds.add(_sepTokenId!);
    }
    
    // Attention mask を作成（growableリストとして作成）
    final attentionMask = List<int>.generate(tokenIds.length, (_) => 1, growable: true);
    
    // Padding
    if (padding) {
      while (tokenIds.length < maxLength) {
        tokenIds.add(_padTokenId!);
        attentionMask.add(0);
      }
    }
    
    return {
      'input_ids': tokenIds,
      'attention_mask': attentionMask,
    };
  }
  
  /// 単語をWordPieceトークンに分割
  List<String> _tokenizeWord(String word) {
    // 単語全体がvocabに存在するか確認
    if (_vocab!.containsKey(word)) {
      return [word];
    }
    
    final tokens = <String>[];
    
    // Unicodeコードポイント単位で処理するためRunesを使用
    final runes = word.runes.toList();
    int start = 0;
    
    while (start < runes.length) {
      int end = runes.length;
      String? subToken;
      
      // 最長一致でサブワードを見つける
      while (start < end && subToken == null) {
        // Runesから文字列を再構築
        final substr = String.fromCharCodes(runes.sublist(start, end));
        final candidate = start > 0 ? '##$substr' : substr;
        
        if (_vocab!.containsKey(candidate)) {
          subToken = candidate;
          break;
        }
        end--;
      }
      
      if (subToken == null) {
        // 見つからない場合は1文字進めてUNKトークンを追加
        tokens.add(UNK_TOKEN);
        start++;
      } else {
        tokens.add(subToken);
        start = end;
      }
    }
    
    return tokens;
  }
  
  /// テキストを単語に分割
  /// 簡易版: スペース、句読点で分割
  List<String> _splitIntoWords(String text) {
    final words = <String>[];
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      // スペース、句読点で分割
      if (char == ' ' || 
          char == '、' || 
          char == '。' || 
          char == '，' || 
          char == '．' ||
          char == '!' ||
          char == '?' ||
          char == '；' ||
          char == '：') {
        if (buffer.isNotEmpty) {
          words.add(buffer.toString());
          buffer.clear();
        }
        // 句読点自体も追加
        if (char != ' ') {
          words.add(char);
        }
      } else {
        buffer.write(char);
      }
    }
    
    if (buffer.isNotEmpty) {
      words.add(buffer.toString());
    }
    
    return words;
  }
}

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
