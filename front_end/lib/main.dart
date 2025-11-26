import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'auth/googleSignIn.dart'; // 未使用のため削除
import 'pages/signIn.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speech_to_text/pages/voiceRecognitionPage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart'; // providerをインポート
import 'providers/mordalProvider.dart';
import 'providers/classProvider.dart';
import 'providers/keywordProvider.dart';
import 'providers/textsDataProvider.dart';
import 'providers/recognitionProvider.dart';
import 'providers/calendar_inbox_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'services/notification_service.dart';

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
      // home: kIsWeb ? const LandingPage() : AuthWrapper(),
      home: AuthWrapper(),
    );
  }
}

// 認証状態に応じて画面を切り替えるウィジェット
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: FirebaseAuth.instance.authStateChanges().first,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          // ログイン中はヘッダー付きメイン画面へ
          return VoiceRecognitionPage();
        } else {
          // 未ログインはタイトル画面
          return SignInPage();
        }
      },
    );
  }
}

// SQLiteの初期化関数
void _initSqlite() {
  if (kIsWeb) {
    // Webプラットフォームの場合、SQLite FFI Webを使用
    databaseFactory = databaseFactoryFfiWeb;
    print('SQLite Web initialized successfully');
  } else {
    // モバイルプラットフォームでは標準のSQLiteが使用される
    print('Using default SQLite implementation for mobile');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter のバインディングを初期化
  //await dotenv.load(fileName: ".env");
  // Web版とモバイル版で .env ファイルの読み込み方を分ける
  if (kIsWeb) {
    try {
      // Web版: .envファイルのパスを明示的に指定
      await dotenv.load(fileName: ".env");
      print('✅ .env file loaded successfully (Web)');
      
      // APIキーが正しく読み込まれたか確認
      final geminiKey = dotenv.env['GEMINI_API_KEY'];
      final googleClientId = dotenv.env['GOOGLE_CLIENT_ID'];
      
      if (geminiKey == null || geminiKey.isEmpty) {
        print('❌ Error: GEMINI_API_KEY is missing.');
      } else {
        print('✅ GEMINI_API_KEY loaded: ${geminiKey.substring(0, 10)}...');
      }
      
      if (googleClientId == null || googleClientId.isEmpty) {
        print('⚠️ Warning: GOOGLE_CLIENT_ID is missing.');
      } else {
        print('✅ GOOGLE_CLIENT_ID loaded: ${googleClientId.substring(0, 20)}...');
      }
    } catch (e) {
      print('❌ Error loading .env file (Web): $e');
      // エラーが発生しても続行（APIキーが必要な機能は動作しない）
    }
  } else {
    // Android/iOS版: assetsフォルダから読み込む
    try {
      await dotenv.load(fileName: "assets/.env");
      print('✅ .env file loaded successfully (Mobile)');
    } catch (e) {
      print('❌ Error loading .env file (Mobile): $e');
    }
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, skipping...');
    } else {
      print('Firebase initialization error: $e');
      rethrow;
    }
  }

  // ローカル通知初期化(Android)
  await NotificationService.init();

  // SQLiteの初期化
  try {
    _initSqlite();
  } catch (e) {
    print('SQLite initialization error: $e');
    // エラーが発生しても続行（SharedPreferencesにフォールバックする可能性）
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ClassProvider()),
        ChangeNotifierProvider(create: (context) => ModalProvider()),
        ChangeNotifierProvider(create: (_) => TextsDataProvider()),
        ChangeNotifierProvider(create: (_) => RecognitionProvider()),
        ChangeNotifierProvider(create: (_) => KeywordProvider()),
        ChangeNotifierProvider(create: (_) => CalendarInboxProvider()),
      ],
      child: SpeechToTextApp(),
    ),
  );
}

// import 'package:flutter/material.dart';
// import 'package:speech_to_text_ultra/speech_to_text_ultra.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false, // デバッグバナーを非表示
//       title: 'Speech To Text Ultra',
//       theme: ThemeData(primarySwatch: Colors.teal),
//       home: const SpeechToTextScreen(),
//     );
//   }
// }

// class SpeechToTextScreen extends StatefulWidget {
//   const SpeechToTextScreen({super.key});

//   @override
//   _SpeechToTextScreenState createState() => _SpeechToTextScreenState();
// }

// class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
//   bool mIsListening = false;
//   String mEntireResponse = '';
//   String mLiveResponse = '';

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.teal,
//         centerTitle: true,
//         title: const Text(
//           'Speech To Text Ultra',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
//         ),
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Text(
//                   mIsListening ? mLiveResponse : mEntireResponse,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
//                 ),
//               ),

//               const SizedBox(height: 20),
//               SpeechToTextUltra(
//                 ultraCallback: (String liveText, String finalText, bool isListening) {
//                   setState(() {
//                     if (!isListening) {
//                       // finalTextが空なら、liveTextをmEntireResponseにセット
//                       if (finalText.isNotEmpty) {
//                         mEntireResponse = finalText;
//                       } else if (liveText.isNotEmpty) {
//                         mEntireResponse = liveText;
//                       }
//                     } else {
//                       // リアルタイムのテキストを更新
//                       mLiveResponse = liveText;
//                     }
//                     mIsListening = isListening;

//                     // ターミナルにデバッグ情報を表示
//                     print("----- SpeechToTextUltra Callback -----");
//                     print("isListening: $mIsListening");
//                     print("liveText: $mLiveResponse");
//                     print("finalText: $finalText");
//                     print("mEntireResponse: $mEntireResponse");
//                     print("-------------------------------------");
//                   });
//                 },
//                 toPauseIcon: const Icon(Icons.pause_circle, size: 50, color: Colors.red),
//                 toStartIcon: const Icon(Icons.mic, size: 50, color: Colors.green),
//               ),
//               const SizedBox(height: 10),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
