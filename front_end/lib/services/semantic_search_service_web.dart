import 'dart:typed_data';
import 'i_semantic_search_service.dart';

/// Web用のダミー実装
/// Webでは Universal Sentence Encoder は重すぎるため、
/// JapaneseSemanticSearchService の使用を推奨します。
class SemanticSearchService implements ISemanticSearchService {
  @override
  bool get isInitialized => false;

  @override
  Future<void> initialize() async {
    print('⚠️ Web: SemanticSearchService is not supported. Please use JapaneseSemanticSearchService.');
  }

  @override
  void dispose() {}

  @override
  void printModelInfo() {}

  @override
  Future<Float32List?> encodeText(String text) async => null;

  @override
  double calculateCosineSimilarity(Float32List vector1, Float32List vector2) => 0.0;

  @override
  Future<double?> calculateSimilarity(String searchKeyword, String taskText) async => null;
}