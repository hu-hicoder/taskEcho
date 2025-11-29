import 'package:flutter/foundation.dart';
import 'transformers_summarizer.dart';

/// Web版（デモ）用のシンプルな要約サービス
class SimpleSummarizeService {
  /// キーワード周辺のテキストを抽出して簡易要約
  static Future<String> extractAndSummarize(
    String fullText,
    List<String> keywords, {
    int contextLength = 200,
  }) async {
    if (keywords.isEmpty) {
      // キーワードがない場合は全文を要約
      return await _summarizeText(fullText, null);
    }

    String keyword = keywords.first;

    // キーワードの位置を見つける
    int keywordIndex = fullText.indexOf(keyword);
    if (keywordIndex == -1) {
      print('キーワード「$keyword」が見つかりません');
      return await _summarizeText(fullText, keyword);
    }

    // 前後の文脈を含めるための範囲を計算
    int startIndex = (keywordIndex - contextLength) < 0
        ? 0
        : keywordIndex - contextLength;
    int endIndex = (keywordIndex + keyword.length + contextLength) >
            fullText.length
        ? fullText.length
        : keywordIndex + keyword.length + contextLength;

    // 抽出したテキスト
    String extractedText = fullText.substring(startIndex, endIndex);

    // 要約を実行
    final summary = await _summarizeText(extractedText, keyword);

    return "【キーワード「$keyword」検出】 $summary";
  }

  /// テキストを要約（Transformers.js 優先、フォールバックあり）
  static Future<String> _summarizeText(String text, String? keyword) async {
    // 1. Transformers.js で要約を試みる（Web版のみ）
    if (kIsWeb) {
      try {
        final aiSummary = await TransformersSummarizer.summarize(text);
        if (aiSummary != null && aiSummary.isNotEmpty) {
          print('✅ Transformers.js で要約成功');
          return aiSummary;
        }
      } catch (e) {
        print('⚠️ Transformers.js 要約失敗、フォールバック処理へ: $e');
      }
    }

    // 2. フォールバック: シンプルな抽出ロジック
    print('📝 シンプルな抽出ロジックで要約');
    return _simpleSummarize(text, keyword);
  }

  /// シンプルな要約処理（フォールバック用）
  static String _simpleSummarize(String text, String? keyword) {
    // 元のテキストが短い場合はそのまま返す
    if (text.length < 30) {
      return text;
    }

    // 1. 文を分割
    final sentences = _splitIntoSentences(text);

    if (sentences.isEmpty) {
      return text;
    }

    // 1文しかない場合はそのまま返す
    if (sentences.length == 1) {
      return sentences.first;
    }

    // 2. キーワードを含む文を優先的に選択
    if (keyword != null && keyword.isNotEmpty) {
      final keywordSentences = sentences
          .where((s) => s.contains(keyword))
          .toList();

      if (keywordSentences.isNotEmpty) {
        // キーワードを含む文 + 前後1文を含める
        final Set<String> selectedSet = {};
        
        for (final kwSentence in keywordSentences) {
          final index = sentences.indexOf(kwSentence);
          
          // 前の文を追加
          if (index > 0) {
            selectedSet.add(sentences[index - 1]);
          }
          
          // キーワードを含む文を追加
          selectedSet.add(kwSentence);
          
          // 次の文を追加
          if (index < sentences.length - 1) {
            selectedSet.add(sentences[index + 1]);
          }
        }
        
        // 元の順序を保持して結合
        final result = sentences
            .where((s) => selectedSet.contains(s))
            .join(' ');
        
        return result;
      }
    }

    // 3. キーワードがない場合は重要度スコアで選択
    final scoredSentences = sentences.map((sentence) {
      final score = _calculateImportanceScore(sentence);
      return {'sentence': sentence, 'score': score};
    }).toList();

    // スコア順にソート
    scoredSentences.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // 上位50%または最低3文を抽出（最大5文）
    final summaryCount = (sentences.length * 0.5)
        .ceil()
        .clamp(3, 5)
        .clamp(1, sentences.length);
    
    final selectedSentences = scoredSentences
        .take(summaryCount)
        .map((item) => item['sentence'] as String)
        .toList();

    // 元の順序で結合
    final summary = sentences
        .where((s) => selectedSentences.contains(s))
        .join(' ');

    return summary.isNotEmpty ? summary : text;
  }

  /// 文を分割
  static List<String> _splitIntoSentences(String text) {
    final sentences = <String>[];
    final parts = text.split(RegExp(r'[。！？]'));
    
    for (var part in parts) {
      if (part.trim().isEmpty) continue;
      sentences.add(part.trim() + '。');
    }
    
    return sentences.where((s) => s.length > 1).toList();
  }

  /// 重要度スコアを計算
  static double _calculateImportanceScore(String sentence) {
    double score = 0.0;

    final importantKeywords = [
      '重要', '必要', '必須', '注意', '確認', '提出', '締切', '期限',
      '課題', '宿題', '試験', 'テスト', '発表', 'プレゼン', 'レポート',
      '会議', 'ミーティング', '予定', '日時', '場所', 'スケジュール',
      '明日', '今日', '明後日', '来週', '再来週', '月末',
    ];

    for (final keyword in importantKeywords) {
      if (sentence.contains(keyword)) {
        score += 3.0;
      }
    }

    if (RegExp(r'\d+').hasMatch(sentence)) {
      score += 2.0;
    }

    if (RegExp(r'[0-9]+月|[0-9]+日|月曜|火曜|水曜|木曜|金曜|土曜|日曜')
        .hasMatch(sentence)) {
      score += 2.5;
    }

    if (RegExp(r'[0-9]+時|[0-9]+分').hasMatch(sentence)) {
      score += 2.0;
    }

    final length = sentence.length;
    if (length < 5) {
      score -= 5.0;
    } else if (length > 10 && length < 80) {
      score += 1.5;
    }

    return score;
  }
}