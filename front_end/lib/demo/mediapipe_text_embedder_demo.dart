import 'package:flutter/material.dart';
import '../services/mediapipe_text_embedder_service.dart';

/// MediaPipe Text Embedder を使用したデモページ
class MediaPipeTextEmbedderDemo extends StatefulWidget {
  @override
  _MediaPipeTextEmbedderDemoState createState() =>
      _MediaPipeTextEmbedderDemoState();
}

class _MediaPipeTextEmbedderDemoState extends State<MediaPipeTextEmbedderDemo> {
  final MediaPipeTextEmbedderService _embedder =
      MediaPipeTextEmbedderService();
  bool _isInitialized = false;
  bool _isLoading = false;
  String _result = '';

  final TextEditingController _text1Controller = TextEditingController();
  final TextEditingController _text2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeEmbedder();
  }

  Future<void> _initializeEmbedder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _embedder.initialize();
      setState(() {
        _isInitialized = true;
        _result = '✅ MediaPipe Text Embedder initialized successfully!';
      });
      _embedder.printModelInfo();
    } catch (e) {
      setState(() {
        _result = '❌ Initialization failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateSimilarity() async {
    if (!_isInitialized) {
      setState(() {
        _result = 'Embedder is not initialized';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final text1 = _text1Controller.text;
      final text2 = _text2Controller.text;

      if (text1.isEmpty || text2.isEmpty) {
        setState(() {
          _result = 'Please enter both texts';
        });
        return;
      }

      final similarity = await _embedder.calculateSimilarity(text1, text2);

      if (similarity == null) {
        setState(() {
          _result = 'Failed to calculate similarity';
        });
        return;
      }

      setState(() {
        _result = '''
📊 Similarity Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Text 1: "$text1"
Text 2: "$text2"

Similarity Score: ${similarity.toStringAsFixed(4)}
Percentage: ${(similarity * 100).toStringAsFixed(2)}%

Interpretation:
${_getInterpretation(similarity)}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Powered by Google MediaPipe
''';
      });
    } catch (e) {
      setState(() {
        _result = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getInterpretation(double similarity) {
    if (similarity >= 0.8) {
      return '🟢 Very Similar\nThese texts have very similar meanings.';
    } else if (similarity >= 0.6) {
      return '🟡 Somewhat Similar\nThese texts share some semantic similarity.';
    } else if (similarity >= 0.4) {
      return '🟠 Slightly Similar\nThese texts have minor semantic overlap.';
    } else {
      return '🔴 Not Similar\nThese texts have different meanings.';
    }
  }

  @override
  void dispose() {
    _embedder.dispose();
    _text1Controller.dispose();
    _text2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/mediapipe_icon.png',
              height: 24,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.text_fields, size: 24),
            ),
            SizedBox(width: 8),
            Text('MediaPipe Text Embedder'),
          ],
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb, color: Colors.amber[700]),
                              SizedBox(width: 8),
                              Text(
                                'Semantic Similarity',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'テキスト間の意味的類似度を計算します',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Powered by Google MediaPipe',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Text Input 1
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _text1Controller,
                        decoration: InputDecoration(
                          labelText: 'Text 1',
                          hintText: 'プログラミングの課題を提出する',
                          prefixIcon: Icon(Icons.text_snippet),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Text Input 2
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _text2Controller,
                        decoration: InputDecoration(
                          labelText: 'Text 2',
                          hintText: 'コーディングの宿題を出す',
                          prefixIcon: Icon(Icons.text_snippet),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Calculate Button
                  ElevatedButton(
                    onPressed:
                        _isInitialized && !_isLoading ? _calculateSimilarity : null,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calculate),
                              SizedBox(width: 8),
                              Text(
                                'Calculate Similarity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Result Card
                  if (_result.isNotEmpty)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insights, color: Colors.green[700]),
                                SizedBox(width: 8),
                                Text(
                                  'Result',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _result,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 16),

                  // Info Card
                  Card(
                    elevation: 2,
                    color: Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                '使用例',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildInfoRow(Icons.search, 'キーワード検索'),
                          _buildInfoRow(Icons.library_books, '類似文書の検索'),
                          _buildInfoRow(Icons.find_replace, '意味的な重複検出'),
                          _buildInfoRow(Icons.translate, '多言語対応'),
                          _buildInfoRow(Icons.category, 'テキスト分類のサポート'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue[700]),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
