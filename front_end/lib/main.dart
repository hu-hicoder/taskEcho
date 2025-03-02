import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_vosk/pages/basePage.dart';
import 'package:flutter_vosk/pages/voiceRecognitionPage.dart'; // VoiceRecognitionPage をインポート
import 'package:flutter_vosk/providers/recognitionProvider.dart';
import 'providers/mordalProvider.dart';
import 'providers/classProvider.dart';
import 'providers/textsDataProvider.dart';


Future<void> _requestPermissions() async {
  var status = await Permission.microphone.status;
  if (!status.isGranted) {
    await Permission.microphone.request();
  }
}

class SpeechToTextApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'taskEcho',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: Color(0xFF0F0F1F), // ダークテーマ背景色
      ),
      home: VoiceRecognitionPage(),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter のバインディングを初期化
  await _requestPermissions();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ClassProvider()),
        ChangeNotifierProvider(create: (context) => ModalProvider()),
        ChangeNotifierProvider(create: (_) => TextsDataProvider()),
        ChangeNotifierProvider(create: (_) => RecognitionProvider()),
      ],
      child: SpeechToTextApp(),
    ),
  );
}