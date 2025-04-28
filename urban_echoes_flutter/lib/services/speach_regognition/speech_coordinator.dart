// lib/services/speach_regognition/speech_coordinator.dart
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/speech_recognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/word_recognition.dart';

class SpeechCoordinator extends ChangeNotifier {
  final SpeechRecognitionService _speechService;
  final BirdRecognitionService _birdService;
  final WordRecognitionService _wordService;
  final bool _debugMode;
  
  // Constructor
  SpeechCoordinator({
    required SpeechRecognitionService speechService,
    required BirdRecognitionService birdService,
    required WordRecognitionService wordService,
    bool? debugMode,
  }) : _speechService = speechService,
       _birdService = birdService,
       _wordService = wordService,
       _debugMode = debugMode ?? ServiceConfig().debugMode {
    // Listen for speech recognition updates
    _speechService.addListener(_onSpeechUpdate);
  }
  
  // Getters to expose underlying services
  SpeechRecognitionService get speechService => _speechService;
  BirdRecognitionService get birdService => _birdService;
  WordRecognitionService get wordService => _wordService;
  bool get isListening => _speechService.isListening;
  String get recognizedText => _speechService.recognizedText;
  double get confidence => _speechService.confidence;
  String? get errorMessage => _speechService.errorMessage ?? 
                             _birdService.errorMessage;
  
  void _onSpeechUpdate() {
    if (_speechService.recognizedText.isNotEmpty) {
      _logDebug('Processing recognized text: ${_speechService.recognizedText}');
      
      // First try special words
      _wordService.processText(_speechService.recognizedText);
      
      // If no special word found, try bird names
      if (_wordService.recognizedSpecialWord.isEmpty) {
        _logDebug('No special word found, trying bird names');
        _birdService.processText(_speechService.recognizedText);
      } else {
        _logDebug('Found special word: ${_wordService.recognizedSpecialWord}');
      }
    }
  }
  
  // Methods to control speech recognition
  Future<bool> startListening() async {
    _logDebug('Starting listening through coordinator');
    // Reset existing results before starting
    _wordService.reset();
    _birdService.reset();
    return await _speechService.startListening();
  }
  
  Future<bool> stopListening() async {
    _logDebug('Stopping listening through coordinator');
    return await _speechService.stopListening();
  }
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('SpeechCoordinator: $message');
    }
  }
  
  @override
  void dispose() {
    _speechService.removeListener(_onSpeechUpdate);
    super.dispose();
  }
}