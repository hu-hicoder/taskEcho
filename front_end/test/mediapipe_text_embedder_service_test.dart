import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_speech_to_text/services/mediapipe_text_embedder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPipe Text Embedder Service Tests', () {
    late MediaPipeTextEmbedderService embedder;

    setUp(() {
      embedder = MediaPipeTextEmbedderService();
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

      final text = 'Hello, world!';
      final embedding = await embedder.encodeText(text);

      expect(embedding, isNotNull);
      expect(embedding!.length, greaterThan(0));
      print('Embedding dimension: ${embedding.length}');
      print('First 5 values: ${embedding.sublist(0, 5)}');
    });

    test('日本語テキストのエンベディングが生成されること', () async {
      await embedder.initialize();

      final text = 'これはテストです';
      final embedding = await embedder.encodeText(text);

      expect(embedding, isNotNull);
      expect(embedding!.length, greaterThan(0));
      print('Japanese text embedded successfully');
    });

    test('2つの類似したテキストの類似度が高いこと', () async {
      await embedder.initialize();

      final text1 = 'プログラミングの課題を提出する';
      final text2 = 'コーディングの宿題を出す';

      final similarity = await embedder.calculateSimilarity(text1, text2);
      
      expect(similarity, isNotNull);
      print('Similarity between "$text1" and "$text2": ${similarity!.toStringAsFixed(4)}');
      expect(similarity, greaterThan(0.5)); // 類似度が0.5以上
    });

    test('異なるテキストの類似度が低いこと', () async {
      await embedder.initialize();

      final text1 = 'プログラミングの課題を提出する';
      final text2 = '明日は雨が降るでしょう';

      final similarity = await embedder.calculateSimilarity(text1, text2);
      
      expect(similarity, isNotNull);
      print('Similarity between "$text1" and "$text2": ${similarity!.toStringAsFixed(4)}');
      expect(similarity, lessThan(0.6)); // 類似度が0.6未満
    });

    test('英語と日本語が混在したテキストを処理できること', () async {
      await embedder.initialize();

      final text1 = 'Submit the programming assignment';
      final text2 = 'プログラミング課題を提出';

      final similarity = await embedder.calculateSimilarity(text1, text2);
      
      expect(similarity, isNotNull);
      print('Similarity (EN-JP): ${similarity!.toStringAsFixed(4)}');
      expect(similarity, greaterThan(0.4)); // 多言語でも意味が似ていれば類似度がある
    });

    test('キーワード検索が正しく動作すること', () async {
      await embedder.initialize();

      final keyword = '課題';
      final text1 = '今日中に提出する宿題がある';
      final text2 = '明日は晴れるでしょう';

      final found1 = await embedder.searchSimilarText(keyword, text1, threshold: 0.5);
      final found2 = await embedder.searchSimilarText(keyword, text2, threshold: 0.5);

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
        print('Text $i embedded: ${embeddings[i]!.length} dimensions');
      }
    });

    test('空のテキストを処理できること', () async {
      await embedder.initialize();

      final embedding = await embedder.encodeText('');
      expect(embedding, isNull);
    });

    test('多言語対応を確認（英語、日本語、中国語）', () async {
      await embedder.initialize();

      final texts = {
        'English': 'Good morning',
        'Japanese': 'おはようございます',
        'Chinese': '早上好',
      };

      for (final entry in texts.entries) {
        final embedding = await embedder.encodeText(entry.value);
        expect(embedding, isNotNull);
        print('${entry.key}: "${entry.value}" -> Embedding OK');
      }

      // 同じ意味の異なる言語間の類似度をチェック
      final simEnJp = await embedder.calculateSimilarity(
        texts['English']!,
        texts['Japanese']!,
      );
      print('EN-JP similarity: ${simEnJp?.toStringAsFixed(4)}');
      expect(simEnJp, isNotNull);
      expect(simEnJp!, greaterThan(0.3)); // 多言語でも意味が同じなら少し似ている
    });
  });
}
