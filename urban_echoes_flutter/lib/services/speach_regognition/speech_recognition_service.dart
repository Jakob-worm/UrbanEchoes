import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechRecognitionService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  double _confidence = 0.0;
  String? _errorMessage;
  bool _debugMode = false;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  double get confidence => _confidence;
  String? get errorMessage => _errorMessage;
  
  // Constructor
  SpeechRecognitionService({bool debugMode = false}) {
    _debugMode = debugMode;
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

  void clearRecognizedText() {
  // Clear the recognized text
  _recognizedText = '';
  
  // Notify listeners of the change
  notifyListeners();
}
  
  // Start listening for speech
  Future<bool> startListening() async {
    if (_isListening) return true;
    
    try {
      _logDebug('Starting speech recognition');
      _errorMessage = null;
      
      // Make sure speech is initialized
      if (!_isInitialized) {
        await _initSpeech();
        if (!_isInitialized) {
          _errorMessage = 'Speech recognition not available';
          notifyListeners();
          return false;
        }
      }
      
      _recognizedText = '';
      notifyListeners();
      
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
    notifyListeners();
  }
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('SpeechRecognitionService: $message');
    }
  }
  
  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}