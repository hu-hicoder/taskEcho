import 'dart:html'; // dart:htmlをインポート
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert'; // Base64エンコーディングに必要
import 'package:googleapis/speech/v1.dart' as speech;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data'; // Uint8Listのために追加

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MediaStream? _localStream;
  MediaRecorder? _mediaRecorder;
  List<int> _audioChunks = [];

  @override
  void initState() {
    super.initState();
    _getUserMedia();
  }

  // マイクからの音声を取得
  Future<void> _getUserMedia() async {
    try {
      var stream =
          await window.navigator.mediaDevices!.getUserMedia({'audio': true});
      _localStream = stream;
      print("マイクから音声を取得しました！");
    } catch (e) {
      print("マイク入力エラー: $e");
    }
  }

  // 録音を開始
  void _startRecording() {
    if (_localStream != null) {
      _mediaRecorder = MediaRecorder(_localStream!);
      _mediaRecorder!.start();

      _mediaRecorder!.addEventListener('dataavailable', (event) {
        BlobEvent blobEvent = event as BlobEvent;
        Blob blob = blobEvent.data!;

        // FileReaderを使ってBlobデータを読み込む
        FileReader reader = FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoadEnd.listen((event) {
          if (reader.result != null) {
            Uint8List audioData = reader.result as Uint8List;
            _audioChunks.addAll(audioData);
          } else {
            print("Error: reader.result is null");
          }
        });
      });

      _mediaRecorder!.addEventListener('stop', (event) {
        print("録音が停止しました。");
        _sendAudioToAPI();
      });

      print("録音を開始しました！");
    }
  }

  // 録音を停止
  void _stopRecording() {
    if (_mediaRecorder != null) {
      _mediaRecorder!.stop();
      _mediaRecorder = null;
    }
  }

  Future<auth.AutoRefreshingAuthClient> getAuthClient() async {
    // JSONファイルの読み込み
    String jsonString =
        await rootBundle.loadString('assets/service_account.json');
    var jsonMap = json.decode(jsonString);

    // 認証情報を取得
    var accountCredentials = auth.ServiceAccountCredentials.fromJson(jsonMap);
    var scopes = [speech.SpeechApi.cloudPlatformScope];

    // 認証クライアントを取得
    var client = await auth.clientViaServiceAccount(accountCredentials, scopes);
    return client;
  }

  // 録音したデータをGoogle Speech-to-Text APIに送信
  Future<void> _sendAudioToAPI() async {
    print("音声データをAPIに送信します...");

    // 認証クライアントを取得
    var client = await getAuthClient();

    // Speech APIのインスタンスを作成
    var speechApi = speech.SpeechApi(client);

    // 録音データをBase64にエンコード
    String base64Audio = base64Encode(_audioChunks);

    // 音声認識リクエストの設定
    var request = speech.LongRunningRecognizeRequest.fromJson({
      'config': {
        'encoding': 'WEBM_OPUS', // 録音フォーマットに応じてエンコーディングを変更
        'sampleRateHertz': 48000, // サンプルレートを48000Hzに変更
        'languageCode': 'ja-JP', // 言語を日本語に設定
      },
      'audio': {
        'content': base64Audio,
      },
    });

    // APIにリクエストを送信
    try {
      var operation = await speechApi.speech.longrunningrecognize(request);

      // operation.name が null でないか確認
      if (operation.name != null) {
        var operationName = operation.name!;
        speech.Operation completedOperation;

        do {
          print("処理中...");
          await Future.delayed(Duration(seconds: 5)); // 数秒待機
          completedOperation = await speechApi.operations.get(operationName);
        } while (!completedOperation.done!);

        // 操作が完了したらレスポンスを解析
        if (completedOperation.done! && completedOperation.response != null) {
          var responseData =
              completedOperation.response as Map<String, dynamic>;

          // 音声認識結果を解析
          if (responseData.containsKey('results')) {
            var results = responseData['results'] as List<dynamic>;

            if (results.isNotEmpty) {
              var alternatives = results.first['alternatives'] as List<dynamic>;
              if (alternatives.isNotEmpty) {
                var transcript = alternatives.first['transcript'];
                print('認識結果: $transcript');
              } else {
                print("音声認識結果なし");
              }
            }
          } else {
            print("結果がありません。");
          }
        } else {
          print("エラーが発生しました: 完了したが結果なし");
        }
      } else {
        print("エラー: operation.name が null です");
      }
    } catch (e) {
      print("エラーが発生しました: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('マイク録音テスト')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startRecording,
                child: Text('録音を開始'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _stopRecording,
                child: Text('録音を停止'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
