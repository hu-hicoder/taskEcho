#!/usr/bin/env python3
"""
sonoisa/sentence-bert-base-ja-cased-all-MiniLM-L6-v2 モデルの
詳細情報を確認し、TFLite に変換するスクリプト
"""

import os
import sys

print("=" * 70)
print("日本語 Sentence-BERT モデルの準備")
print("=" * 70)

# 必要なパッケージの確認
try:
    from transformers import AutoTokenizer, AutoModel
    import torch
    print("✓ transformers がインストールされています")
except ImportError:
    print("✗ transformers がインストールされていません")
    print("\n次のコマンドでインストールしてください:")
    print("  pip install transformers torch")
    sys.exit(1)

try:
    import tensorflow as tf
    print("✓ tensorflow がインストールされています")
except ImportError:
    print("✗ tensorflow がインストールされていません")
    sys.exit(1)

print("\n" + "=" * 70)
print("ステップ 1: モデルとトークナイザーのダウンロード")
print("=" * 70)

model_name = "sonoisa/sentence-bert-base-ja-mean-tokens-v2"

try:
    # トークナイザーのロード
    print(f"トークナイザーをダウンロード中: {model_name}")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    print("✓ トークナイザーのダウンロード完了")
    
    # モデルのロード
    print(f"モデルをダウンロード中: {model_name}")
    model = AutoModel.from_pretrained(model_name)
    print("✓ モデルのダウンロード完了")
    
except Exception as e:
    print(f"✗ ダウンロードエラー: {e}")
    sys.exit(1)

print("\n" + "=" * 70)
print("ステップ 2: モデルとトークナイザーの情報")
print("=" * 70)

# トークナイザー情報
print("\n【トークナイザー情報】")
print(f"語彙サイズ: {tokenizer.vocab_size}")
print(f"最大長: {tokenizer.model_max_length}")
print(f"パディングトークン: {tokenizer.pad_token}")
print(f"特殊トークン: {tokenizer.special_tokens_map}")

# トークナイザーの保存
tokenizer_dir = "../assets/tokenizer/sentence_bert_ja"
os.makedirs(tokenizer_dir, exist_ok=True)
tokenizer.save_pretrained(tokenizer_dir)
print(f"\nトークナイザーを保存: {tokenizer_dir}")

# サンプルテキストでテスト
print("\n【トークナイズのテスト】")
test_texts = [
    "こんにちは、世界",
    "タスクを追加する",
    "会議の予定を確認"
]

for text in test_texts:
    tokens = tokenizer.tokenize(text)
    token_ids = tokenizer.encode(text, add_special_tokens=True)
    print(f"\nテキスト: '{text}'")
    print(f"  トークン: {tokens}")
    print(f"  トークンID: {token_ids}")
    print(f"  トークン数: {len(token_ids)}")

# モデル情報
print("\n【モデル情報】")
print(f"モデルタイプ: {type(model).__name__}")
print(f"隠れ層のサイズ: {model.config.hidden_size}")
print(f"レイヤー数: {model.config.num_hidden_layers}")
print(f"アテンションヘッド数: {model.config.num_attention_heads}")

# 推論テスト
print("\n" + "=" * 70)
print("ステップ 3: 推論テスト")
print("=" * 70)

def mean_pooling(model_output, attention_mask):
    """Mean Pooling - モデル出力の平均を取る"""
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

# サンプルテキストでエンベディング
sample_text = "これはテストです"
print(f"サンプルテキスト: '{sample_text}'")

# トークナイズ
encoded_input = tokenizer([sample_text], padding=True, truncation=True, return_tensors='pt')
print(f"入力形状: {encoded_input['input_ids'].shape}")

# モデル実行
with torch.no_grad():
    model_output = model(**encoded_input)

# Mean Pooling
sentence_embeddings = mean_pooling(model_output, encoded_input['attention_mask'])
print(f"エンベディング形状: {sentence_embeddings.shape}")
print(f"エンベディング次元: {sentence_embeddings.shape[1]}")

print("\n" + "=" * 70)
print("ステップ 4: TFLite への変換")
print("=" * 70)

print("\nPyTorch モデルを TFLite に変換中...")
print("注意: この変換は複雑で、いくつかの手順が必要です")

try:
    # PyTorch -> ONNX -> TensorFlow -> TFLite の変換が必要
    print("\n変換には以下のステップが必要です:")
    print("1. PyTorch -> ONNX")
    print("2. ONNX -> TensorFlow")
    print("3. TensorFlow -> TFLite")
    print("\nこれには追加のパッケージ（onnx, onnx-tf）が必要です")
    
    # まずは ONNX への変換を試みる
    try:
        import onnx
        print("✓ onnx パッケージがインストールされています")
        
        onnx_path = "../assets/models/sentence_bert_ja.onnx"
        
        # ダミー入力を作成
        dummy_input = {
            'input_ids': torch.randint(0, tokenizer.vocab_size, (1, 128)),
            'attention_mask': torch.ones((1, 128), dtype=torch.long),
            'token_type_ids': torch.zeros((1, 128), dtype=torch.long)
        }
        
        print(f"\nONNX への変換を試みています...")
        torch.onnx.export(
            model,
            (dummy_input['input_ids'], dummy_input['attention_mask'], dummy_input['token_type_ids']),
            onnx_path,
            input_names=['input_ids', 'attention_mask', 'token_type_ids'],
            output_names=['output'],
            dynamic_axes={
                'input_ids': {0: 'batch', 1: 'sequence'},
                'attention_mask': {0: 'batch', 1: 'sequence'},
                'token_type_ids': {0: 'batch', 1: 'sequence'},
                'output': {0: 'batch', 1: 'sequence'}
            },
            opset_version=12
        )
        print(f"✓ ONNX モデルを保存: {onnx_path}")
        
    except ImportError:
        print("\n⚠️ onnx パッケージがインストールされていません")
        print("  pip install onnx onnx-tf")
    except Exception as e:
        print(f"\n⚠️ ONNX への変換に失敗: {e}")

except Exception as e:
    print(f"\n✗ エラー: {e}")

print("\n" + "=" * 70)
print("完了")
print("=" * 70)
print("\n次のステップ:")
print("1. トークナイザーファイルを Flutter アプリにコピー")
print("2. Dart でトークナイザーを実装")
print("3. モデルの変換方法を決定:")
print("   - オプションA: ONNX経由でTFLiteに変換")
print("   - オプションB: バックエンド(Python)で推論")
print("   - オプションC: ONNX Runtime を Flutter で使用")
