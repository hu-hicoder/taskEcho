import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'basePage.dart';
import '../providers/classProvider.dart';
import '../providers/recognitionProvider.dart';
import '../providers/keywordProvider.dart';
import '../dialogs/settingDialog.dart';
import '../services/voiceRecognitionUIService.dart';
import '../widgets/voiceRecognitionWidgets.dart';
import '/auth/googleSignIn.dart';
import 'signIn.dart';

class VoiceRecognitionPage extends StatefulWidget {
  @override
  _VoiceRecognitionPageState createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends State<VoiceRecognitionPage> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceRecognitionUIService(),
      child: Consumer<VoiceRecognitionUIService>(
        builder: (context, uiService, child) {
          final double cardHeight = MediaQuery.of(context).size.height / 6;
          final recognitionProvider = Provider.of<RecognitionProvider>(context);
          final keywordProvider = Provider.of<KeywordProvider>(context);
          final classProvider = Provider.of<ClassProvider>(context);

          return Scaffold(
            appBar: AppBar(
              title: Text('TaskEcho'),
              actions: [
                IconButton(
                  icon: Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    await GoogleAuth.signOut();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => SignInPage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
            body: BasePage(
              body: Stack(
                children: [
                  VoiceRecognitionWidgets.buildBackground(
                    showGradient: uiService.showGradient,
                    backgroundColor: uiService.backgroundColor,
                    child: SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 40),
                              // 認識結果を表示するカード
                              VoiceRecognitionWidgets.buildRecognitionCard(
                                context: context,
                                recognizedTexts: uiService.recognizedTexts,
                                summarizedTexts: uiService.summarizedTexts,
                                cardHeight: cardHeight,
                              ),
                              SizedBox(height: 20),
                              // 録音開始/停止ボタン
                              VoiceRecognitionWidgets.buildRecordingButton(
                                context: context,
                                isRecognizing:
                                    recognitionProvider.isRecognizing,
                                onPressed: () {
                                  if (recognitionProvider.isRecognizing) {
                                    uiService.stopRecording(context);
                                  } else {
                                    uiService.startRecording(context);
                                  }
                                },
                              ),
                              SizedBox(height: 20),
                              // キーワード表示
                              VoiceRecognitionWidgets.buildKeywordContainer(
                                context: context,
                                keyword: uiService.keyword,
                                keywordProvider: keywordProvider,
                                existKeyword:
                                    uiService.existKeyword, // キーワード存在フラグを追加
                              ),
                              SizedBox(height: 20),
                              // クラス選択ドロップダウン
                              VoiceRecognitionWidgets.buildClassDropdown(
                                context: context,
                                classProvider: classProvider,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 設定ボタンをStackの中に配置
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: VoiceRecognitionWidgets.buildSettingsButton(
                      context: context,
                      onPressed: () {
                        showSettingsDialog(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
