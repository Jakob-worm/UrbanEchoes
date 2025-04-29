import 'package:flutter/foundation.dart';
import 'bird_data_helper.dart';
import 'bird_data_loader.dart';

class BirdRecognitionService extends ChangeNotifier {
  // Bird data components
  late BirdDataLoader _dataLoader;
  late BirdDataHelper _dataHelper;
  bool _dataInitialized = false;
  
  // State variables
  String _matchedBird = '';
  List<String> _possibleMatches = [];
  double _confidence = 0.0;
  String? _errorMessage;
  
  // Debug and test variables
  bool _debugMode = false;
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
  
  // Constructor
  BirdRecognitionService({bool debugMode = false}) {
    _debugMode = debugMode;
    _dataLoader = BirdDataLoader();
    _initBirdData();
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
  
  // Match bird name using the data helper
  void _matchBirdName(String text) {
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
    
    notifyListeners();
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
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('BirdRecognitionService: $message');
    }
  }
}