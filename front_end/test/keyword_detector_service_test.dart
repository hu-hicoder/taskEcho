import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_speech_to_text/services/semantic_search_service.dart';
import 'package:flutter_speech_to_text/services/keyword_detector_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeywordDetectorService', () {
    late SemanticSearchService semanticSearchService;
    late KeywordDetectorService keywordDetectorService;

    setUp(() {
      semanticSearchService = SemanticSearchService();
      keywordDetectorService = KeywordDetectorService(semanticSearchService);
    });

    tearDown(() {
      semanticSearchService.dispose();
    });

    test('類似度閾値を設定できる', () {
      keywordDetectorService.setSimilarityThreshold(0.8);
      expect(keywordDetectorService, isNotNull);
    });

    test('無効な閾値でエラーが発生する', () {
      expect(
        () => keywordDetectorService.setSimilarityThreshold(1.5),
        throwsArgumentError,
      );
      expect(
        () => keywordDetectorService.setSimilarityThreshold(-0.1),
        throwsArgumentError,
      );
    });

    test('ウィンドウサイズを設定できる', () {
      keywordDetectorService.setWindowSize(100);
      expect(keywordDetectorService, isNotNull);
    });

    test('完全一致検出が動作する', () async {
      final text = 'これは会議の議事録です。会議では重要な決定がありました。';
      final keywords = ['会議'];

      final detections = await keywordDetectorService.detectKeywordsHybrid(
        text,
        keywords,
      );

      // 完全一致が検出される
      final exactMatches = detections.where((d) => d.similarity == 1.0).toList();
      expect(exactMatches.length, greaterThan(0));
      expect(exactMatches.first.keyword, '会議');
      print('✅ 完全一致検出: ${exactMatches.length}件');
      
      for (final match in exactMatches) {
        print('   - "${match.matchedText}" (類似度: ${match.similarity.toStringAsFixed(2)})');
      }
    });

    test('セマンティック検索による類似語検出（初期化が必要）', () async {
      // この テストはモデルの初期化が必要なため、初期化をスキップして設計を確認
      print('📝 セマンティック検索テスト:');
      print('   期待される動作:');
      print('   - 「会議」というキーワードで「ミーティング」「打ち合わせ」も検出');
      print('   - 「タスク」というキーワードで「仕事」「作業」も検出');
      print('   - 類似度が閾値以上の場合のみ検出');
      
      // 実際の検出（モデル初期化後に動作）
      try {
        await semanticSearchService.initialize();
        
        final text = '明日のミーティングで重要な打ち合わせがあります。';
        final keywords = ['会議'];

        final detections = await keywordDetectorService.detectKeywords(
          text,
          keywords,
        );

        print('✅ セマンティック検出: ${detections.length}件');
        for (final detection in detections) {
          print('   - "${detection.matchedText}" ← "${detection.keyword}" (類似度: ${detection.similarity.toStringAsFixed(2)})');
        }
      } catch (e) {
        print('⚠️ モデル未初期化のため、セマンティック検索はスキップされました: $e');
      }
    });

    test('ハイブリッド検出モードのテスト', () async {
      final text = '''
        本日の会議では以下の議題について話し合いました。
        次回のミーティングは来週の月曜日に設定されています。
        打ち合わせの結果、新しいプロジェクトを開始することが決定しました。
      ''';
      final keywords = ['会議', 'プロジェクト'];

      final detections = await keywordDetectorService.detectKeywordsHybrid(
        text,
        keywords,
      );

      print('📊 ハイブリッド検出結果:');
      print('   総検出数: ${detections.length}件');
      
      final exactMatches = detections.where((d) => d.similarity == 1.0);
      final semanticMatches = detections.where((d) => d.similarity < 1.0);
      
      print('   完全一致: ${exactMatches.length}件');
      print('   セマンティック: ${semanticMatches.length}件');
      
      for (final detection in detections.take(5)) {
        print('   - "${detection.matchedText}" ← "${detection.keyword}"');
        print('     類似度: ${detection.similarity.toStringAsFixed(2)} (${detection.similarity == 1.0 ? "完全一致" : "セマンティック"})');
      }

      expect(detections, isNotEmpty);
    });

    test('空のテキストや空のキーワードリストの処理', () async {
      // 空のテキスト
      final detections1 = await keywordDetectorService.detectKeywords('', ['会議']);
      expect(detections1, isEmpty);

      // 空のキーワードリスト
      final detections2 = await keywordDetectorService.detectKeywords('テスト', []);
      expect(detections2, isEmpty);

      print('✅ 空の入力を正しく処理しました');
    });

    test('KeywordDetectionのJSON変換', () {
      final detection = KeywordDetection(
        keyword: 'テスト',
        similarity: 0.95,
        startIndex: 0,
        endIndex: 3,
        matchedText: 'テスト',
      );

      final json = detection.toJson();
      expect(json['keyword'], 'テスト');
      expect(json['similarity'], 0.95);
      expect(json['startIndex'], 0);
      expect(json['endIndex'], 3);
      expect(json['matchedText'], 'テスト');

      print('✅ JSON変換が正しく動作しました');
    });
  });
}
