package com.example.front_end

import android.content.Context
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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
                    val quantize = call.argument<Boolean>("quantize") ?: false
                    
                    // BaseOptions の設定
                    val baseOptionsBuilder = BaseOptions.builder()
                    
                    if (modelPath != null && modelPath.isNotEmpty()) {
                        // カスタムモデルを使用
                        baseOptionsBuilder.setModelAssetPath(modelPath)
                    } else {
                        // デフォルトモデルを使用
                        baseOptionsBuilder.setModelAssetPath("universal_sentence_encoder.tflite")
                    }
                    
                    val baseOptions = baseOptionsBuilder.build()

                    // TextEmbedder の作成
                    val options = TextEmbedder.TextEmbedderOptions.builder()
                        .setBaseOptions(baseOptions)
                        .setQuantize(quantize)
                        .build()

                    textEmbedder = TextEmbedder.createFromOptions(context, options)
                    
                    result.success(mapOf(
                        "success" to true,
                        "message" to "MediaPipe TextEmbedder initialized successfully"
                    ))
                } catch (e: Exception) {
                    result.error("INIT_ERROR", "Failed to initialize: ${e.message}", e.stackTraceToString())
                }
            }

            "embed" -> {
                try {
                    val text = call.argument<String>("text")
                    if (text == null || text.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "Text is required and cannot be empty", null)
                        return
                    }

                    if (textEmbedder == null) {
                        result.error("NOT_INITIALIZED", "TextEmbedder not initialized. Call initialize() first.", null)
                        return
                    }

                    // テキストをエンベディング
                    val embedderResult = textEmbedder!!.embed(text)
                    
                    if (embedderResult.embeddingResult().embeddings().isEmpty()) {
                        result.error("EMBED_ERROR", "No embeddings generated", null)
                        return
                    }
                    
                    val embedding = embedderResult.embeddingResult().embeddings()[0]
                    
                    // Float配列として返す
                    val floatArray = if (embedding.quantizedEmbedding() != null) {
                        // Quantized embedding
                        val quantized = embedding.quantizedEmbedding()
                        FloatArray(quantized.size) { i -> quantized[i].toFloat() }
                    } else {
                        // Float embedding
                        embedding.floatEmbedding()
                    }
                    
                    result.success(floatArray.toList())

                } catch (e: Exception) {
                    result.error("EMBED_ERROR", "Failed to embed text: ${e.message}", e.stackTraceToString())
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

                    if (result1.embeddingResult().embeddings().isEmpty() || result2.embeddingResult().embeddings().isEmpty()) {
                        result.error("EMBED_ERROR", "Failed to generate embeddings", null)
                        return
                    }

                    // コサイン類似度を計算
                    val similarity = TextEmbedder.cosineSimilarity(
                        result1.embeddingResult().embeddings()[0],
                        result2.embeddingResult().embeddings()[0]
                    )

                    result.success(similarity.toDouble())

                } catch (e: Exception) {
                    result.error("SIMILARITY_ERROR", "Failed to calculate similarity: ${e.message}", e.stackTraceToString())
                }
            }

            "getModelInfo" -> {
                try {
                    if (textEmbedder == null) {
                        result.error("NOT_INITIALIZED", "TextEmbedder not initialized", null)
                        return
                    }

                    // モデル情報を返す
                    val info = mapOf(
                        "initialized" to true,
                        "platform" to "Android",
                        "mediapipe_version" to "0.10.14"
                    )
                    result.success(info)
                } catch (e: Exception) {
                    result.error("INFO_ERROR", "Failed to get model info: ${e.message}", null)
                }
            }

            "dispose" -> {
                try {
                    textEmbedder?.close()
                    textEmbedder = null
                    result.success(true)
                } catch (e: Exception) {
                    result.error("DISPOSE_ERROR", "Failed to dispose: ${e.message}", null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        textEmbedder?.close()
        textEmbedder = null
    }
}
