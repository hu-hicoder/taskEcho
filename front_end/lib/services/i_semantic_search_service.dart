import 'dart:typed_data';

/// セマンティック検索サービスの共通インターフェース
/// 
/// このインターフェースを実装することで、異なるモデル（多言語モデル、日本語専用モデルなど）を
/// 統一的に扱うことができます。
abstract class ISemanticSearchService {
  /// サービスが初期化済みかどうか
  bool get isInitialized;

  /// モデルの初期化
  Future<void> initialize();

  /// リソースの解放
  void dispose();

  /// テキストをベクトルに変換
  /// 
  /// [text] エンコードするテキスト
  /// 戻り値: テキストのベクトル表現（Float32List）
  Future<Float32List?> encodeText(String text);

  /// 2つのベクトル間のコサイン類似度を計算
  /// 
  /// [vector1] 最初のベクトル
  /// [vector2] 2番目のベクトル
  /// 戻り値: 類似度スコア（-1.0 ~ 1.0、1.0が最も類似）
  double calculateCosineSimilarity(Float32List vector1, Float32List vector2);

  /// 検索キーワードとタスクテキストの類似度を計算
  /// 
  /// [searchKeyword] 検索キーワード
  /// [taskText] タスクのテキスト
  /// 戻り値: 類似度スコア（0.0 ~ 1.0）
  Future<double?> calculateSimilarity(String searchKeyword, String taskText);
  
  /// モデルの情報を出力（デバッグ用）
  void printModelInfo();
}
