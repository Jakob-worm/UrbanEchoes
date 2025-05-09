import 'package:flutter/foundation.dart';
import 'bird_data_helper.dart';
import 'bird_data_loader.dart';

class BirdRecognitionService extends ChangeNotifier {
  // Constructor
  BirdRecognitionService({bool debugMode = false}) {
    _debugMode = debugMode;
    _dataLoader = BirdDataLoader();
    _initBirdData();
  }

  double _confidence = 0.0;
  late BirdDataHelper _dataHelper;
  bool _dataInitialized = false;
  // Bird data components
  late BirdDataLoader _dataLoader;

  // Debug and test variables
  bool _debugMode = false;

  String? _errorMessage;
  // State variables
  String _matchedBird = '';

  List<String> _possibleMatches = [];
  int _recognitionAttempts = 0;
  int _successfulMatches = 0;

  // Getters
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

  // Process text to find bird names
  void processText(String text) {
    if (text.isEmpty) return;
    
    _recognitionAttempts++;
    
    // Make sure data is initialized before matching
    if (_dataInitialized) {
      _matchBirdName(text);
    } else {
      _logDebug('Bird data not initialized, can\'t match bird names');
      _errorMessage = 'Bird data not available for matching';
      notifyListeners();
    }
  }

  // Reset service state
  void reset() {
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
      debugPrint("Test mode set to: $value, active birds: ${_dataHelper.activeBirds.length}");
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

  // Match bird name using the data helper
    void _matchBirdName(String text) {
    String lowerText = text.toLowerCase();
    _possibleMatches = [];
    Map<String, double> matchConfidences = {};
    
    // Phase 1: Look for exact matches
    for (String bird in _dataHelper.activeBirds) {
      String lowerBird = bird.toLowerCase();
      if (lowerText.contains(lowerBird)) {
        // Calculate a basic confidence score based on the relative length of the match
        double exactMatchConfidence = lowerBird.length / lowerText.length * 0.8 + 0.2;
        matchConfidences[bird] = exactMatchConfidence;
        _possibleMatches.add(bird);
      }
    }
    
    // Phase 2: If no exact matches, try phonetic matching
    if (_possibleMatches.isEmpty) {
      List<String> phoneticMatches = _dataHelper.findPhoneticallySimilarBirds(text);
      
      // Assign confidence scores to phonetic matches (lower than exact matches)
      for (int i = 0; i < phoneticMatches.length; i++) {
        // First match has higher confidence, decreasing for later matches
        double phoneticConfidence = 0.7 - (i * 0.1);
        if (phoneticConfidence < 0.3) phoneticConfidence = 0.3; // Minimum confidence
        
        matchConfidences[phoneticMatches[i]] = phoneticConfidence;
        _possibleMatches.add(phoneticMatches[i]);
      }
    }
    
    // Sort matches by confidence score (highest first)
    _possibleMatches.sort((a, b) => 
      (matchConfidences[b] ?? 0).compareTo(matchConfidences[a] ?? 0)
    );
    
    // Update matched bird and confidence if matches found
    if (_possibleMatches.isNotEmpty) {
      _matchedBird = _possibleMatches.first;
      _confidence = matchConfidences[_matchedBird] ?? 0.0;
      _successfulMatches++;
      
      // Record in data helper for analytics
      _dataHelper.recordRecognition(_matchedBird, _confidence);
      
      _logDebug('Matched bird: $_matchedBird with confidence: $_confidence');
      _logDebug('Possible matches: ${_possibleMatches.join(", ")}');
    } else {
      _matchedBird = '';
      _confidence = 0.0;
      _logDebug('No bird match found');
    }
    
    notifyListeners();
  }

  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('BirdRecognitionService: $message');
    }
  }
}