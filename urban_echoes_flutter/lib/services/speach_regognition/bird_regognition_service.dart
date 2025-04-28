import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'bird_data_helper.dart';
import 'bird_data_loader.dart';

class BirdRecognitionService extends ChangeNotifier {
  // Core speech recognition
  final SpeechToText _speech = SpeechToText();
  
  // Bird data components
  late BirdDataLoader _dataLoader;
  late BirdDataHelper _dataHelper;
  bool _dataInitialized = false;
  
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
  bool get isDataInitialized => _dataInitialized;
  int get successfulMatches => _successfulMatches;
  double get successRate => _recognitionAttempts > 0 
      ? _successfulMatches / _recognitionAttempts 
      : 0.0;
  List<String> get birdNames => _dataInitialized ? _dataHelper.activeBirds : [];
  
  // Constructor
  BirdRecognitionService({bool debugMode = false}) {
    _debugMode = debugMode;
    _dataLoader = BirdDataLoader();
    _initBirdData();
    _initSpeech();
  }
  
  Future<void> _initBirdData() async {
  try {
    _logDebug('Initializing bird data (dataInitialized=$_dataInitialized)');
    
    // Load bird names
    List<String> allBirdNames = await _dataLoader.loadBirdNames();
    
    _logDebug('Creating data helper with ${allBirdNames.length} bird names');
    // Create data helper with loaded names
    _dataHelper = BirdDataHelper(allBirdNames);
    
    // Log test mode before setting
    _logDebug('Current test mode: ${_dataHelper.isTestMode}');
    
    // Set test mode based on debug setting
    await _dataHelper.setTestMode(false); // Force to false for testing
    _logDebug('Test mode set to false, active birds: ${_dataHelper.activeBirds.length}');
    
    _dataInitialized = true;
    _logDebug('Bird data initialized with ${allBirdNames.length} names');
    _logDebug('Active birds after initialization: ${_dataHelper.activeBirds.length}');
    
    notifyListeners();
  } catch (e) {
    _logDebug('Error initializing bird data: $e');
    _errorMessage = 'Failed to initialize bird data: $e';
    notifyListeners();
  }
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
      
      // Make sure both speech and bird data are initialized
      if (!_isInitialized) {
        await _initSpeech();
        if (!_isInitialized) {
          _errorMessage = 'Speech recognition not available';
          notifyListeners();
          return false;
        }
      }
      
      if (!_dataInitialized) {
        await _initBirdData();
        if (!_dataInitialized) {
          _errorMessage = 'Bird data not initialized';
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
    
    // Make sure data is initialized before matching
    if (_dataInitialized) {
      _matchBirdName(_recognizedText);
    } else {
      _logDebug('Bird data not initialized, can\'t match bird names');
      _errorMessage = 'Bird data not available for matching';
    }
    
    notifyListeners();
  }
  
  // Match bird name using the data helper
  void _matchBirdName(String text) {
    if (text.isEmpty) return;
    
    // In Phase 1, use basic matching
    // This will be enhanced in Phase 2 with the data helper's advanced methods
    String lowerText = text.toLowerCase();
    _possibleMatches = [];
    
    // Simple matching for initial testing
    for (String bird in _dataHelper.activeBirds) {
      if (lowerText.contains(bird.toLowerCase())) {
        _possibleMatches.add(bird);
      }
    }
    
    // If no exact matches, try phonetic matching
    if (_possibleMatches.isEmpty) {
      _possibleMatches = _dataHelper.findPhoneticallySimilarBirds(text);
    }
    
    // Update matched bird and record success if found
    if (_possibleMatches.isNotEmpty) {
      _matchedBird = _possibleMatches.first;
      _successfulMatches++;
      
      // Record in data helper for analytics
      _dataHelper.recordRecognition(_matchedBird, _confidence);
      
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
  
  Future<void> setTestMode(bool value) async {
  if (_dataInitialized) {
    await _dataHelper.setTestMode(value);
    print("Test mode set to: $value, active birds: ${_dataHelper.activeBirds.length}");
    notifyListeners();
  }
}
  
  // Add custom birds to active set (for testing)
  Future<void> addCustomBirdsToActive(List<String> birds) async {
    if (_dataInitialized) {
      await _dataHelper.addCustomBirdsToActive(birds);
      notifyListeners();
    }
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