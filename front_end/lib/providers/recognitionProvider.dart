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



  void startRecognizing() async {
    if (_speechEnabled) {
      _isRecognizing = true;
      await _speechToText.listen(onResult: _onSpeechResult);
      notifyListeners();
    } else {
      _lastWords = 'Speech recognition not initialized';
      notifyListeners();
    }
  }

  void stopRecognizing() async {
    _isRecognizing = false;
    await _speechToText.stop();
    notifyListeners();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    notifyListeners();
  }
}
