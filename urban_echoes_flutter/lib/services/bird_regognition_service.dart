import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class BirdRecognitionService extends ChangeNotifier {
  // Core speech recognition
  final SpeechToText _speech = SpeechToText();
  
  // State variables
  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _matchedBird = '';
  List<String> _possibleMatches = [];
  double _confidence = 0.0;
  String? _errorMessage;
  
  // Debug and test variables
  bool _debugMode = false;
  int _recognitionAttempts = 0;
  int _successfulMatches = 0;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  String get matchedBird => _matchedBird;
  List<String> get possibleMatches => _possibleMatches;
  double get confidence => _confidence;
  String? get errorMessage => _errorMessage;
  int get recognitionAttempts => _recognitionAttempts;
  int get successfulMatches => _successfulMatches;
  double get successRate => _recognitionAttempts > 0 
      ? _successfulMatches / _recognitionAttempts 
      : 0.0;
  
  // Danish bird names (simplified list for initial testing)
  // In production, load this from a file or database
  final List<String> birdNames = [
    'Musvit', 'Solsort', 'Gråspurv', 'Husskade', 'Ringdue', 
    'Bogfinke', 'Blåmejse', 'Allike', 'Grønirisk', 'Rødhals',
    // Add more birds in phases - start with most common birds first
  ];
  
  // Constructor
  BirdRecognitionService({bool debugMode = false}) {
    _debugMode = debugMode;
    // Initialize asynchronously to not block main thread
    _initSpeech();
  }
  
  // Initialize speech recognition
  Future<bool> _initSpeech() async {
    try {
      _logDebug('Initializing speech recognition');
      
      bool available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: _debugMode,
      );
      
      _isInitialized = available;
      
      if (available) {
        _logDebug('Speech recognition initialized successfully');
        
        // Check if Danish is supported
        var locales = await _speech.locales();
        bool danishSupported = locales.any((locale) => 
          locale.localeId.toLowerCase().contains('da') || 
          locale.name.toLowerCase().contains('danish')
        );
        
        if (!danishSupported) {
          _logDebug('WARNING: Danish may not be directly supported on this device');
          _errorMessage = 'Danish language support may be limited on this device';
        } else {
          _logDebug('Danish language is supported');
        }
      } else {
        _logDebug('Speech recognition failed to initialize');
        _errorMessage = 'Speech recognition is not available on this device';
      }
      
      notifyListeners();
      return available;
    } catch (e) {
      _logDebug('Error initializing speech: $e');
      _errorMessage = 'Failed to initialize: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Start listening for speech
  Future<bool> startListening() async {
    if (_isListening) return true;
    
    try {
      _logDebug('Starting speech recognition');
      _errorMessage = null;
      
      if (!_isInitialized) {
        await _initSpeech();
        if (!_isInitialized) {
          _errorMessage = 'Speech recognition not available';
          notifyListeners();
          return false;
        }
      }
      
      _recognizedText = '';
      _matchedBird = '';
      _possibleMatches = [];
      notifyListeners();
      
      _recognitionAttempts++;
      
      return await _speech.listen(
        onResult: _onSpeechResult,
        localeId: 'da_DK', // Danish language
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
      );
    } catch (e) {
      _logDebug('Error starting listening: $e');
      _errorMessage = 'Failed to start listening: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Stop listening
  Future<bool> stopListening() async {
    if (!_isListening) return true;
    
    try {
      _logDebug('Stopping speech recognition');
      await _speech.stop();
      return true;
    } catch (e) {
      _logDebug('Error stopping listening: $e');
      _errorMessage = 'Failed to stop listening: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Handle speech recognition status changes
  void _onSpeechStatus(String status) {
    _logDebug('Speech recognition status: $status');
    _isListening = status == 'listening';
    notifyListeners();
  }
  
  // Handle speech recognition errors
  void _onSpeechError(SpeechRecognitionError error) {
    _logDebug('Speech recognition error: ${error.errorMsg}');
    _errorMessage = 'Recognition error: ${error.errorMsg}';
    notifyListeners();
  }
  
  // Process speech results
  void _onSpeechResult(SpeechRecognitionResult result) {
    _recognizedText = result.recognizedWords;
    _confidence = result.confidence;
    
    _logDebug('Recognized: $_recognizedText (${(_confidence * 100).toStringAsFixed(1)}%)');
    
    // Very simple matching logic for Phase 1
    // This will be enhanced in later phases
    _matchBirdName(_recognizedText);
    
    notifyListeners();
  }
  
  // Basic bird name matching logic (Phase 1)
  void _matchBirdName(String text) {
    String lowerText = text.toLowerCase();
    _possibleMatches = [];
    
    // Simple contains matching for initial testing
    for (String bird in birdNames) {
      if (lowerText.contains(bird.toLowerCase())) {
        _possibleMatches.add(bird);
      }
    }
    
    if (_possibleMatches.isNotEmpty) {
      _matchedBird = _possibleMatches.first;
      _successfulMatches++;
      _logDebug('Matched bird: $_matchedBird');
    } else {
      _matchedBird = '';
      _logDebug('No bird match found');
    }
  }
  
  // Reset service state
  void reset() {
    stopListening();
    _recognizedText = '';
    _matchedBird = '';
    _possibleMatches = [];
    _confidence = 0.0;
    _errorMessage = null;
    notifyListeners();
  }
  
  // Reset statistics
  void resetStatistics() {
    _recognitionAttempts = 0;
    _successfulMatches = 0;
    notifyListeners();
  }
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('BirdRecognitionService: $message');
    }
  }
  
  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}