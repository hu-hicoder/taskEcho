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
        case "getModelInfo":
            getModelInfo(result: result)
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeEmbedder(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
            return
        }
        
        let modelPath = args["modelPath"] as? String ?? "universal_sentence_encoder"
        let quantize = args["quantize"] as? Bool ?? false
        
        do {
            // モデルファイルのパスを取得
            let modelAssetPath = Bundle.main.path(
                forResource: modelPath,
                ofType: "tflite"
            ) ?? ""
            
            if modelAssetPath.isEmpty {
                result(FlutterError(
                    code: "MODEL_NOT_FOUND",
                    message: "Model file not found: \(modelPath).tflite",
                    details: nil
                ))
                return
            }
            
            // TextEmbedder のオプションを設定
            let options = TextEmbedderOptions()
            options.baseOptions.modelAssetPath = modelAssetPath
            options.quantize = quantize
            
            // TextEmbedder を作成
            textEmbedder = try TextEmbedder(options: options)
            
            result([
                "success": true,
                "message": "MediaPipe TextEmbedder initialized successfully"
            ])
        } catch {
            result(FlutterError(
                code: "INIT_ERROR",
                message: "Failed to initialize: \(error.localizedDescription)",
                details: "\(error)"
            ))
        }
    }
    
    private func embedText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text is required", details: nil))
            return
        }
        
        if text.isEmpty {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Text cannot be empty", details: nil))
            return
        }
        
        guard let embedder = textEmbedder else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "TextEmbedder not initialized. Call initialize() first.", details: nil))
            return
        }
        
        do {
            // テキストをエンベディング
            let embedderResult = try embedder.embed(text: text)
            
            guard let embedding = embedderResult.embeddings.first else {
                result(FlutterError(code: "EMBED_ERROR", message: "No embedding generated", details: nil))
                return
            }
            
            // Float配列として返す
            let floatArray: [Float]
            if let quantizedEmbedding = embedding.quantizedEmbedding {
                // Quantized embedding
                floatArray = quantizedEmbedding.map { Float($0) }
            } else {
                // Float embedding
                floatArray = embedding.floatEmbedding
            }
            
            result(floatArray)
            
        } catch {
            result(FlutterError(
                code: "EMBED_ERROR",
                message: "Failed to embed text: \(error.localizedDescription)",
                details: "\(error)"
            ))
        }
    }
    
    private func calculateSimilarity(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text1 = args["text1"] as? String,
              let text2 = args["text2"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Both texts are required", details: nil))
            return
        }
        
        guard let embedder = textEmbedder else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "TextEmbedder not initialized", details: nil))
            return
        }
        
        do {
            // 両方のテキストをエンベディング
            let result1 = try embedder.embed(text: text1)
            let result2 = try embedder.embed(text: text2)
            
            guard let embedding1 = result1.embeddings.first,
                  let embedding2 = result2.embeddings.first else {
                result(FlutterError(code: "EMBED_ERROR", message: "Failed to generate embeddings", details: nil))
                return
            }
            
            // コサイン類似度を計算
            let similarity = TextEmbedder.cosineSimilarity(
                embedding1,
                embedding2
            )
            
            result(Double(similarity))
            
        } catch {
            result(FlutterError(
                code: "SIMILARITY_ERROR",
                message: "Failed to calculate similarity: \(error.localizedDescription)",
                details: "\(error)"
            ))
        }
    }
    
    private func getModelInfo(result: @escaping FlutterResult) {
        guard textEmbedder != nil else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "TextEmbedder not initialized", details: nil))
            return
        }
        
        let info: [String: Any] = [
            "initialized": true,
            "platform": "iOS",
            "mediapipe_version": "0.10.14"
        ]
        
        result(info)
    }
    
    private func dispose(result: @escaping FlutterResult) {
        textEmbedder = nil
        result(true)
    }
}
