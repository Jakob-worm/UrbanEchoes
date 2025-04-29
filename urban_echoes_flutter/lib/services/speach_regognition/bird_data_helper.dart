import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BirdDataHelper {
  // The full list of Danish bird names
  final List<String> _allBirdNames;
  
  // Common birds to start with (for better initial testing)
  final List<String> _commonBirds = [
    'Musvit', 'Solsort', 'Gråspurv', 'Husskade', 'Ringdue', 
    'Bogfinke', 'Blåmejse', 'Allike', 'Grønirisk', 'Rødhals',
  ];
  
  // Current active birds (can be all or a subset for testing)
  List<String> _activeBirds = [];
  
  // Recognition statistics
  Map<String, int> _recognitionFrequency = {};
  Map<String, double> _recognitionConfidence = {};
  
  // Mode settings
  bool _testMode = false;
  
  // Constructor
  BirdDataHelper(this._allBirdNames) {
    _activeBirds = _allBirdNames.toList();
    _loadStoredData();
  }
  
  // Getters
  List<String> get allBirdNames => _allBirdNames;
  List<String> get activeBirds => _activeBirds;
  List<String> get commonBirds => _commonBirds;
  bool get isTestMode => _testMode;
  
  // Load stored recognition data from SharedPreferences
Future<void> _loadStoredData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Load frequency data
    String? freqData = prefs.getString('bird_recognition_frequency');
    if (freqData != null) {
      Map<String, dynamic> data = jsonDecode(freqData);
      _recognitionFrequency = Map<String, int>.from(data);
    }
    
    // Load confidence data
    String? confData = prefs.getString('bird_recognition_confidence');
    if (confData != null) {
      Map<String, dynamic> data = jsonDecode(confData);
      _recognitionConfidence = Map<String, double>.from(data);
    }
    
    // Load test mode setting, but don't use it to determine active birds
    _testMode = prefs.getBool('bird_recognition_test_mode') ?? true;
    
    // Always use all birds
    _activeBirds = _allBirdNames.toList();
  } catch (e) {
    debugPrint('Error loading bird recognition data: $e');
  }
}
  
  // Save data to SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save frequency data
      await prefs.setString(
        'bird_recognition_frequency', 
        jsonEncode(_recognitionFrequency)
      );
      
      // Save confidence data
      await prefs.setString(
        'bird_recognition_confidence', 
        jsonEncode(_recognitionConfidence)
      );
      
      // Save test mode setting
      await prefs.setBool('bird_recognition_test_mode', _testMode);
    } catch (e) {
      debugPrint('Error saving bird recognition data: $e');
    }
  }
  
  Future<void> setTestMode(bool value) async {
  _testMode = value;
  
  // Always keep all birds active regardless of test mode
  _activeBirds = _allBirdNames.toList();
  debugPrint("BirdDataHelper - Test mode set to: $value, but keeping all birds active: ${_activeBirds.length}");
  
  await _saveData();
}
  
  // Add custom birds to the active set (for gradual testing)
  Future<void> addCustomBirdsToActive(List<String> birds) async {
    for (String bird in birds) {
      if (_allBirdNames.contains(bird) && !_activeBirds.contains(bird)) {
        _activeBirds.add(bird);
      }
    }
    await _saveData();
  }
  
  // Reset active birds to default for current mode
  Future<void> resetActiveBirds() async {
    _activeBirds = _testMode ? _commonBirds.toList() : _allBirdNames.toList();
    await _saveData();
  }
  
  // Record a successful recognition
  Future<void> recordRecognition(String birdName, double confidence) async {
    if (_allBirdNames.contains(birdName)) {
      // Update frequency
      _recognitionFrequency[birdName] = (_recognitionFrequency[birdName] ?? 0) + 1;
      
      // Update average confidence
      double currentConfidence = _recognitionConfidence[birdName] ?? 0;
      int currentCount = _recognitionFrequency[birdName] ?? 1;
      
      // Calculate new weighted average confidence
      double newConfidence = (currentConfidence * (currentCount - 1) + confidence) / currentCount;
      _recognitionConfidence[birdName] = newConfidence;
      
      await _saveData();
    }
  }
  
  // Get most frequently recognized birds
  List<MapEntry<String, int>> getMostFrequentBirds({int limit = 10}) {
    List<MapEntry<String, int>> entries = _recognitionFrequency.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
  
  // Get birds with highest confidence scores
  List<MapEntry<String, double>> getHighestConfidenceBirds({int limit = 10}) {
    List<MapEntry<String, double>> entries = _recognitionConfidence.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
  
  // Get recognition frequency for a specific bird
  int getRecognitionCount(String birdName) {
    return _recognitionFrequency[birdName] ?? 0;
  }
  
  // Get average confidence for a specific bird
  double getAverageConfidence(String birdName) {
    return _recognitionConfidence[birdName] ?? 0.0;
  }
  
  // Clear all recognition statistics
  Future<void> clearStatistics() async {
    _recognitionFrequency.clear();
    _recognitionConfidence.clear();
    await _saveData();
  }
  
  // Group birds by first letter (useful for UI organization)
  Map<String, List<String>> groupBirdsByFirstLetter() {
    Map<String, List<String>> grouped = {};
    
    for (String bird in _allBirdNames) {
      String firstLetter = bird[0].toUpperCase();
      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = [];
      }
      grouped[firstLetter]!.add(bird);
    }
    
    return grouped;
  }
  
  // Filter birds by partial name match
  List<String> filterBirdsByName(String query) {
    if (query.isEmpty) return _activeBirds;
    
    String lowerQuery = query.toLowerCase();
    return _activeBirds.where((bird) => 
      bird.toLowerCase().contains(lowerQuery)
    ).toList();
  }
  
  // Calculate a simple Danish phonetic code for a word
  // This helps with matching similar-sounding words
  String getDanishPhoneticCode(String word) {
    if (word.isEmpty) return '';
    
    // Convert to lowercase
    String input = word.toLowerCase();
    
    // Basic Danish phonetic transformations
    input = input.replaceAll('æ', 'e');
    input = input.replaceAll('ø', 'o');
    input = input.replaceAll('å', 'o');
    input = input.replaceAll('aa', 'o');
    
    // Remove double consonants
    RegExp doubleConsonants = RegExp(r'([bcdfghjklmnpqrstvwxz])\1+');
    input = input.replaceAllMapped(doubleConsonants, (match) => match.group(1)!);
    
    // Return just the first 4 characters or the whole string if shorter
    return input.length <= 4 ? input : input.substring(0, 4);
  }
  
  // Find phonetically similar birds
  List<String> findPhoneticallySimilarBirds(String input, {int limit = 5}) {
    if (input.isEmpty) return [];
    
    String inputPhonetic = getDanishPhoneticCode(input);
    Map<String, double> similarities = {};
    
    for (String bird in _activeBirds) {
      List<String> parts = bird.split(' ');
      double bestSimilarity = 0;
      
      // Check each word in multi-word bird names
      for (String part in parts) {
        String partPhonetic = getDanishPhoneticCode(part);
        
        // Simple similarity metric - shared chars at start
        int matchLength = 0;
        int maxLength = inputPhonetic.length < partPhonetic.length ? 
                        inputPhonetic.length : partPhonetic.length;
        
        for (int i = 0; i < maxLength; i++) {
          if (inputPhonetic[i] == partPhonetic[i]) {
            matchLength++;
          } else {
            break; // Stop at first mismatch
          }
        }
        
        double similarity = matchLength / (inputPhonetic.length * 1.0);
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
        }
      }
      
      // Add if similarity is above threshold
      if (bestSimilarity > 0.5) {
        similarities[bird] = bestSimilarity;
      }
    }
    
    // Sort and return top matches
    List<MapEntry<String, double>> sorted = similarities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(limit).map((e) => e.key).toList();
  }
}