import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../auth/googleSignIn.dart';
import '../main.dart'; // AuthWrapper を使います

// StatefulWidgetに変更してスクロール制御を行う
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  // 各セクションのキーを管理
  final List<GlobalKey> _sectionKeys = List.generate(5, (_) => GlobalKey());

  // スクロールコントローラーとヘッダー表示フラグ
  final ScrollController _scrollController = ScrollController();
  bool _showAppbar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final screenHeight = MediaQuery.of(context).size.height;
    // ファーストビューの80%を過ぎたらヘッダーを表示
    final show = _scrollController.offset > screenHeight * 0.8;
    if (show != _showAppbar) {
      setState(() {
        _showAppbar = show;
      });
    }
  }

  // 指定したセクションへスクロールする関数
  void _scrollToSection(int index) {
    if (index < _sectionKeys.length && _sectionKeys[index].currentContext != null) {
      Scrollable.ensureVisible(
        _sectionKeys[index].currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  // 次のセクションへスクロールする関数
  void _scrollToNext(int currentIndex) {
    _scrollToSection(currentIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    // 画面の高さを取得して各セクションに渡す
    final screenHeight = MediaQuery.of(context).size.height;
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final paddingTop = MediaQuery.of(context).padding.top;


    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController, // コントローラーをセット
            child: Column(
              children: [
                // 1. ファーストビュー
                _buildHeroSection(
                  context, 
                  screenHeight, 
                  key: _sectionKeys[0], 
                  onNavigate: _scrollToSection,
                ),
                
                // 2. 導入
                _buildIntroductionSection(
                  context, 
                  screenHeight, 
                  key: _sectionKeys[1], 
                  onNext: () => _scrollToNext(1)
                ),

                // 3. 主な機能 + 注意点 (Web版のみ)
                _buildFeaturesAndLimitationsSection(
                  context, 
                  screenHeight, 
                  key: _sectionKeys[2], 
                  onNext: () => _scrollToNext(2)
                ),

                // 4. 使い方
                _buildHowToUseSection(
                  context, 
                  screenHeight, 
                  key: _sectionKeys[3], 
                  onNext: () => _scrollToNext(3)
                ),
                
                // 5. フッター (CTA)
                _buildFooter(
                  context, 
                  screenHeight, 
                  key: _sectionKeys[4],
                ),
              ],
            ),
          ),

          // 固定ヘッダー (スクロール時に表示)
          Positioned(
            top: 0, // 修正: bottom: 30 から top: 0 に変更して上部に固定
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showAppbar ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showAppbar, 
                child: Container(
                  height: 60 + paddingTop,
                  padding: EdgeInsets.only(
                    top: paddingTop,
                    left: 20,
                    right: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      // ロゴ (クリックでトップへ戻る)
                      InkWell(
                        onTap: () => _scrollToSection(0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 24, // voiceRecognitionPageと同じ高さ制限
                                ),
                                child: Image.asset(
                                  'assets/images/TaskEcho_lightmode.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                ),
                              ),
                            ),
                            if (kIsWeb) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orangeAccent),
                                ),
                                child: const Text(
                                  'Demo',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      // ナビゲーション (画面幅が広い場合のみ表示)
                      // if (isWideScreen) ...[
                      //   _buildHeaderNavLink('TaskEchoとは', 1),
                      //   const SizedBox(width: 16),
                      //   _buildHeaderNavLink('できること', 2),
                      //   const SizedBox(width: 16),
                      //   _buildHeaderNavLink('使い方', 3),
                      // ],
                      if (kIsWeb)
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () async {
                              final user = await GoogleAuth.signInAnonymously();
                              if (user != null && context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => AuthWrapper()),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(33, 150, 243, 0.75), 
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'はじめる',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () => _scrollToSection(0),
                          icon: Icon(Icons.arrow_upward_rounded, color: Colors.grey.shade600),
                          tooltip: 'トップへ戻る',
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ヘッダー用のナビゲーションリンク
  Widget _buildHeaderNavLink(String text, int index) {
    return TextButton(
      onPressed: () => _scrollToSection(index),
      style: TextButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  // 1. ファーストビュー
  Widget _buildHeroSection(BuildContext context, double minHeight, {required Key key, required Function(int) onNavigate}) {
    return Container(
      key: key, // キーを設定
      height: minHeight, // ここは高さを固定して全画面表示
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/TaskEcho_lightmode.png',
                  width: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 48),

                if (!kIsWeb) ...[
                  const SizedBox(height: 18),
                  // ネイティブ版
                  _buildLoginButton(
                    icon: Icons.login,
                    label: 'Sign in with Google',
                    backgroundColor: const Color.fromRGBO(33, 150, 243, 0.75),
                    onPressed: () async {
                      final user = await GoogleAuth.signInWithGoogle();
                      if (user != null && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => AuthWrapper()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildLoginButton(
                    icon: Icons.person_outline,
                    label: 'Continue as Guest',
                    backgroundColor: Colors.black54,
                    onPressed: () async {
                      final user = await GoogleAuth.signInAnonymously();
                      if (user != null && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => AuthWrapper()),
                        );
                      }
                    },
                  ),
                ] else ...[
                  // Web版
                  _buildLoginButton(
                    icon: Icons.person_outline,
                    label: 'ゲストではじめる',
                    backgroundColor: const Color.fromRGBO(33, 150, 243, 0.75),
                    onPressed: () async {
                      final user = await GoogleAuth.signInAnonymously();
                      if (user != null && context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => AuthWrapper()),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500), // 最大幅を設定して広がりすぎを防ぐ
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 各ボタンをExpandedで囲み、等幅の領域の中央に配置することで
                    // 真ん中のボタンが確実に画面中央に来るようにする
                    Expanded(
                      child: Center(
                        child: _buildNavButton('TaskEchoとは', () => onNavigate(1)),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _buildNavButton('できること', () => onNavigate(2)),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _buildNavButton('使い方', () => onNavigate(3)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // タップ領域を確保
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 修正: FittedBoxで囲み、画面幅が狭い場合にテキストを縮小してオーバーフローを防ぐ
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.grey.shade600, 
                  fontSize: 15, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400, size: 22),
          ],
        ),
      ),
    );
  }

  // 2. 導入セクション
  Widget _buildIntroductionSection(BuildContext context, double minHeight, {required Key key, required VoidCallback onNext}) {
    return Container(
      key: key, // キーを設定
      constraints: BoxConstraints(minHeight: minHeight),
      // padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      color: const Color(0xFFF9FAFB),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            alignment: Alignment.center, // 上下中央寄せ
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '授業中にこんなこと、ありませんか？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildProblemItem('課題の内容を聞き逃す'),
                      _buildProblemItem('メモをとっている間に話が進んでわからなくなる'),
                      _buildProblemItem('90分間集中が持たない'),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
                Icon(Icons.arrow_downward_rounded, color: Colors.blue.shade200, size: 32),
                const SizedBox(height: 24),

                const Text(
                  'TaskEchoは、そんな\n「今のなんだっけ？」を減らすための\nモバイルアプリです',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    height: 1.2, // 行間を広げて読みやすく
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: IconButton( // IconButtonに変更してタップしやすく
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }

  // 3. 主な機能 + 注意点 (統合セクション)
  Widget _buildFeaturesAndLimitationsSection(BuildContext context, double minHeight, {required Key key, required VoidCallback onNext}) {
    return Container(
      key: key, // キーを設定
      // constraints: BoxConstraints(minHeight: minHeight),
      // padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      color: Colors.white,
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'できること',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildFeatureItem('重要な話を聞き逃さない', '重要な話が始まったら、\n画面の点滅でお知らせ', Icons.notifications_active),
                    _buildFeatureItem('聞き逃した話を後から確認', '聞き逃したくない話を要約し、\n授業毎に分類して保存', Icons.auto_awesome),
                    _buildFeatureItem('気がそれる原因を減らす', '自動でタスクを抽出し、\n簡単にカレンダーへ予定を追加', Icons.check_circle_outline),
                    _buildFeatureItem('メモ中の聞き逃しを防止', 'Notionと連携し、\n自分のメモに要約を追加', Icons.description),
                  ],
                ),

                // Web版の場合のみ注意点を表示
                if (kIsWeb) ...[
                  const SizedBox(height: 60),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 580),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Web版はデモです。以下の機能は利用できません。',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLimitationItem('Googleアカウントを用いたログイン'),
                        _buildLimitationItem('Googleカレンダーへのタスク追加機能'),
                        _buildLimitationItem('Notion連携機能'),
                        _buildLimitationItem('データの永続的な保存（ブラウザを閉じると消える場合があります)'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: IconButton( // IconButtonに変更
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }

  // 4. 使い方セクション
  Widget _buildHowToUseSection(BuildContext context, double minHeight, {required Key key, required VoidCallback onNext}) {
    return Container(
      key: key, // キーを設定
      constraints: BoxConstraints(minHeight: minHeight),
      // padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      color: const Color(0xFFF9FAFB),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '使い方',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // カードの幅を調整
                    if (constraints.maxWidth > 1100) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 300, child: _buildStepCard(1, '授業名・キーワードを設定', '聞き逃したくない単語をキーワードに\n設定すると、類義語も自動で検出', Icons.edit_note)),
                          const SizedBox(width: 24),
                          SizedBox(width: 300, child: _buildStepCard(2, '録音する', 'キーワードを検出して\n画面の点滅や通知でお知らせ', Icons.mic)),
                          const SizedBox(width: 24),
                          SizedBox(width: 300, child: _buildStepCard(3, '振り返る', 'キーワード周辺の要約や\nカレンダーに追加するタスクを確認', Icons.summarize)),
                        ],
                      );
                    } else {
                      return Container(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStepCard(1, '授業名・キーワードを設定', '聞き逃したくない単語をキーワードに設定すると、類義語も自動で検出', Icons.edit_note),
                            const SizedBox(height: 24), // マージンの代わりにSizedBoxを使用
                            _buildStepCard(2, '録音する', '重要な話は画面の点滅や通知でお知らせ', Icons.mic),
                            const SizedBox(height: 24),
                            _buildStepCard(3, '振り返る', '聞き逃した箇所の要約やカレンダーに追加するタスクを確認', Icons.summarize),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: IconButton( // IconButtonに変更
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }

  // 5. フッター (CTA)
  Widget _buildFooter(BuildContext context, double minHeight, {required Key key}) {
    return Container(
      key: key, // キーを設定
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(40),
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => _scrollToSection(0),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/images/TaskEcho_lightmode.png',
                width: 280,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '「今のなんだっけ？」をなくす聞き逃し防止アプリ',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          if (!kIsWeb) ...[
            const SizedBox(height: 18),
            // ネイティブ版
            _buildLoginButton(
              icon: Icons.login,
              label: 'Sign in with Google',
              backgroundColor: const Color.fromRGBO(33, 150, 243, 0.75),
              onPressed: () async {
                final user = await GoogleAuth.signInWithGoogle();
                if (user != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => AuthWrapper()),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            _buildLoginButton(
              icon: Icons.person_outline,
              label: 'Continue as Guest',
              backgroundColor: Colors.black54,
              onPressed: () async {
                final user = await GoogleAuth.signInAnonymously();
                if (user != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => AuthWrapper()),
                  );
                }
              },
            ),
          ] else ...[
            // Web版
            _buildLoginButton(
              icon: Icons.person_outline,
              label: 'ゲストではじめる',
              backgroundColor: const Color.fromRGBO(33, 150, 243, 0.75),
              onPressed: () async {
                final user = await GoogleAuth.signInAnonymously();
                if (user != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => AuthWrapper()),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildProblemItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 220,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
            // horizontal: 12,
            // vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 6,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildLimitationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•', style: TextStyle(color: Colors.orange.shade800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.orange.shade900, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int step, String title, String description, IconData icon) {
    return Container(
      // margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            'STEP $step',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.5, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Container(
      width: 280, // カード幅を少し調整
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}