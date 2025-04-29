import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/recording_player_service.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/speech_recognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/word_recognition.dart';
import 'package:urban_echoes/services/tts/tts_service.dart';

class SpeechCoordinator extends ChangeNotifier {
  final SpeechRecognitionService _speechService;
  final BirdRecognitionService _birdService;
  final WordRecognitionService _wordService;
  final RecrodingPlayerService _audioService; // Instead of TtsService
  final bool _debugMode;
  
  // State for confirmation workflow
  bool _isWaitingForConfirmation = false;
  String _currentBirdInQuestion = '';
  
  // Constructor - updated to include TtsService
  SpeechCoordinator({
    required SpeechRecognitionService speechService,
    required BirdRecognitionService birdService,
    required WordRecognitionService wordService,
    required RecrodingPlayerService audioService,
    bool? debugMode,
  }) : _speechService = speechService,
       _birdService = birdService,
       _wordService = wordService,
       _audioService = audioService,
       _debugMode = debugMode ?? ServiceConfig().debugMode {
    // Listen for speech recognition updates
    _speechService.addListener(_onSpeechUpdate);
    _wordService.addListener(_onWordUpdate);
  }
  
  // Getters to expose underlying services
  SpeechRecognitionService get speechService => _speechService;
  BirdRecognitionService get birdService => _birdService;
  WordRecognitionService get wordService => _wordService;
  RecrodingPlayerService get audioService => _audioService;
  bool get isListening => _speechService.isListening;
  String get recognizedText => _speechService.recognizedText;
  double get confidence => _speechService.confidence;
  String? get errorMessage => _speechService.errorMessage ??
                             _birdService.errorMessage;
  
  // Confirmation workflow getters
  bool get isWaitingForConfirmation => _isWaitingForConfirmation;
  String get currentBirdInQuestion => _currentBirdInQuestion;
  
  // Handle speech recognition updates
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
  
  // Handle special word updates
  void _onWordUpdate() {
    if (_wordService.isConfirmationWord && _isWaitingForConfirmation) {
      _logDebug('Processing confirmation word: ${_wordService.recognizedSpecialWord}');
      
      // Handle Yes/No response
      if (_wordService.recognizedSpecialWord == 'ja') {
        handleConfirmationResponse(true);
      } else if (_wordService.recognizedSpecialWord == 'nej') {
        handleConfirmationResponse(false);
      }
    }
  }
  
  void handleBirdRecognition(String birdName) {
  if (birdName.isNotEmpty) {
    _logDebug('Handling bird recognition: $birdName');
    
    // Ask confirmation question using audio
    _audioService.playPrompt('bird_question');
    
    // Set waiting for confirmation state
    _isWaitingForConfirmation = true;
    _currentBirdInQuestion = birdName;
    notifyListeners();
  }
}
  
void handleConfirmationResponse(bool confirmed) {
  if (!_isWaitingForConfirmation) return;
  
  _logDebug('Handling confirmation response: ${confirmed ? "Yes" : "No"}');
  
  if (confirmed) {
    // User confirmed the bird sighting
    _audioService.playPrompt('bird_confirmed');
    // Here you could save the observation to a database
  } else {
    // User denied the bird sighting
    _audioService.playPrompt('bird_denied');
  }
  
  // Reset confirmation state
  _isWaitingForConfirmation = false;
  _currentBirdInQuestion = '';
  notifyListeners();
}
  
  // Methods to control speech recognition
  Future<bool> startListening() async {
  _logDebug('Starting listening through coordinator');
  
  // Stop any ongoing audio before starting to listen
  if (_audioService.isPlaying) {
    await _audioService.stopAudio();
  }
  
  // Play the starting audio
  await _audioService.playPrompt('start_listening');
  
  // Reset existing results before starting
  _wordService.reset();
  _birdService.reset();
  return await _speechService.startListening();
}

Future<bool> stopListening() async {
  _logDebug('Stopping listening through coordinator');
  
  bool result = await _speechService.stopListening();
  
  // Play the stopping audio
  await _audioService.playPrompt('stop_listening');
  
  // Process the recognition results after stopping
  _processRecognitionResults();
  
  return result;
}
  
  // Process the final recognition results
  void _processRecognitionResults() {
    // If already waiting for confirmation, we're in a dialog
    if (_isWaitingForConfirmation) {
      // Check for confirmation words in the recognized text
      String text = _speechService.recognizedText.toLowerCase();
      
      if (text.contains('ja') || text.contains('jo') || text.contains('yes') || 
          text.contains('jep') || text.contains('rigtigt')) {
        handleConfirmationResponse(true);
      } else if (text.contains('nej') || text.contains('no') || text.contains('ikke') || 
                text.contains('forkert')) {
        handleConfirmationResponse(false);
      }
      // Else continue waiting for confirmation
    } 
    // If not waiting for confirmation and a bird was recognized
    else if (_birdService.matchedBird.isNotEmpty) {
      handleBirdRecognition(_birdService.matchedBird);
    }
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
    _wordService.removeListener(_onWordUpdate);
    super.dispose();
  }
}