// import 'package:flutter/material.dart';
// import 'package:flutter_speech_to_text/pages/voiceRecognitionPage.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:provider/provider.dart'; // providerをインポート
// import 'providers/MordalProvider.dart';
// import 'providers/classProvider.dart';
// import 'providers/textsDataProvider.dart';
// import 'providers/recognitionProvider.dart';

// class SpeechToTextApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'taskEcho',
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primarySwatch: Colors.cyan,
//         scaffoldBackgroundColor: Color(0xFF0F0F1F), // ダークテーマ背景色
//       ),
//       home: VoiceRecognitionPage(),
//     );
//   }
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized(); // Flutter のバインディングを初期化
//   //await dotenv.load(fileName: ".env");
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (context) => ClassProvider()),
//         ChangeNotifierProvider(create: (context) => ModalProvider()),
//         ChangeNotifierProvider(create: (_) => TextsDataProvider()),
//         ChangeNotifierProvider(create: (_) => RecognitionProvider()),
//       ],
//       child: SpeechToTextApp(),
//     ),
//   );
//}

import 'package:flutter/material.dart';
import 'package:speech_to_text_ultra/speech_to_text_ultra.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // デバッグバナーを非表示
      title: 'Speech To Text Ultra',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const SpeechToTextScreen(),
    );
  }
}

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  _SpeechToTextScreenState createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  bool mIsListening = false;
  String mEntireResponse = '';
  String mLiveResponse = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        centerTitle: true,
        title: const Text(
          'Speech To Text Ultra',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  mIsListening ? mLiveResponse : mEntireResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
              ),
              const SizedBox(height: 20),
              SpeechToTextUltra(
                ultraCallback: (String liveText, String finalText, bool isListening) {
                  setState(() {
                    mLiveResponse = liveText;
                    if (isListening) {
                      // 認識中はリアルタイムのテキストを更新
                      if (liveText.isNotEmpty) {
                        mEntireResponse = '$mEntireResponse $liveText'.trim();
                      }
                    } else {
                      // 認識が停止したとき、最終結果をセット
                      if (finalText.isNotEmpty) {
                        mEntireResponse = '$mEntireResponse $finalText'.trim();
                      }
                    }
                    mIsListening = isListening;
                  });
                },
                toPauseIcon: const Icon(Icons.pause_circle, size: 50, color: Colors.red),
                toStartIcon: const Icon(Icons.mic, size: 50, color: Colors.green),
                pauseIconColor: Colors.red,
                startIconColor: Colors.green,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
