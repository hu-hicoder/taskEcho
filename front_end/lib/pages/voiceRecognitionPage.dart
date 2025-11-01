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

  // セマンティック検索のクイック設定ウィジェット
  Widget _buildQuickSettings(KeywordProvider keywordProvider) {
    final isInitialized = keywordProvider.isSemanticSearchInitialized;
    
    return Card(
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(
          isInitialized ? Icons.check_circle : Icons.warning_amber,
          color: isInitialized ? Colors.green : Colors.orange,
        ),
        title: const Text(
          'キーワード検出設定',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          isInitialized 
              ? _getDetectionModeLabel(keywordProvider.detectionMode)
              : 'セマンティック検索: 初期化待機中',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // セマンティック検索が初期化されていない場合の警告
                if (!isInitialized) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                             color: Colors.orange.shade700, 
                             size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'セマンティック検索モデルが読み込まれていません。\n完全一致のみで動作します。',
                            style: TextStyle(
                              fontSize: 12, 
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // 検出モード選択
                const Text(
                  '検出モード',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'exact',
                        label: Text('完全', style: TextStyle(fontSize: 11))),
                    ButtonSegment(
                        value: 'hybrid',
                        label: Text('両方', style: TextStyle(fontSize: 11))),
                    ButtonSegment(
                        value: 'semantic',
                        label: Text('意味', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {keywordProvider.detectionMode},
                  onSelectionChanged: (Set<String> selected) {
                    final newMode = selected.first;
                    
                    // セマンティック検索が必要なモードで、初期化されていない場合
                    if ((newMode == 'semantic' || newMode == 'hybrid') && 
                        !isInitialized) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'セマンティック検索モデルが利用できません。\n完全一致モードを使用してください。'
                          ),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      return;
                    }
                    
                    keywordProvider.setDetectionMode(newMode);
                  },
                ),
                const SizedBox(height: 12),

                // 類似度閾値（セマンティック検索有効時のみ）
                if (keywordProvider.detectionMode != 'exact') ...[
                  Text(
                    '類似度: ${(keywordProvider.similarityThreshold * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: keywordProvider.similarityThreshold,
                    min: 0.5,
                    max: 0.95,
                    divisions: 9,
                    label: '${(keywordProvider.similarityThreshold * 100).toStringAsFixed(0)}%',
                    onChanged: (value) {
                      keywordProvider.setSimilarityThreshold(value);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDetectionModeLabel(String mode) {
    switch (mode) {
      case 'exact':
        return '完全一致のみ';
      case 'semantic':
        return '意味的検索のみ';
      case 'hybrid':
        return 'ハイブリッド（推奨）';
      default:
        return mode;
    }
  }

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
                        const SizedBox(height: 20),

                        // セマンティック検索設定（コンパクト版）
                        _buildQuickSettings(keywordProvider),
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
