import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// モデルの入出力情報を確認するためのテスト
/// 実際のアプリ実行環境でのみ動作します
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('モデルの入出力情報を取得', () async {
    try {
      print('=== モデル情報の取得開始 ===');
      
      final interpreter = await Interpreter.fromAsset(
        'assets/models/universal_sentence_encoder_multilingual.tflite',
      );

      print('\n--- 入力テンソル情報 ---');
      final inputTensors = interpreter.getInputTensors();
      for (var i = 0; i < inputTensors.length; i++) {
        final tensor = inputTensors[i];
        print('入力[$i]:');
        print('  名前: ${tensor.name}');
        print('  型: ${tensor.type}');
        print('  形状: ${tensor.shape}');
        print('  量子化パラメータ: ${tensor.params}');
      }

      print('\n--- 出力テンソル情報 ---');
      final outputTensors = interpreter.getOutputTensors();
      for (var i = 0; i < outputTensors.length; i++) {
        final tensor = outputTensors[i];
        print('出力[$i]:');
        print('  名前: ${tensor.name}');
        print('  型: ${tensor.type}');
        print('  形状: ${tensor.shape}');
        print('  量子化パラメータ: ${tensor.params}');
      }

      print('\n=== モデル情報の取得完了 ===');
      
      interpreter.close();
    } catch (e, stackTrace) {
      print('❌ エラー: $e');
      print('スタックトレース: $stackTrace');
    }
  });
}
