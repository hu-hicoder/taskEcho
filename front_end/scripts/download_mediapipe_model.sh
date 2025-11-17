#!/bin/bash

# MediaPipe Universal Sentence Encoder モデルをダウンロード

MODEL_URL="https://storage.googleapis.com/mediapipe-models/text_embedder/universal_sentence_encoder/float32/latest/universal_sentence_encoder.tflite"
MODEL_DIR="../assets/models"
MODEL_FILE="$MODEL_DIR/universal_sentence_encoder.tflite"

echo "📥 Downloading MediaPipe Universal Sentence Encoder model..."
echo "URL: $MODEL_URL"
echo "Destination: $MODEL_FILE"

# ディレクトリが存在しない場合は作成
mkdir -p "$MODEL_DIR"

# モデルをダウンロード
if command -v curl &> /dev/null; then
    curl -L "$MODEL_URL" -o "$MODEL_FILE"
elif command -v wget &> /dev/null; then
    wget "$MODEL_URL" -O "$MODEL_FILE"
else
    echo "❌ Error: curl or wget is required to download the model"
    exit 1
fi

# ダウンロード成功を確認
if [ -f "$MODEL_FILE" ]; then
    FILE_SIZE=$(ls -lh "$MODEL_FILE" | awk '{print $5}')
    echo "✅ Model downloaded successfully!"
    echo "📊 File size: $FILE_SIZE"
    echo "📁 Location: $MODEL_FILE"
else
    echo "❌ Error: Failed to download model"
    exit 1
fi

echo ""
echo "🎉 Setup complete! You can now use MediaPipe Text Embedder."
