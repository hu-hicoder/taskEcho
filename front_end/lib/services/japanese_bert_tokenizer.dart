import 'package:flutter/services.dart';

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
