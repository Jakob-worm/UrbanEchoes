import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

class TtsService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _debugMode = false;

  // Constructor
  TtsService({bool debugMode = false}) {
    _debugMode = debugMode;
    initTTS();
  }

  // Initialize TTS with Danish language settings
  Future<void> initTTS() async {
    if (_isInitialized) return;
    
    try {
      _logDebug('Initializing TTS service');
      
      // Set platform-specific options
      if (Platform.isAndroid) {
        // Check if Danish is available
        await _flutterTts.isLanguageInstalled("da-DK").then((result) {
          if (result == null || result == false) {
            // Language not installed, fall back to another language
            _flutterTts.setLanguage("en-US");
            _logDebug("Warning: Danish TTS not available, using English");
          } else {
            _flutterTts.setLanguage("da-DK");
            _logDebug("Danish TTS language set successfully");
          }
        });
      } else if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode
        );
        await _flutterTts.setLanguage("da-DK");
        _logDebug("iOS TTS settings configured");
      } else {
        await _flutterTts.setLanguage("da-DK");
        _logDebug("Default TTS language set to Danish");
      }
      
      // Get available languages for logging/debugging
      List<dynamic>? languages = await _flutterTts.getLanguages;
      _logDebug("Available TTS languages: $languages");
      
      // General settings
      await _flutterTts.setSpeechRate(0.5);    // Slower speech rate for better clarity
      await _flutterTts.setVolume(1.0);        // Full volume
      await _flutterTts.setPitch(1.0);         // Normal pitch
      
      _flutterTts.setCompletionHandler(() {
        _logDebug("TTS playback completed");
        _isSpeaking = false;
        notifyListeners();
      });
      
      _flutterTts.setErrorHandler((error) {
        _logDebug("TTS Error: $error");
        _isSpeaking = false;
        notifyListeners();
      });
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _logDebug("TTS initialization error: $e");
      _isInitialized = false; // Mark as not initialized so we can try again later
      notifyListeners();
    }
  }

  // Speak given text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initTTS();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    _logDebug("Speaking: $text");
    _isSpeaking = true;
    notifyListeners();
    await _flutterTts.speak(text);
  }

  // Stop speaking
  Future<void> stop() async {
    if (_isSpeaking) {
      _logDebug("Stopping TTS");
      _isSpeaking = false;
      await _flutterTts.stop();
      notifyListeners();
    }
  }

  // Check if TTS is currently speaking
  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('TTSService: $message');
    }
  }

  // Dispose of the TTS engine
  @override
  void dispose() {
    _flutterTts.stop();
    _isSpeaking = false;
    super.dispose();
  }
}