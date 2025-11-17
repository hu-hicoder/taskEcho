import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_speech_to_text/services/mediapipe_style_text_embedder.dart';

void main() {
  group('MediaPipeStyleTextEmbedder Tests', () {
    late MediaPipeStyleTextEmbedder embedder;

    setUp(() {
      embedder = MediaPipeStyleTextEmbedder();
    });

    tearDown(() {
      embedder.dispose();
    });

    test('初期化が正常に行われること', () async {
      await embedder.initialize();
      expect(embedder.isInitialized, true);
      
      // モデル情報を表示
      embedder.printModelInfo();
    });

    test('テキストのエンベディングが生成されること', () async {
      await embedder.initialize();

      final text = 'これはテストです';
      final embedding = await embedder.encodeText(text);

      expect(embedding, isNotNull);
      expect(embedding!.length, 768); // BERT base の埋め込み次元
      print('Embedding generated: ${embedding.sublist(0, 5)}...'); // 最初の5要素を表示
    });

    test('2つの類似したテキストの類似度が高いこと', () async {
      await embedder.initialize();

      final text1 = 'プログラミングの課題を提出する';
      final text2 = 'コーディングの宿題を出す';

      final similarity = await embedder.calculateTextSimilarity(text1, text2);
      
      print('Similarity between "$text1" and "$text2": $similarity');
      expect(similarity, greaterThan(0.6)); // 類似度が0.6以上
    });

    test('異なるテキストの類似度が低いこと', () async {
      await embedder.initialize();

      final text1 = 'プログラミングの課題を提出する';
      final text2 = '明日は雨が降るでしょう';

      final similarity = await embedder.calculateTextSimilarity(text1, text2);
      
      print('Similarity between "$text1" and "$text2": $similarity');
      expect(similarity, lessThan(0.5)); // 類似度が0.5未満
    });

    test('キーワード検索が正しく動作すること', () async {
      await embedder.initialize();

      final keyword = '課題';
      final text1 = '今日中に提出する宿題がある';
      final text2 = '明日は晴れるでしょう';

      final found1 = await embedder.searchSimilarText(keyword, text1, threshold: 0.6);
      final found2 = await embedder.searchSimilarText(keyword, text2, threshold: 0.6);

      print('Keyword "$keyword" found in "$text1": $found1');
      print('Keyword "$keyword" found in "$text2": $found2');

      expect(found1, true);  // 類似しているテキストで見つかる
      expect(found2, false); // 類似していないテキストでは見つからない
    });

    test('バッチ処理が正常に動作すること', () async {
      await embedder.initialize();

      final texts = [
        'プログラミング課題を提出する',
        '数学のレポートを書く',
        '英語の単語を覚える',
      ];

      final embeddings = await embedder.embedBatch(texts);

      expect(embeddings.length, 3);
      for (int i = 0; i < embeddings.length; i++) {
        expect(embeddings[i], isNotNull);
        expect(embeddings[i]!.length, 768);
        print('Text $i: "${texts[i]}" -> Embedding generated');
      }
    });

    test('空のテキストを処理できること', () async {
      await embedder.initialize();

      final embedding = await embedder.encodeText('');
      expect(embedding, isNull);
    });

    test('長いテキストを処理できること', () async {
      await embedder.initialize();

      final longText = '今日は' * 100; // 非常に長いテキスト
      final embedding = await embedder.encodeText(longText);

      expect(embedding, isNotNull);
      expect(embedding!.length, 768);
      print('Long text processed successfully');
    });
  });
}
