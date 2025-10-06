/// 音声認識テキストから抽出した
/// スケジュール候補を表すモデル
class ScheduleCandidate {
  final DateTime time;
  final String summary;

  ScheduleCandidate({
    required this.time,
    required this.summary,
  });

  @override
  String toString() => '$summary @ $time';
}

/// 要約のために文字列を送信するためのモデル
class RecognitionObject {
  final String keyword;
  final String text;

  RecognitionObject({
    required this.keyword,
    required this.text,
  });

  // JSONに変換するメソッド（バックエンドAPI送信用）
  Map<String, dynamic> toJson() {
    return {
      'keyword': keyword,
      'text': text,
    };
  }

  // JSONから変換するメソッド（必要に応じて）
  factory RecognitionObject.fromJson(Map<String, dynamic> json) {
    return RecognitionObject(
      keyword: json['keyword'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

/// バックエンドAPIへの要約リクエスト用モデル
class SummarizeRequest {
  final String text;
  final String? keyword;  // この行を追加
  final int? maxLength;

  SummarizeRequest({
    required this.text,
    this.keyword,  // この行を追加
    this.maxLength,
  });

  // JSONに変換するメソッド（バックエンドAPI送信用）
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      if (keyword != null) 'keyword': keyword,  // この行を追加
      if (maxLength != null) 'max_length': maxLength,
    };
  }
}

/// バックエンドAPIからの要約レスポンス用モデル
class SummarizeResponse {
  final String summarizedText;

  SummarizeResponse({
    required this.summarizedText,
  });

  // JSONから変換するメソッド
  factory SummarizeResponse.fromJson(Map<String, dynamic> json) {
    return SummarizeResponse(
      summarizedText: json['summarized_text'] ?? '',
    );
  }

  // JSONに変換するメソッド（必要に応じて）
  Map<String, dynamic> toJson() {
    return {
      'summarized_text': summarizedText,
    };
  }
}