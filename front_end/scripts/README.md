# モデルダウンロードスクリプト

このディレクトリには、Universal Sentence Encoder モデルをダウンロードして TFLite 形式に変換するスクリプトが含まれています。

## 前提条件

- Python 3.8 以上
- pip (Pythonパッケージマネージャー)

## セットアップと実行手順

### 1. 必要なパッケージのインストール

```bash
cd front_end/scripts
pip install -r requirements.txt
```

または、個別にインストール:

```bash
pip install kagglehub tensorflow numpy
```

### 2. モデルのダウンロードと変換

```bash
python download_model.py
```

このスクリプトは以下を実行します:
1. Kaggle から Universal Sentence Encoder (Multilingual QA) モデルをダウンロード
2. TensorFlow SavedModel 形式から TFLite 形式に変換
3. `assets/models/` ディレクトリに保存

### 3. 出力

成功すると、以下のファイルが生成されます:
- `../assets/models/universal_sentence_encoder_multilingual.tflite`

モデルサイズ: 約 90-100 MB

## トラブルシューティング

### エラー: "kagglehub not found"

```bash
pip install --upgrade kagglehub
```

### エラー: "tensorflow not found"

```bash
pip install --upgrade tensorflow
```

### エラー: Kaggle 認証エラー

初回実行時、Kaggle API の認証が必要な場合があります:

1. [Kaggle](https://www.kaggle.com/) にログイン
2. Account → API → "Create New API Token" をクリック
3. `kaggle.json` ファイルをダウンロード
4. ファイルを適切な場所に配置:
   - Linux/Mac: `~/.kaggle/kaggle.json`
   - Windows: `C:\Users\<username>\.kaggle\kaggle.json`

### メモリ不足エラー

TensorFlow の変換にはメモリが必要です（推奨: 8GB 以上の RAM）

## モデル情報

- **モデル名**: Universal Sentence Encoder - Multilingual QA
- **提供元**: Google Research
- **対応言語**: 100以上の言語（日本語含む）
- **用途**: テキストの意味的類似度検索
- **入力**: 文字列（可変長）
- **出力**: 512次元のベクトル

## 参考リンク

- [Kaggle Model Hub](https://www.kaggle.com/models/google/universal-sentence-encoder)
- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [Universal Sentence Encoder (TensorFlow Hub)](https://tfhub.dev/google/universal-sentence-encoder-multilingual-qa/3)
