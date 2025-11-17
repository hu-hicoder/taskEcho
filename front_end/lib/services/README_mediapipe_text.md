# MediaPipe-style Text Embedder

MediaPipe Text Embedder 風のシンプルで使いやすいAPIを提供する Flutter 用のテキスト埋め込みライブラリです。

## 特徴

- 🚀 **シンプルなAPI**: MediaPipe のような直感的なインターフェース
- 🇯🇵 **日本語対応**: sentence-bert-base-ja-mean-tokens-v2 モデルを使用
- ⚡ **高速**: TensorFlow Lite による効率的な推論
- 🔄 **バッチ処理対応**: 複数のテキストを一度に処理可能
- 🎯 **意味的類似度計算**: コサイン類似度による高精度な比較

## インストール

`pubspec.yaml` に以下を追加:

```yaml
dependencies:
  tflite_flutter: ^0.12.0
```

## 使い方

### 基本的な使用例

```dart
import 'package:flutter_speech_to_text/services/mediapipe_style_text_embedder.dart';

// 1. エンベッダーを初期化
final embedder = MediaPipeStyleTextEmbedder();
await embedder.initialize();

// 2. テキストをエンベディング（ベクトル化）
final embedding = await embedder.encodeText('これはテストです');
print('Embedding dimension: ${embedding?.length}'); // 768

// 3. 2つのテキストの類似度を計算
final similarity = await embedder.calculateTextSimilarity(
  'プログラミングの課題を提出する',
  'コーディングの宿題を出す',
);
print('Similarity: $similarity'); // 0.0〜1.0

// 4. キーワード検索
final found = await embedder.searchSimilarText(
  '課題',
  '今日中に提出する宿題がある',
  threshold: 0.6,
);
print('Keyword found: $found'); // true/false

// 5. クリーンアップ
embedder.dispose();
```

### バッチ処理

```dart
final texts = [
  'プログラミング課題を提出する',
  '数学のレポートを書く',
  '英語の単語を覚える',
];

final embeddings = await embedder.embedBatch(texts);
for (var i = 0; i < embeddings.length; i++) {
  print('Text $i embedding: ${embeddings[i]?.length} dimensions');
}
```

### Provider と組み合わせて使用

```dart
import 'package:provider/provider.dart';

class TextEmbedderProvider extends ChangeNotifier {
  final MediaPipeStyleTextEmbedder _embedder = MediaPipeStyleTextEmbedder();
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> initialize() async {
    await _embedder.initialize();
    _isReady = true;
    notifyListeners();
  }

  Future<double> getSimilarity(String text1, String text2) async {
    if (!_isReady) {
      throw StateError('Embedder not initialized');
    }
    return await _embedder.calculateTextSimilarity(text1, text2);
  }

  @override
  void dispose() {
    _embedder.dispose();
    super.dispose();
  }
}
```

## API リファレンス

### MediaPipeStyleTextEmbedder

#### メソッド

##### `initialize()`
エンベッダーを初期化します。使用前に必ず呼び出してください。

```dart
await embedder.initialize();
```

##### `encodeText(String text)`
テキストをベクトル（Float32List）に変換します。

```dart
final embedding = await embedder.encodeText('テキスト');
```

**戻り値**: `Float32List?` - 768次元のベクトル（失敗時は null）

##### `calculateTextSimilarity(String text1, String text2)`
2つのテキスト間の意味的類似度を計算します。

```dart
final similarity = await embedder.calculateTextSimilarity(
  'プログラミング',
  'コーディング',
);
```

**戻り値**: `double` - 類似度スコア（0.0〜1.0）
- 0.8以上: 非常に類似
- 0.6〜0.8: やや類似
- 0.4〜0.6: わずかに類似
- 0.4未満: 類似していない

##### `calculateSimilarity(String searchKeyword, String taskText)`
インターフェース `ISemanticSearchService` の実装。`calculateTextSimilarity` と同じです。

```dart
final similarity = await embedder.calculateSimilarity(
  'キーワード',
  'テキスト',
);
```

##### `searchSimilarText(String keyword, String taskText, {double threshold})`
キーワードがテキスト内に意味的に含まれているかチェックします。

```dart
final found = await embedder.searchSimilarText(
  '課題',
  '今日の宿題を提出する',
  threshold: 0.6,
);
```

**パラメータ**:
- `keyword`: 検索キーワード
- `taskText`: 検索対象のテキスト
- `threshold`: 類似度の閾値（デフォルト: 0.7）

**戻り値**: `bool` - 閾値以上の類似度がある場合は true

##### `embedBatch(List<String> texts)`
複数のテキストを一度にエンベディングします。

```dart
final embeddings = await embedder.embedBatch([
  'テキスト1',
  'テキスト2',
  'テキスト3',
]);
```

**戻り値**: `List<Float32List?>` - 各テキストのベクトル

##### `calculateCosineSimilarity(Float32List vector1, Float32List vector2)`
2つのベクトル間のコサイン類似度を計算します。

```dart
final similarity = embedder.calculateCosineSimilarity(vec1, vec2);
```

##### `printModelInfo()`
モデルの情報をコンソールに出力します（デバッグ用）。

```dart
embedder.printModelInfo();
```

##### `dispose()`
リソースを解放します。使用後は必ず呼び出してください。

```dart
embedder.dispose();
```

#### プロパティ

##### `isInitialized`
エンベッダーが初期化済みかどうか。

```dart
if (embedder.isInitialized) {
  // エンベッダーを使用
}
```

## 使用モデル

**sentence-bert-base-ja-mean-tokens-v2**
- 日本語専用のBERTベースモデル
- 768次元のベクトル表現
- 最大シーケンス長: 128トークン

## デモアプリ

デモアプリを実行するには:

```dart
import 'package:flutter_speech_to_text/demo/mediapipe_text_demo.dart';

// MaterialApp 内で
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => MediaPipeTextDemo()),
);
```

## テスト

```bash
flutter test test/mediapipe_style_text_embedder_test.dart
```

## パフォーマンス

- 初期化: 約1〜2秒
- 単一テキストのエンベディング: 約50〜100ms
- 類似度計算: 約100〜200ms

## 制限事項

- 最大シーケンス長: 128トークン（それ以上は切り詰められます）
- 日本語専用（他の言語では精度が低下する可能性があります）
- オフライン動作（ネットワーク不要）

## トラブルシューティング

### モデルが読み込めない

`assets/models/sentence_bert_ja.tflite` が存在することを確認してください。

### 初期化エラー

```dart
try {
  await embedder.initialize();
} catch (e) {
  print('Initialization error: $e');
  // エラー処理
}
```

### メモリ不足

バッチサイズを小さくするか、一度に処理するテキスト数を減らしてください。

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。

## 参考

- [TensorFlow Lite Flutter Plugin](https://pub.dev/packages/tflite_flutter)
- [sentence-bert-base-ja-mean-tokens-v2](https://huggingface.co/sonoisa/sentence-bert-base-ja-mean-tokens-v2)
- [MediaPipe](https://developers.google.com/mediapipe)
