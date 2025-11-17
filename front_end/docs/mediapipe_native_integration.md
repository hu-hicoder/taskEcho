# MediaPipe Text Embedder (ネイティブ統合版) の実装ガイド

## 概要

本物の MediaPipe Text Embedder を Flutter で使用するための実装ガイドです。

## アーキテクチャ

```
Flutter (Dart)
    ↓ Platform Channel
Native Code (Kotlin/Swift)
    ↓ MediaPipe Tasks API
MediaPipe Text Embedder
```

## 必要な手順

### 1. Android 実装

#### 1.1 build.gradle に依存関係を追加

`android/app/build.gradle`:
```gradle
dependencies {
    // MediaPipe Tasks Text
    implementation 'com.google.mediapipe:tasks-text:0.10.9'
}
```

#### 1.2 Kotlin でネイティブコードを実装

`android/app/src/main/kotlin/com/example/yourapp/MediaPipeTextEmbedderPlugin.kt`:
```kotlin
package com.example.flutter_speech_to_text

import android.content.Context
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import com.google.mediapipe.tasks.text.textembedder.TextEmbedderResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MediaPipeTextEmbedderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var textEmbedder: TextEmbedder? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "mediapipe_text_embedder")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                try {
                    val modelPath = call.argument<String>("modelPath")
                    
                    // BaseOptions の設定
                    val baseOptions = BaseOptions.builder()
                        .setModelAssetPath(modelPath ?: "universal_sentence_encoder.tflite")
                        .build()

                    // TextEmbedder の作成
                    val options = TextEmbedder.TextEmbedderOptions.builder()
                        .setBaseOptions(baseOptions)
                        .build()

                    textEmbedder = TextEmbedder.createFromOptions(context, options)
                    
                    result.success(true)
                } catch (e: Exception) {
                    result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
                }
            }

            "embed" -> {
                try {
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("INVALID_ARGUMENT", "Text is required", null)
                        return
                    }

                    if (textEmbedder == null) {
                        result.error("NOT_INITIALIZED", "TextEmbedder not initialized", null)
                        return
                    }

                    // テキストをエンベディング
                    val embedderResult = textEmbedder!!.embed(text)
                    val embedding = embedderResult.embeddings()[0]
                    
                    // Float配列として返す
                    val floatArray = embedding.floatEmbedding()
                    result.success(floatArray)

                } catch (e: Exception) {
                    result.error("EMBED_ERROR", "Failed to embed: ${e.message}", null)
                }
            }

            "cosineSimilarity" -> {
                try {
                    val text1 = call.argument<String>("text1")
                    val text2 = call.argument<String>("text2")

                    if (text1 == null || text2 == null) {
                        result.error("INVALID_ARGUMENT", "Both texts are required", null)
                        return
                    }

                    if (textEmbedder == null) {
                        result.error("NOT_INITIALIZED", "TextEmbedder not initialized", null)
                        return
                    }

                    // 両方のテキストをエンベディング
                    val result1 = textEmbedder!!.embed(text1)
                    val result2 = textEmbedder!!.embed(text2)

                    // コサイン類似度を計算
                    val similarity = TextEmbedder.cosineSimilarity(
                        result1.embeddings()[0],
                        result2.embeddings()[0]
                    )

                    result.success(similarity.toDouble())

                } catch (e: Exception) {
                    result.error("SIMILARITY_ERROR", "Failed to calculate: ${e.message}", null)
                }
            }

            "dispose" -> {
                textEmbedder?.close()
                textEmbedder = null
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        textEmbedder?.close()
    }
}
```

#### 1.3 MainActivity に登録

`android/app/src/main/kotlin/com/example/yourapp/MainActivity.kt`:
```kotlin
class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(MediaPipeTextEmbedderPlugin())
    }
}
```

### 2. iOS 実装

#### 2.1 Podfile に依存関係を追加

`ios/Podfile`:
```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  # MediaPipe Tasks Text
  pod 'MediaPipeTasksText', '~> 0.10.9'
end
```

#### 2.2 Swift でネイティブコードを実装

`ios/Runner/MediaPipeTextEmbedderPlugin.swift`:
```swift
import Flutter
import UIKit
import MediaPipeTasksText

public class MediaPipeTextEmbedderPlugin: NSObject, FlutterPlugin {
    private var textEmbedder: TextEmbedder?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "mediapipe_text_embedder",
            binaryMessenger: registrar.messenger()
        )
        let instance = MediaPipeTextEmbedderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeEmbedder(call: call, result: result)
        case "embed":
            embedText(call: call, result: result)
        case "cosineSimilarity":
            calculateSimilarity(call: call, result: result)
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeEmbedder(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let modelPath = args["modelPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Model path required", details: nil))
            return
        }
        
        do {
            let modelAssetPath = Bundle.main.path(
                forResource: modelPath,
                ofType: nil
            ) ?? ""
            
            let options = TextEmbedderOptions()
            options.baseOptions.modelAssetPath = modelAssetPath
            
            textEmbedder = try TextEmbedder(options: options)
            result(true)
        } catch {
            result(FlutterError(
                code: "INIT_ERROR",
                message: "Failed to initialize: \\(error.localizedDescription)",
                details: nil
            ))
        }
    }
    
    private func embedText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text required", details: nil))
            return
        }
        
        guard let embedder = textEmbedder else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Not initialized", details: nil))
            return
        }
        
        do {
            let embedderResult = try embedder.embed(text: text)
            if let embedding = embedderResult.embeddings.first {
                let floatArray = embedding.floatEmbedding
                result(floatArray)
            } else {
                result(FlutterError(code: "EMBED_ERROR", message: "No embedding generated", details: nil))
            }
        } catch {
            result(FlutterError(
                code: "EMBED_ERROR",
                message: "Failed to embed: \\(error.localizedDescription)",
                details: nil
            ))
        }
    }
    
    private func calculateSimilarity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text1 = args["text1"] as? String,
              let text2 = args["text2"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Both texts required", details: nil))
            return
        }
        
        guard let embedder = textEmbedder else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Not initialized", details: nil))
            return
        }
        
        do {
            let result1 = try embedder.embed(text: text1)
            let result2 = try embedder.embed(text: text2)
            
            if let embedding1 = result1.embeddings.first,
               let embedding2 = result2.embeddings.first {
                let similarity = TextEmbedder.cosineSimilarity(
                    embedding1,
                    embedding2
                )
                result(Double(similarity))
            } else {
                result(FlutterError(code: "SIMILARITY_ERROR", message: "Failed to compute", details: nil))
            }
        } catch {
            result(FlutterError(
                code: "SIMILARITY_ERROR",
                message: "Failed: \\(error.localizedDescription)",
                details: nil
            ))
        }
    }
    
    private func dispose(result: @escaping FlutterResult) {
        textEmbedder = nil
        result(true)
    }
}
```

### 3. Flutter (Dart) 実装

`lib/services/mediapipe_text_embedder_native.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';

class MediaPipeTextEmbedderNative {
  static const MethodChannel _channel = MethodChannel('mediapipe_text_embedder');
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初期化
  Future<void> initialize({String modelPath = 'universal_sentence_encoder.tflite'}) async {
    try {
      await _channel.invokeMethod('initialize', {'modelPath': modelPath});
      _isInitialized = true;
      print('✓ MediaPipe Text Embedder (Native) initialized');
    } catch (e) {
      print('✗ Failed to initialize: $e');
      rethrow;
    }
  }

  /// テキストをエンベディング
  Future<Float32List?> embed(String text) async {
    if (!_isInitialized) {
      throw StateError('Not initialized');
    }

    try {
      final result = await _channel.invokeMethod('embed', {'text': text});
      if (result is List) {
        return Float32List.fromList(result.cast<double>().map((e) => e.toDouble()).toList());
      }
      return null;
    } catch (e) {
      print('Error embedding text: $e');
      return null;
    }
  }

  /// 2つのテキストの類似度を計算
  Future<double> cosineSimilarity(String text1, String text2) async {
    if (!_isInitialized) {
      throw StateError('Not initialized');
    }

    try {
      final result = await _channel.invokeMethod('cosineSimilarity', {
        'text1': text1,
        'text2': text2,
      });
      return result as double;
    } catch (e) {
      print('Error calculating similarity: $e');
      return 0.0;
    }
  }

  /// リソースを解放
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
      _isInitialized = false;
      print('✓ MediaPipe Text Embedder disposed');
    } catch (e) {
      print('Error disposing: $e');
    }
  }
}
```

## オプション3: 現状維持（推奨）

実は、**現在の実装（TFLite + 日本語BERT）が最適**かもしれません：

### 理由：

1. **日本語に最適化**: MediaPipe の多言語モデルより日本語専用モデルの方が精度が高い
2. **実装済み**: すぐに使える
3. **シンプル**: ネイティブコード不要
4. **軽量**: 追加の依存関係なし

### 比較表

| 項目 | 現在の実装 (TFLite) | MediaPipe Native |
|------|---------------------|------------------|
| 日本語精度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 実装の複雑さ | シンプル | 複雑 |
| メンテナンス | 簡単 | 困難 |
| パフォーマンス | 高速 | 高速 |
| 多言語対応 | ❌ | ✅ |

## 結論

**現在の実装を継続することを推奨します。**

理由：
- ✅ 日本語に特化した高精度モデル使用
- ✅ すでに動作している
- ✅ シンプルで保守しやすい
- ✅ MediaPipe風のAPIで使いやすい

多言語対応が必要な場合のみ、MediaPipe Native 統合を検討してください。
