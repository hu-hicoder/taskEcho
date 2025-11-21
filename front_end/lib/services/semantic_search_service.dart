// インターフェースのエクスポート
export 'i_semantic_search_service.dart';

// 条件付きエクスポート
// Webの場合は _web.dart を、それ以外（Android/iOS）は _native.dart を使用
export 'semantic_search_service_native.dart'
    if (dart.library.html) 'semantic_search_service_web.dart';