import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../services/i_semantic_search_service.dart';
import '../services/semantic_search_service.dart';
import '../services/japanese_semantic_search_service.dart';
import '../services/keyword_detector_service.dart';

class KeywordProvider with ChangeNotifier {
  List<String> _keywords = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // セマンティック検索サービス（インターフェース型）
  ISemanticSearchService? _semanticSearchService;
  late final KeywordDetectorService _keywordDetectorService;
  
  // 使用するモデルのタイプ: 'multilingual' (多言語), 'japanese' (日本語専用)
  String _modelType = 'japanese'; // デフォルトは日本語専用
  
  // 検出モード: 'exact'（完全一致）, 'semantic'（セマンティック検索）, 'hybrid'（両方）
  String _detectionMode = 'hybrid';
  
  // セマンティック検索の類似度閾値（0.0〜1.0）
  double _similarityThreshold = 0.7;

  List<String> get keywords => _keywords;
  bool get isSemanticSearchInitialized => _semanticSearchService?.isInitialized ?? false;
  String get detectionMode => _detectionMode;
  double get similarityThreshold => _similarityThreshold;
  String get modelType => _modelType;

  KeywordProvider() {
    loadKeywords();
    _initializeWithFallback();
  }
  
  /// モデルタイプを設定
  /// 
  /// [type] 'multilingual' または 'japanese'
  void setModelType(String type) {
    if (type != 'multilingual' && type != 'japanese') {
      throw ArgumentError('モデルタイプは "multilingual" または "japanese" である必要があります');
    }
    if (_modelType != type) {
      _modelType = type;
      // モデルを切り替える場合は再初期化が必要
      _semanticSearchService?.dispose();
      _semanticSearchService = null;
      _initializeWithFallback();
      notifyListeners();
    }
  }
  
  /// セマンティック検索サービスを初期化（フォールバック付き）
  Future<void> _initializeWithFallback() async {
    try {
      // モデルタイプに応じてサービスを作成
      if (_modelType == 'japanese') {
        print('🔧 日本語専用モデルを使用');
        _semanticSearchService = JapaneseSemanticSearchService();
      } else {
        print('🔧 多言語モデルを使用');
        _semanticSearchService = SemanticSearchService();
      }
      
      // KeywordDetectorServiceを初期化
      _keywordDetectorService = KeywordDetectorService(_semanticSearchService!);
      
      await _semanticSearchService!.initialize();
      notifyListeners();
    } catch (e) {
      print('⚠️  セマンティック検索初期化失敗、完全一致モードに切り替え: $e');
      _detectionMode = 'exact'; // 自動的に完全一致モードに切り替え
      notifyListeners();
    }
  }
  
  /// セマンティック検索サービスを初期化
  Future<void> initializeSemanticSearch() async {
    await _initializeWithFallback();
  }
  
  /// 検出モードを設定
  void setDetectionMode(String mode) {
    if (!['exact', 'semantic', 'hybrid'].contains(mode)) {
      throw ArgumentError('無効な検出モード: $mode');
    }
    _detectionMode = mode;
    notifyListeners();
  }
  
  /// 類似度閾値を設定
  void setSimilarityThreshold(double threshold) {
    _similarityThreshold = threshold;
    _keywordDetectorService.setSimilarityThreshold(threshold);
    notifyListeners();
  }

  // キーワードを追加するメソッド
  Future<void> addKeyword(String keyword) async {
    if (!_keywords.contains(keyword)) {
      _keywords.add(keyword);
      await saveKeywords(_keywords);
    }
  }

  // キーワードを削除するメソッド
  Future<void> removeKeyword(int index) async {
    if (index >= 0 && index < _keywords.length) {
      _keywords.removeAt(index);
      await saveKeywords(_keywords);
    }
  }

  Future<void> loadKeywords() async {
    try {
      _keywords = await _dbHelper.getKeywords();
      notifyListeners();
    } catch (e) {
      print('キーワードの読み込み中にエラーが発生しました: $e');
    }
  }

  Future<void> saveKeywords(List<String> keywords) async {
    try {
      _keywords = keywords;
      await _dbHelper.saveKeywords(keywords);
      notifyListeners();
    } catch (e) {
      print('キーワードの保存中にエラーが発生しました: $e');
    }
  }

  Future<void> addKeywords(String keyword) async {
    // キーワードが既に存在しない場合のみ追加
    if (!_keywords.contains(keyword)) {
      try {
        await _dbHelper.insertKeyword(keyword);
        _keywords.add(keyword); // 新しいキーワードをリストに追加
        notifyListeners(); // リスナーに変更を通知
      } catch (e) {
        print('キーワードの追加中にエラーが発生しました: $e');
      }
    } else {
      print('キーワード "$keyword" は既に存在します');
    }
  }

  /// セマンティック検索を使用したキーワード検出（改善版）
  Future<List<KeywordDetection>> detectKeywordsSemantic(String transcript) async {
    if (_semanticSearchService == null || !_semanticSearchService!.isInitialized) {
      // フォールバック: 完全一致検出
      final exactMatches = _keywords.where((k) => transcript.contains(k)).toList();
      return exactMatches.map((k) {
        final index = transcript.indexOf(k);
        return KeywordDetection(
          keyword: k,
          similarity: 1.0,
          startIndex: index,
          endIndex: index + k.length,
          matchedText: k,
        );
      }).toList();
    }

    List<KeywordDetection> detections;
    switch (_detectionMode) {
      case 'exact':
        // 完全一致のみ
        detections = await _keywordDetectorService.detectKeywordsHybrid(transcript, _keywords)
            .then((d) => d.where((detection) => detection.similarity == 1.0).toList());
        break;
      
      case 'semantic':
        // セマンティック検索のみ
        detections = await _keywordDetectorService.detectKeywords(transcript, _keywords);
        break;
      
      case 'hybrid':
      default:
        // 両方を使用
        detections = await _keywordDetectorService.detectKeywordsHybrid(transcript, _keywords);
        break;
    }
    
    // 検出結果のサマリーを表示
    if (detections.isNotEmpty) {
      final uniqueKeywords = detections.map((d) => d.keyword).toSet();
      print('🔍 キーワード検出: ${uniqueKeywords.length}個 (${uniqueKeywords.join(", ")})');
    }
    
    return detections;
  }

  // 後方互換性のため、既存のメソッドも維持
  Future<List<String>> detectKeywords(String transcript) async {
    final detections = await detectKeywordsSemantic(transcript);
    return detections.map((d) => d.keyword).toSet().toList();
  }

  Future<void> deleteKeywords(int index) async {
    // インデックスが有効か確認
    if (index >= 0 && index < _keywords.length) {
      try {
        String keyword = _keywords[index];
        await _dbHelper.deleteKeyword(keyword);
        _keywords.removeAt(index); // 指定されたインデックスの要素を削除
        notifyListeners(); // リスナーに変更を通知
      } catch (e) {
        print('キーワードの削除中にエラーが発生しました: $e');
      }
    } else {
      print('無効なインデックス: $index');
    }
  }

  // キーワード検出履歴を保存
  Future<void> saveKeywordDetection(
      String keyword, String className, String contextText) async {
    try {
      await _dbHelper.saveKeywordDetection(keyword, className, contextText);
    } catch (e) {
      print('キーワード検出履歴の保存中にエラーが発生しました: $e');
    }
  }

  // 特定の授業のキーワード検出履歴を取得
  Future<List<Map<String, dynamic>>> getKeywordDetectionsByClass(
      String className) async {
    try {
      return await _dbHelper.getKeywordDetectionsByClass(className);
    } catch (e) {
      print('キーワード検出履歴の取得中にエラーが発生しました: $e');
      return [];
    }
  }

  // 全てのキーワード検出履歴を取得
  Future<List<Map<String, dynamic>>> getAllKeywordDetections() async {
    try {
      return await _dbHelper.getKeywordDetections();
    } catch (e) {
      print('キーワード検出履歴の取得中にエラーが発生しました: $e');
      return [];
    }
  }
  
  @override
  void dispose() {
    _semanticSearchService?.dispose();
    super.dispose();
  }
}
