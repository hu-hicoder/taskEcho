import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keywordProvider.dart';
import '../providers/classProvider.dart';
import 'basePage.dart';
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

    return BasePage(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigoAccent, Colors.deepPurpleAccent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'キーワード検出履歴',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),

              // 授業フィルター
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '授業: ',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedClass,
                      dropdownColor: Colors.black87,
                      style: TextStyle(color: Colors.white),
                      underline: Container(),
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
                  ],
                ),
              ),

              SizedBox(height: 16),

              // 履歴リスト
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _detections.isEmpty
                        ? Center(
                            child: Text(
                              'キーワード検出履歴がありません',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 18),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _detections.length,
                            itemBuilder: (context, index) {
                              final detection = _detections[index];
                              final DateTime detectedAt =
                                  DateTime.parse(detection['detected_at']);
                              final String formattedDate =
                                  DateFormat('yyyy/MM/dd HH:mm')
                                      .format(detectedAt);

                              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                color: Colors.black54,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Chip(
                                            label: Text(
                                              detection['keyword'],
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                                color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          detection['context_text'],
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        '授業: ${detection['class_name']}',
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
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
      ),
    );
  }
}
