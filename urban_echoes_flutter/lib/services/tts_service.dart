// lib/services/tts_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

class TtsService extends ChangeNotifier {
  late FlutterTts flutterTts;
  TtsState ttsState = TtsState.stopped;

  // TTS configuration properties
  String? language;
  double volume = 0.8;
  double pitch = 1.0;
  double rate = 0.5;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;

  TtsService() {
    initTts();
  }

  Future<void> initTts() async {
    flutterTts = FlutterTts();

    await flutterTts.setVolume(volume);
    await flutterTts.setPitch(pitch);
    await flutterTts.setSpeechRate(rate);

    // Configure speech completion behavior
    await flutterTts.awaitSpeakCompletion(true);

    // Set handlers
    flutterTts.setStartHandler(() {
      ttsState = TtsState.playing;
      notifyListeners();
    });

    flutterTts.setCompletionHandler(() {
      ttsState = TtsState.stopped;
      notifyListeners();
    });

    flutterTts.setCancelHandler(() {
      ttsState = TtsState.stopped;
      notifyListeners();
    });

    flutterTts.setPauseHandler(() {
      ttsState = TtsState.paused;
      notifyListeners();
    });

    flutterTts.setContinueHandler(() {
      ttsState = TtsState.continued;
      notifyListeners();
    });

    flutterTts.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
      ttsState = TtsState.stopped;
      notifyListeners();
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Stop any ongoing speech
    if (isPlaying) {
      await stop();
    }

    await flutterTts.speak(text);
  }

  Future<void> stop() async {
    await flutterTts.stop();
  }

  Future<void> pause() async {
    if (isPlaying) {
      await flutterTts.pause();
    }
  }

  // Optional: Get available languages
  Future<List<String>> getLanguages() async {
    try {
      final languages = await flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      debugPrint("Failed to get languages: $e");
      return [];
    }
  }

  // Update TTS settings
  Future<void> setTtsConfiguration(
      {double? newVolume,
      double? newPitch,
      double? newRate,
      String? newLanguage}) async {
    if (newVolume != null && newVolume != volume) {
      volume = newVolume;
      await flutterTts.setVolume(volume);
    }

    if (newPitch != null && newPitch != pitch) {
      pitch = newPitch;
      await flutterTts.setPitch(pitch);
    }

    if (newRate != null && newRate != rate) {
      rate = newRate;
      await flutterTts.setSpeechRate(rate);
    }

    if (newLanguage != null && newLanguage != language) {
      language = newLanguage;
      await flutterTts.setLanguage(language!);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }
}
