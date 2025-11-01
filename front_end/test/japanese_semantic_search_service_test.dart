import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_speech_to_text/services/japanese_semantic_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JapaneseBertTokenizer Tests', () {
    late JapaneseBertTokenizer tokenizer;

    setUp(() async {
      tokenizer = JapaneseBertTokenizer();
      await tokenizer.initialize();
    });

    test('トークナイザーが初期化されること', () {
      expect(tokenizer.isInitialized, isTrue);
    });

    test('日本語テキストをトークン化できること', () {
      final tokens = tokenizer.tokenize('これはテストです。');
      expect(tokens, isNotEmpty);
      print('トークン: $tokens');
    });

    test('日本語テキストをエンコードできること', () {
      final encoded = tokenizer.encode(
        'これはテストです。',
        maxLength: 128,
      );
      
      expect(encoded['input_ids'], isNotNull);
      expect(encoded['attention_mask'], isNotNull);
      expect(encoded['input_ids']!.length, equals(128));
      expect(encoded['attention_mask']!.length, equals(128));
      
      print('Input IDs: ${encoded['input_ids']!.take(10)}');
      print('Attention Mask: ${encoded['attention_mask']!.take(10)}');
    });

    test('長いテキストが正しく切り詰められること', () {
      final longText = '日本語のテキストです。' * 50;
      final encoded = tokenizer.encode(
        longText,
        maxLength: 128,
        truncation: true,
      );
      
      expect(encoded['input_ids']!.length, equals(128));
      expect(encoded['attention_mask']!.length, equals(128));
    });
  });

  group('JapaneseSemanticSearchService Tests', () {
    late JapaneseSemanticSearchService service;

    setUp(() async {
      service = JapaneseSemanticSearchService();
      // Note: actual model loading requires Flutter app context
      // これは統合テストで実行する必要があります
    });

    test('サービスが作成されること', () {
      expect(service, isNotNull);
      expect(service.isInitialized, isFalse);
    });
  });
}
