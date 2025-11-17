# MediaPipe Text 統合の現状

## 📋 概要

`mediapipe_text` パッケージの統合を試みましたが、**Native Assets** 機能との互換性の問題により、現在は一時的に無効化しています。

## ❌ 発生した問題

### エラー内容
```
Target dart_build failed: Error: Package(s) mediapipe_text require the native assets feature to be enabled.
Enable using `flutter config --enable-native-assets`.

BUILD FAILED in 12s
Gradle task assembleDebug failed with exit code 1
```

### 試した対策
1. ✅ `flutter config --enable-native-assets` を実行
2. ✅ `flutter clean` と `flutter pub get` を実行
3. ❌ それでもビルドエラーが発生

### 原因
- `mediapipe_text: ^0.0.1` パッケージはまだ experimental 段階
- Native Assets 機能の安定性の問題
- Flutter と Gradle の互換性の問題

## ✅ 現在の対策

### 一時的な無効化

`pubspec.yaml`:
```yaml
# mediapipe_core: ^0.0.1  # 一時的に無効化
# mediapipe_text: ^0.0.1  # 一時的に無効化（Native Assets の問題）
```

`lib/providers/keywordProvider.dart`:
```dart
String _modelType = 'japanese'; // デフォルトは日本語専用（安定版）

// MediaPipe は一時的に無効化
// import '../services/mediapipe_text_service.dart';
```

### 代替実装

現在は **日本語 BERT モデル** を使用しています：
- ✅ 安定動作
- ✅ 日本語に最適化
- ✅ Native Assets 不要
- ✅ ビルドエラーなし

## 📚 実装済みのコード

MediaPipe Text の統合コードは完成しており、将来の有効化に備えて保持しています：

### ファイル一覧
1. `lib/services/mediapipe_text_service.dart` - MediaPipe Text サービス実装
2. `lib/services/mediapipe_text_embedder.dart` - ネイティブ統合版
3. `test/mediapipe_text_service_test.dart` - テストコード
4. `android/.../MediaPipeTextEmbedderPlugin.kt` - Android ネイティブコード
5. `ios/.../MediaPipeTextEmbedderPlugin.swift` - iOS ネイティブコード
6. `scripts/download_mediapipe_model.sh` - モデルダウンロードスクリプト
7. `docs/mediapipe_native_integration.md` - 統合ドキュメント

### モデルファイル
- ✅ `assets/models/universal_sentence_encoder.tflite` (5.8MB)

## 🔮 将来の有効化手順

MediaPipe Text パッケージが安定したら、以下の手順で有効化できます：

### 1. パッケージのコメントを解除

`pubspec.yaml`:
```yaml
mediapipe_core: ^0.0.1
mediapipe_text: ^0.0.1
```

### 2. import のコメントを解除

`lib/providers/keywordProvider.dart`:
```dart
import '../services/mediapipe_text_service.dart';
```

### 3. モデルタイプを変更

```dart
String _modelType = 'mediapipe';
```

### 4. 初期化コードのコメントを解除

```dart
} else if (_modelType == 'mediapipe') {
  print('🔧 MediaPipe公式モデルを使用');
  _semanticSearchService = MediaPipeTextService();
}
```

### 5. ビルドと実行

```bash
flutter clean
flutter pub get
flutter run
```

## 📊 モデル比較

| モデル | 状態 | パッケージ | 日本語精度 | ビルド |
|--------|------|-----------|----------|--------|
| **Japanese BERT** | ✅ 使用中 | `tflite_flutter` | ⭐⭐⭐⭐⭐ | ✅ 安定 |
| **Multilingual USE** | ⚠️ 利用可能 | `tflite_flutter` | ⭐⭐⭐ | ✅ 安定 |
| **MediaPipe Text** | ❌ 無効化 | `mediapipe_text` | ⭐⭐⭐⭐ | ❌ エラー |

## 🔧 トラブルシューティング

### Native Assets エラーが発生する場合

1. Native Assets を無効化：
```bash
flutter config --no-enable-native-assets
```

2. プロジェクトをクリーン：
```bash
flutter clean
flutter pub get
```

3. Gradle キャッシュをクリーン（Android）：
```bash
cd android
./gradlew clean
cd ..
```

### MediaPipe を試したい場合

将来的に Flutter の Native Assets サポートが改善されたら再試行してください。

参考:
- https://pub.dev/packages/mediapipe_text
- https://docs.flutter.dev/platform-integration/native-assets

## ✅ 現在の推奨設定

**日本語 BERT モデル** を使用することを推奨します：
- 最も安定している
- 日本語に最適化されている
- ビルドエラーがない
- Native Assets 不要

MediaPipe Text は将来の機能として準備済みですが、現時点では使用しないでください。

---

最終更新: 2025年11月15日
