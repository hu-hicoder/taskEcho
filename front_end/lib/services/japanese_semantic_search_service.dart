// インターフェースのエクスポート
export 'i_semantic_search_service.dart';
// Tokenizerのエクスポート（必要であれば）
export 'japanese_bert_tokenizer.dart';

// クラスのエクスポート
// これにより、外部からは JapaneseSemanticSearchService としてアクセスできます
export 'japanese_semantic_search_service_native.dart'
    if (dart.library.html) 'japanese_semantic_search_service_web.dart';