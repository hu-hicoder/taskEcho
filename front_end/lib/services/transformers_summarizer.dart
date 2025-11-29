// 条件付きエクスポート: Webの場合のみ dart:js を使用
export 'transformers_summarizer_stub.dart'
    if (dart.library.html) 'transformers_summarizer_web.dart';