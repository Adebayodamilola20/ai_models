import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.48); // Natural speaking pace
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1); // Slightly higher = more human

    // iOS: Use Samantha (best natural female voice)
    await _flutterTts.setVoice({"name": "Samantha", "locale": "en-US"});

    // If Samantha doesn't work, try Alex
    // await _flutterTts.setVoice({"name": "Alex", "locale": "en-US"});

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
  }

  Future<void> speak(String text) async {
    if (_isSpeaking) {
      await stop();
    }

    String cleanText = text
        .replaceAll('**', '')
        .replaceAll('```', '')
        .replaceAll('#', '')
        .replaceAll('*', '');

    _isSpeaking = true;
    await _flutterTts.speak(cleanText);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
  }

  bool get isSpeaking => _isSpeaking;
  Future<List<dynamic>> getVoices() async {
    return await _flutterTts.getVoices;
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
  }
}
