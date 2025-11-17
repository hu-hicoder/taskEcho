#!/usr/bin/env python3
"""
MediaPipe 用の Universal Sentence Encoder モデルをダウンロード

このスクリプトは、MediaPipe Text Embedder で使用できる
Universal Sentence Encoder モデルをダウンロードして配置します。
"""

import os
import urllib.request
import sys

# モデルのURL（MediaPipe公式）
MODEL_URL = "https://storage.googleapis.com/mediapipe-models/text_embedder/universal_sentence_encoder/float32/1/universal_sentence_encoder.tflite"

# 保存先ディレクトリ
ASSETS_DIR = "../assets/models"
MODEL_PATH = os.path.join(ASSETS_DIR, "universal_sentence_encoder.tflite")

def download_model():
    """モデルをダウンロード"""
    # ディレクトリが存在しない場合は作成
    os.makedirs(ASSETS_DIR, exist_ok=True)
    
    # すでにファイルが存在する場合
    if os.path.exists(MODEL_PATH):
        print(f"✓ Model already exists: {MODEL_PATH}")
        file_size = os.path.getsize(MODEL_PATH) / (1024 * 1024)  # MB
        print(f"  File size: {file_size:.2f} MB")
        
        response = input("Do you want to re-download? (y/N): ")
        if response.lower() != 'y':
            print("Skipping download.")
            return
        
        print("Re-downloading...")
    
    print(f"Downloading model from: {MODEL_URL}")
    print(f"Saving to: {MODEL_PATH}")
    
    try:
        # ダウンロード
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
        
        # ファイルサイズを確認
        file_size = os.path.getsize(MODEL_PATH) / (1024 * 1024)  # MB
        print(f"✓ Download complete!")
        print(f"  File size: {file_size:.2f} MB")
        print(f"  Location: {MODEL_PATH}")
        
    except Exception as e:
        print(f"✗ Error downloading model: {e}")
        sys.exit(1)

def verify_model():
    """モデルファイルを検証"""
    if not os.path.exists(MODEL_PATH):
        print(f"✗ Model file not found: {MODEL_PATH}")
        return False
    
    file_size = os.path.getsize(MODEL_PATH)
    
    # TFLite ファイルのマジックナンバーをチェック
    with open(MODEL_PATH, 'rb') as f:
        magic = f.read(4)
        if magic == b'TFL3':
            print("✓ Valid TFLite model file")
            return True
        else:
            print("✗ Invalid TFLite file format")
            return False

def main():
    print("=" * 60)
    print("MediaPipe Universal Sentence Encoder Model Downloader")
    print("=" * 60)
    print()
    
    # モデルをダウンロード
    download_model()
    
    print()
    
    # モデルを検証
    if verify_model():
        print()
        print("=" * 60)
        print("Setup Complete!")
        print("=" * 60)
        print()
        print("Next steps:")
        print("1. Make sure the model is listed in pubspec.yaml:")
        print("   assets:")
        print("     - assets/models/universal_sentence_encoder.tflite")
        print()
        print("2. Run: flutter pub get")
        print("3. Initialize the embedder in your Dart code:")
        print("   final embedder = MediaPipeTextEmbedder();")
        print("   await embedder.initialize();")
        print()
    else:
        print()
        print("✗ Model verification failed. Please try again.")
        sys.exit(1)

if __name__ == "__main__":
    main()
