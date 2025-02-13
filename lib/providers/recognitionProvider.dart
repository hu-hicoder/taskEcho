import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class RecognitionProvider with ChangeNotifier {
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isRecognizing = false;

  bool get isRecognizing => _isRecognizing;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;

  RecognitionProvider() {
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _lastWords = 'マイクの権限が必要です';
        notifyListeners();
        return;
      }
    }
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (val) => print('Error: $val'),
      );
      if (!_speechEnabled) {
        _lastWords = 'Speech recognition not available on this device';
      }
    } catch (e) {
      _lastWords = 'Error initializing speech recognition: $e';
    }
    notifyListeners();
  }

  void startListening() async {
    if (_speechEnabled) {
      _isRecognizing = true;
      await _speechToText.listen(onResult: _onSpeechResult);
      notifyListeners();
    } else {
      _lastWords = 'Speech recognition not initialized';
      notifyListeners();
    }
  }

  void stopListening() async {
    _isRecognizing = false;
    await _speechToText.stop();
    notifyListeners();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    notifyListeners();
  }
}