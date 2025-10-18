import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keywordProvider.dart';
import '../providers/classProvider.dart';
import 'package:intl/intl.dart';

class KeywordHistoryPage extends StatefulWidget {
  @override
  _KeywordHistoryPageState createState() => _KeywordHistoryPageState();
}

class _KeywordHistoryPageState extends State<KeywordHistoryPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _detections = [];
  String _selectedClass = "すべて";

  @override
  void initState() {
    super.initState();
    _loadDetections();
  }

  Future<void> _loadDetections() async {
    setState(() {
      _isLoading = true;
    });

    final keywordProvider =
        Provider.of<KeywordProvider>(context, listen: false);

    try {
      if (_selectedClass == "すべて") {
        _detections = await keywordProvider.getAllKeywordDetections();
      } else {
        _detections =
            await keywordProvider.getKeywordDetectionsByClass(_selectedClass);
      }
    } catch (e) {
      print('キーワード検出履歴の読み込み中にエラーが発生しました: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('履歴の読み込みに失敗しました')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classProvider = Provider.of<ClassProvider>(context);
    List<String> classOptions = ["すべて", ...classProvider.classes];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'キーワード履歴',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // フィルター部分
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Text(
                      '授業: ',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          dropdownColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.black87),
                          isExpanded: true,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedClass = newValue;
                              });
                              _loadDetections();
                            }
                          },
                          items: classOptions
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 履歴リスト
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.black87,
                      ),
                    )
                  : _detections.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 80,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'キーワード検出履歴がありません',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemCount: _detections.length,
                          itemBuilder: (context, index) {
                            final detection = _detections[index];
                            final DateTime detectedAt =
                                DateTime.parse(detection['detected_at']);
                            final String formattedDate =
                                DateFormat('yyyy/MM/dd HH:mm')
                                    .format(detectedAt);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.red[200]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            detection['keyword'],
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        detection['context_text'],
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.book_outlined,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          detection['class_name'],
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
