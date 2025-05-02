// lib/services/speach_regognition/word_recognition_service.dart
import 'package:flutter/foundation.dart';

class WordRecognitionService extends ChangeNotifier {
  final List<String> _seasonWords = ['sommer', 'forår', 'efterår', 'vinter'];
  final List<String> _confirmationWords = ['ja','yes','jeps','yeah', 'nej'];
  String _recognizedSpecialWord = '';
  String _wordType = ''; // 'season', 'confirmation', or ''
  bool _debugMode = false;
  
  // Getters
  String get recognizedSpecialWord => _recognizedSpecialWord;
  String get wordType => _wordType;
  bool get isSeasonWord => _wordType == 'season';
  bool get isConfirmationWord => _wordType == 'confirmation';
  List<String> get allSpecialWords => [..._seasonWords, ..._confirmationWords];
  
  // Constructor
  WordRecognitionService({bool debugMode = false}) {
    _debugMode = debugMode;
  }
  
  // Process text to find special words
  void processText(String text) {
    String lowerText = text.toLowerCase();
    
    // Reset
    _recognizedSpecialWord = '';
    _wordType = '';
    
    // Check seasons
    for (var word in _seasonWords) {
      if (lowerText.contains(word)) {
        _recognizedSpecialWord = word;
        _wordType = 'season';
        _logDebug('Recognized season word: $word');
        notifyListeners();
        return;
      }
    }
    
    // Check confirmations
    for (var word in _confirmationWords) {
      if (lowerText.contains(word)) {
        _recognizedSpecialWord = word;
        _wordType = 'confirmation';
        _logDebug('Recognized confirmation word: $word');
        notifyListeners();
        return;
      }
    }
    
    _logDebug('No special word found in: $text');
  }
  
  // Reset service state
  void reset() {
    _recognizedSpecialWord = '';
    _wordType = '';
    notifyListeners();
  }
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('WordRecognitionService: $message');
    }
  }
}