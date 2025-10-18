import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/classProvider.dart';
import '../providers/recognitionProvider.dart';
import '../providers/keywordProvider.dart';
import '../services/voiceRecognitionUIService.dart';
import '../widgets/voiceRecognitionWidgets.dart';
import '../models/calendar_event_proposal.dart';
import '/auth/googleSignIn.dart';
import 'signIn.dart';
import 'keywordHistoryPage.dart';

class VoiceRecognitionPage extends StatefulWidget {
  @override
  _VoiceRecognitionPageState createState() => _VoiceRecognitionPageState();
}

class _VoiceRecognitionPageState extends State<VoiceRecognitionPage> {
  CalendarEventProposal? _lastProposal;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceRecognitionUIService(),
      child: Consumer<VoiceRecognitionUIService>(
        builder: (context, uiService, child) {
          final recognitionProvider = Provider.of<RecognitionProvider>(context);
          final keywordProvider = Provider.of<KeywordProvider>(context);
          final classProvider = Provider.of<ClassProvider>(context);

          // カレンダーイベント提案が新しく来たらボトムシートを表示
          final currentProposal = uiService.pendingEventProposal;
          if (currentProposal != null && currentProposal != _lastProposal) {
            _lastProposal = currentProposal;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              VoiceRecognitionWidgets.showCalendarEventBottomSheet(
                context: context,
                proposal: currentProposal,
                uiService: uiService,
                onConfirm: (CalendarEventProposal updatedProposal) {
                  print('カレンダーに登録: ${updatedProposal.summary}');
                },
              );
            });
          } else if (currentProposal == null) {
            _lastProposal = null;
          }

          return Scaffold(
            backgroundColor:
                uiService.isFlashing ? uiService.backgroundColor : Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'TaskEcho',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.black87),
                  tooltip: 'キーワード履歴',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => KeywordHistoryPage()),
                    );
                  },
                ),
                IconButton(
                  icon:
                      const Icon(Icons.logout_outlined, color: Colors.black87),
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
            body: Stack(
              children: [
                // 背景レイヤー（グラデーションまたは点滅）
                if (!uiService.isFlashing)
                  Container(color: Colors.white)
                else
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    color: uiService.backgroundColor,
                  ),

                // コンテンツレイヤー
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // 上部：授業選択
                        VoiceRecognitionWidgets.buildClassDropdown(
                          context: context,
                          classProvider: classProvider,
                        ),
                        const SizedBox(height: 20),

                        // キーワード表示
                        VoiceRecognitionWidgets.buildKeywordContainer(
                          context: context,
                          keyword: uiService.keyword,
                          keywordProvider: keywordProvider,
                          existKeyword: uiService.existKeyword,
                        ),
                        const SizedBox(height: 40),

                        // 中央：録音ボタン（大きく、目立つように）
                        VoiceRecognitionWidgets.buildRecordingButton(
                          context: context,
                          isRecognizing: recognitionProvider.isRecognizing,
                          onPressed: () {
                            if (recognitionProvider.isRecognizing) {
                              uiService.stopRecording(context);
                            } else {
                              uiService.startRecording(context);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // 録音状態テキスト
                        Text(
                          recognitionProvider.isRecognizing
                              ? '録音中...'
                              : 'タップして録音開始',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 下部：認識結果カード
                        VoiceRecognitionWidgets.buildRecognitionCard(
                          context: context,
                          recognizedTexts: uiService.recognizedTexts,
                          // summarizedTexts: uiService.summarizedTexts,
                          cardHeight: 120,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
