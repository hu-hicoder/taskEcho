import 'package:flutter/material.dart';
import '../services/mediapipe_style_text_embedder.dart';

/// MediaPipeStyleTextEmbedder を使用した簡単なデモ
class MediaPipeTextDemo extends StatefulWidget {
  @override
  _MediaPipeTextDemoState createState() => _MediaPipeTextDemoState();
}

class _MediaPipeTextDemoState extends State<MediaPipeTextDemo> {
  final MediaPipeStyleTextEmbedder _embedder = MediaPipeStyleTextEmbedder();
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
        _result = '✓ MediaPipe-style Text Embedder initialized!';
      });
      _embedder.printModelInfo();
    } catch (e) {
      setState(() {
        _result = '✗ Initialization failed: $e';
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

      final similarity = await _embedder.calculateTextSimilarity(text1, text2);
      
      setState(() {
        _result = '''
Text 1: "$text1"
Text 2: "$text2"

Similarity Score: ${similarity.toStringAsFixed(4)}
(${(similarity * 100).toStringAsFixed(2)}%)

Interpretation:
${similarity >= 0.8 ? '🟢 Very Similar' : similarity >= 0.6 ? '🟡 Somewhat Similar' : similarity >= 0.4 ? '🟠 Slightly Similar' : '🔴 Not Similar'}
''';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        title: Text('MediaPipe Text Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MediaPipe-style Text Embedder',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'テキスト間の意味的類似度を計算します',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _text1Controller,
                decoration: InputDecoration(
                  labelText: 'Text 1',
                  hintText: 'プログラミングの課題を提出する',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _text2Controller,
                decoration: InputDecoration(
                  labelText: 'Text 2',
                  hintText: 'コーディングの宿題を出す',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isInitialized && !_isLoading
                    ? _calculateSimilarity
                    : null,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Calculate Similarity'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              if (_result.isNotEmpty)
                Card(
                  color: Colors.grey[100],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Result',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _result,
                          style: TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 使用例',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• キーワード検索\n'
                        '• 類似文書の検索\n'
                        '• 意味的な重複検出\n'
                        '• テキスト分類のサポート',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
