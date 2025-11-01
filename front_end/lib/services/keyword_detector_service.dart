import 'package:flutter_speech_to_text/services/i_semantic_search_service.dart';

/// キーワード検出結果
class KeywordDetection {
  final String keyword;
  final double similarity;
  final int startIndex;
  final int endIndex;
  final String matchedText;

  KeywordDetection({
    required this.keyword,
    required this.similarity,
    required this.startIndex,
    required this.endIndex,
    required this.matchedText,
  });

  Map<String, dynamic> toJson() {
    return {
      'keyword': keyword,
      'similarity': similarity,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'matchedText': matchedText,
    };
  }
}

/// セマンティック検索を使用したキーワード検出サービス
class KeywordDetectorService {
  final ISemanticSearchService _semanticSearchService;
  
  // キーワード検出の閾値（この値以上の類似度でキーワードとして検出）
  double _similarityThreshold = 0.7;
  
  // ウィンドウサイズ（テキストを分割する単位: 文字数）
  int _windowSize = 50;
  
  // スライディングウィンドウのステップサイズ
  int _stepSize = 25;

  KeywordDetectorService(this._semanticSearchService);

  /// 類似度の閾値を設定
  void setSimilarityThreshold(double threshold) {
    if (threshold < 0.0 || threshold > 1.0) {
      throw ArgumentError('閾値は0.0〜1.0の範囲で指定してください');
    }
    _similarityThreshold = threshold;
  }

  /// ウィンドウサイズを設定（文字数）
  void setWindowSize(int size) {
    if (size <= 0) {
      throw ArgumentError('ウィンドウサイズは正の値である必要があります');
    }
    _windowSize = size;
  }

  /// ステップサイズを設定
  void setStepSize(int size) {
    if (size <= 0) {
      throw ArgumentError('ステップサイズは正の値である必要があります');
    }
    _stepSize = size;
  }

  /// テキストから複数のキーワードをセマンティック検索で検出
  /// 
  /// [text] 検索対象のテキスト（音声認識結果など）
  /// [keywords] 検出したいキーワードのリスト
  /// 戻り値: 検出されたキーワードのリスト（類似度でソート済み）
  Future<List<KeywordDetection>> detectKeywords(
    String text,
    List<String> keywords,
  ) async {
    if (!_semanticSearchService.isInitialized) {
      return [];
    }

    if (text.trim().isEmpty || keywords.isEmpty) {
      return [];
    }

    final detections = <KeywordDetection>[];

    // 各キーワードについて検出を実行
    for (final keyword in keywords) {
      final keywordDetections = await _detectSingleKeyword(text, keyword);
      detections.addAll(keywordDetections);
    }

    // 類似度の高い順にソート
    detections.sort((a, b) => b.similarity.compareTo(a.similarity));

    return detections;
  }

  /// 単一のキーワードを検出（スライディングウィンドウ方式）
  Future<List<KeywordDetection>> _detectSingleKeyword(
    String text,
    String keyword,
  ) async {
    final detections = <KeywordDetection>[];

    // キーワードのベクトル化（一度だけ実行）
    final keywordVector = await _semanticSearchService.encodeText(keyword);
    if (keywordVector == null) {
      return [];
    }

    // スライディングウィンドウでテキストを分割
    final windows = _createSlidingWindows(text);

    for (final window in windows) {
      final windowVector = await _semanticSearchService.encodeText(window.text);
      if (windowVector == null) continue;

      final similarity = _semanticSearchService.calculateCosineSimilarity(
        keywordVector,
        windowVector,
      );

      // 類似度を0〜1の範囲に正規化
      final normalizedSimilarity = (similarity + 1.0) / 2.0;

      // 閾値以上の類似度があれば検出結果に追加
      if (normalizedSimilarity >= _similarityThreshold) {
        detections.add(KeywordDetection(
          keyword: keyword,
          similarity: normalizedSimilarity,
          startIndex: window.startIndex,
          endIndex: window.endIndex,
          matchedText: window.text,
        ));
      }
    }

    return detections;
  }

  /// テキストをスライディングウィンドウで分割
  List<_TextWindow> _createSlidingWindows(String text) {
    final windows = <_TextWindow>[];
    final textLength = text.length;

    for (int i = 0; i < textLength; i += _stepSize) {
      final endIndex = (i + _windowSize).clamp(0, textLength);
      final windowText = text.substring(i, endIndex);

      if (windowText.trim().isNotEmpty) {
        windows.add(_TextWindow(
          text: windowText,
          startIndex: i,
          endIndex: endIndex,
        ));
      }

      // 最後のウィンドウに達したら終了
      if (endIndex >= textLength) break;
    }

    return windows;
  }

  /// 完全一致検出も併用した高精度検出
  /// 
  /// セマンティック検索と完全一致の両方を使用して、
  /// より高精度なキーワード検出を行います
  Future<List<KeywordDetection>> detectKeywordsHybrid(
    String text,
    List<String> keywords,
  ) async {
    final detections = <KeywordDetection>[];

    // 1. 完全一致検出（高精度・高速）
    for (final keyword in keywords) {
      final exactMatches = _detectExactMatch(text, keyword);
      detections.addAll(exactMatches);
    }

    // 2. セマンティック検索（柔軟性・類義語対応）
    final semanticDetections = await detectKeywords(text, keywords);
    
    // 重複を除去（完全一致が優先）
    for (final semanticDetection in semanticDetections) {
      final isDuplicate = detections.any((exactDetection) =>
          exactDetection.keyword == semanticDetection.keyword &&
          _isOverlapping(exactDetection, semanticDetection));

      if (!isDuplicate) {
        detections.add(semanticDetection);
      }
    }

    // 類似度の高い順にソート
    detections.sort((a, b) => b.similarity.compareTo(a.similarity));

    return detections;
  }

  /// 完全一致でキーワードを検出
  List<KeywordDetection> _detectExactMatch(String text, String keyword) {
    final detections = <KeywordDetection>[];
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    int index = 0;
    while (index != -1) {
      index = lowerText.indexOf(lowerKeyword, index);
      if (index != -1) {
        detections.add(KeywordDetection(
          keyword: keyword,
          similarity: 1.0, // 完全一致なので類似度100%
          startIndex: index,
          endIndex: index + keyword.length,
          matchedText: text.substring(index, index + keyword.length),
        ));
        index += keyword.length;
      }
    }

    return detections;
  }

  /// 2つの検出結果が重複しているかチェック
  bool _isOverlapping(KeywordDetection a, KeywordDetection b) {
    return !(a.endIndex <= b.startIndex || b.endIndex <= a.startIndex);
  }
}

/// スライディングウィンドウの情報
class _TextWindow {
  final String text;
  final int startIndex;
  final int endIndex;

  _TextWindow({
    required this.text,
    required this.startIndex,
    required this.endIndex,
  });
}
