import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/models/bird_observation.dart';
import 'package:urban_echoes/services/observation/observation_uploader.dart';
import 'package:urban_echoes/services/recording_player_service.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/speach_regognition/bird_data_loader.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/speech_recognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/word_recognition.dart';

/// Enum representing the various states of the speech recognition workflow
enum RecognitionState {
  idle,
  listening,
  processingBirdRecognition,
  waitingForConfirmation,
  systemInDoubt,
  processingConfirmation,
}

/// Main coordinator for speech recognition and bird observation workflow
class SpeechCoordinator extends ChangeNotifier {
  // ===== CONSTRUCTOR & FIELDS =====
  
  SpeechCoordinator({
    required SpeechRecognitionService speechService,
    required BirdRecognitionService birdService,
    required WordRecognitionService wordService,
    required RecordingPlayerService audioService,
    required ObservationUploader observationUploader,
    bool? debugMode,
  }) : 
    _speechService = speechService,
    _birdService = birdService,
    _wordService = wordService,
    _audioService = audioService,
    _observationUploader = observationUploader,
    _debugMode = debugMode ?? ServiceConfig().debugMode {
    _initializeListeners();
  }

  // Services
  late SpeechRecognitionService _speechService;
  late BirdRecognitionService _birdService;
  late WordRecognitionService _wordService;
  late RecordingPlayerService _audioService;
  final ObservationUploader _observationUploader;
  
  // Configuration
  final bool _debugMode;
  final int _confirmationTimeoutSeconds = 15;
  
  // State management
  RecognitionState _currentState = RecognitionState.idle;
  Timer? _confirmationTimer;
  String _currentBirdInQuestion = '';
  List<String> _possibleBirds = [];
  bool _isManualInputActive = false;
  
  // Observation tracking
  BirdObservation? _latestObservation;
  final BirdDataLoader birdDataLoader = BirdDataLoader();

  @override
  void dispose() {
    _removeListeners();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  // ===== PUBLIC GETTERS =====
  
  RecognitionState get currentState => _currentState;
  bool get isListening => _speechService.isListening;
  String get recognizedText => _speechService.recognizedText;
  double get confidence => _speechService.confidence;
  bool get isManualInputActive => _isManualInputActive;
  String? get errorMessage => _speechService.errorMessage ?? _birdService.errorMessage;
  bool get isWaitingForConfirmation => _currentState == RecognitionState.waitingForConfirmation;
  bool get isSystemInDoubt => _currentState == RecognitionState.systemInDoubt;
  String get currentBirdInQuestion => _currentBirdInQuestion;
  List<String> get possibleBirds => _possibleBirds;
  BirdObservation? get latestObservation => _latestObservation;

  // Service getters (for testing and external control)
  SpeechRecognitionService get speechService => _speechService;
  BirdRecognitionService get birdService => _birdService;
  WordRecognitionService get wordService => _wordService;
  RecordingPlayerService get audioService => _audioService;

  // ===== PUBLIC METHODS =====

  /// Update services without recreating the coordinator
  void updateServices({
    SpeechRecognitionService? speechService,
    BirdRecognitionService? birdService,
    WordRecognitionService? wordService,
    RecordingPlayerService? audioService,
  }) {
    _logDebug('Updating services in SpeechCoordinator');
    
    if (speechService != null && speechService != _speechService) {
      _speechService.removeListener(_onSpeechUpdate);
      _speechService = speechService;
      _speechService.addListener(_onSpeechUpdate);
    }
    
    if (birdService != null) {
      _birdService = birdService;
    }
    
    if (wordService != null && wordService != _wordService) {
      _wordService.removeListener(_onWordUpdate);
      _wordService = wordService;
      _wordService.addListener(_onWordUpdate);
    }
    
    if (audioService != null && audioService != _audioService) {
      _audioService.removeListener(_onAudioStateChanged);
      _audioService = audioService;
      _audioService.addListener(_onAudioStateChanged);
    }
  }

  // ----- Workflow Entry Points -----
  
  /// Start listening for speech input
  Future<bool> startListening() async {
    _logDebug('Starting listening through coordinator');
    
    // Reset state and stop any ongoing audio
    _transitionToState(RecognitionState.idle);
    if (_audioService.isPlaying) {
      await _audioService.stopAudio();
    }
    
    _resetRecognitionServices();
    
    bool result = await _speechService.startListening();
    if (result) {
      _transitionToState(RecognitionState.listening);
    }
    
    return result;
  }

  /// Stop listening for speech input
  Future<bool> stopListening() async {
    _logDebug('Stopping listening through coordinator');
    
    bool result = await _speechService.stopListening();
    await _audioService.playPrompt('stop_listening');
    
    return result;
  }

  /// Clear recognized text and reset recognition state
  void clearRecognizedText() {
    _logDebug('Clearing recognized text');
    
    _speechService.clearRecognizedText();
    _birdService.reset();
    notifyListeners();
  }

  // ----- Bird Recognition Handlers -----
  
  /// Handle a recognized bird name
  void handleBirdRecognition(String birdName) {
    // Skip if already processing or no bird name
    if (_currentState == RecognitionState.processingBirdRecognition || 
        _currentState == RecognitionState.waitingForConfirmation || 
        birdName.isEmpty) {
      return;
    }
    
    _logDebug('Handling bird recognition: $birdName');
    _transitionToState(RecognitionState.processingBirdRecognition);
    
    _currentBirdInQuestion = birdName;
    _pauseListeningForAudio();
    _startConfirmationTimeout();
    _audioService.playBirdQuestion(birdName);
  }

  /// Handle when the system is in doubt between multiple birds
  void handleSystemInDoubt(List<String> birds) {
    if (_currentState == RecognitionState.processingBirdRecognition || 
        _currentState == RecognitionState.systemInDoubt || 
        birds.isEmpty) {
      return;
    }
    
    _logDebug('System is in doubt about: ${birds.join(", ")}');
    _transitionToState(RecognitionState.processingBirdRecognition);
    
    _possibleBirds = birds.take(3).toList();
    _pauseListeningForAudio();
    _startConfirmationTimeout();
    _audioService.playPrompt('systemet_er_i_tvil');
  }

  /// Handle bird selection from the doubt UI
  void handleBirdSelection(String selectedBird) {
    _confirmationTimer?.cancel();
    
    _logDebug('Bird selected from doubt UI: $selectedBird');
    
    _possibleBirds = [];
    handleBirdRecognition(selectedBird);
  }

  /// Handle deletion of the last observation
  void handleDeleteObservation() {
    _logDebug('Handling delete observation command');
    
    _pauseListeningForAudio();
    _audioService.playPrompt('okay_observation_er_slettet');
    // Implement deletion logic here
  }

  /// Handle user's confirmation response (yes/no)
  Future<void> handleConfirmationResponse(bool confirmed) async {
    if (_currentState != RecognitionState.waitingForConfirmation) {
      return;
    }
    
    _confirmationTimer?.cancel();
    _logDebug('Handling confirmation response: ${confirmed ? "Yes" : "No"}');
    
    // Save the current bird name before making any changes
    final String originalBirdName = _currentBirdInQuestion;
    
    // Stop listening if still active
    _pauseListeningForAudio();
    
    if (confirmed) {
      _transitionToState(RecognitionState.processingConfirmation);
      _audioService.playBirdConfirmation(originalBirdName);
      await _createAndUploadObservation();
    } else {
      // Critical fix: Set the current text to the original bird, not "nej"
      // This prevents "nej" from being used as input to _birdService
      _speechService.clearRecognizedText();
      
      // Pre-populate possible matches with birds similar to the original bird
      _logDebug('Finding alternatives to original bird: $originalBirdName');
      _birdService.processText(originalBirdName);
      
      // Now find alternatives using the original bird name
      _findAlternativeBirds(originalBirdName);
      
      _transitionToState(RecognitionState.systemInDoubt);
      notifyListeners();
      _audioService.playPrompt('systemet_er_i_tvil');
      _logDebug('SystemInDoubt state activated with ${_possibleBirds.length} alternatives');
    }
  }

  /// Reset confirmation state
  void resetConfirmationState() {
    _logDebug('Resetting confirmation state');
    _confirmationTimer?.cancel();
    _currentBirdInQuestion = '';
    _possibleBirds = [];
    _transitionToState(RecognitionState.idle);
    notifyListeners();
  }

  /// Process voice command in system in doubt state
  void processVoiceCommandInDoubtState(String command) {
    if (_currentState != RecognitionState.systemInDoubt) return;
    
    _logDebug('Processing voice command in doubt state: $command');
    String lowerCommand = command.toLowerCase();
    
    // Check if command contains any bird name from possible birds
    for (String bird in _possibleBirds) {
      if (lowerCommand.contains(bird.toLowerCase())) {
        _logDebug('Found bird name in command: $bird');
        handleBirdSelection(bird);
        return;
      }
    }
    
    // Check for dismissal commands
    if (_isDismissalCommand(lowerCommand)) {
      _logDebug('Dismiss command detected');
      resetConfirmationState();
    }
  }

  // ----- Manual Input Handlers -----
  
  /// Activate manual bird input mode
  void activateManualInput() {
    _logDebug('Activating manual input mode');
    _isManualInputActive = true;
    _audioService.playPrompt('indtast_den_fulg_du_så');
    notifyListeners();
  }

  /// Deactivate manual bird input mode
  void deactivateManualInput() {
    _isManualInputActive = false;
    notifyListeners();
  }

  /// Handle manual bird selection
  void handleManualBirdSelection(String birdName) {
    if (birdName.isEmpty) return;
    
    _birdService.reset();
    _birdService.processText(birdName);
    _currentBirdInQuestion = birdName;
    _isManualInputActive = false;
    _startConfirmationTimeout();
    _transitionToState(RecognitionState.waitingForConfirmation);
    _audioService.playBirdQuestion(birdName);
  }

  // ===== PRIVATE METHODS =====

  // ----- Service Listeners -----
  
  /// Initialize all service listeners
  void _initializeListeners() {
    _speechService.addListener(_onSpeechUpdate);
    _wordService.addListener(_onWordUpdate);
    _audioService.addListener(_onAudioStateChanged);
    _logDebug('Service listeners initialized');
  }

  /// Remove all service listeners
  void _removeListeners() {
    _speechService.removeListener(_onSpeechUpdate);
    _wordService.removeListener(_onWordUpdate);
    _audioService.removeListener(_onAudioStateChanged);
    _logDebug('Service listeners removed');
  }

  // ----- Event Handlers -----
  
  /// Handle audio state changes
  void _onAudioStateChanged() {
    if (!_audioService.isPlaying && _audioService.lastPlaybackType.isNotEmpty) {
      _logDebug('Audio completed: ${_audioService.lastPlaybackType}');
      _handleAudioCompletion(_audioService.lastPlaybackType);
      _audioService.resetLastPlaybackType();
    }
  }

  /// Handle speech recognition updates
  void _onSpeechUpdate() {
    String recognizedText = _speechService.recognizedText;
    if (recognizedText.isEmpty) return;
    
    _logDebug('Processing recognized text: $recognizedText');
    
    if (_currentState == RecognitionState.waitingForConfirmation) {
      _processConfirmationSpeech(recognizedText);
      return;
    }
    
    if (_currentState == RecognitionState.systemInDoubt) {
      _directHandleSystemInDoubt(recognizedText);
      return;
    }
    
    if (_currentState == RecognitionState.processingBirdRecognition) {
      _logDebug('Skipping recognition processing - already in processing flow');
      return;
    }
    
    // Process for special words first
    _wordService.processText(recognizedText);
    
    if (_wordService.recognizedSpecialWord.isEmpty) {
      _processBirdNames(recognizedText);
    } else {
      _processSpecialWords(_wordService.recognizedSpecialWord);
    }
  }
  
  /// Handle special word updates
  void _onWordUpdate() {
    if (!_wordService.isConfirmationWord) return;
    
    _logDebug('Processing confirmation word: ${_wordService.recognizedSpecialWord}');
    String word = _wordService.recognizedSpecialWord;
    
    if (_currentState == RecognitionState.waitingForConfirmation) {
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      
      if (_isPositiveResponse(word)) {
        _logDebug('Positive response detected immediately: $word');
        handleConfirmationResponse(true);
      } 
      else if (_isNegativeResponse(word)) {
        _logDebug('Negative response detected immediately: $word');
        handleConfirmationResponse(false);
      }
    }
    else if (_currentState == RecognitionState.systemInDoubt) {
      _processWordResponseInDoubtState(word);
    }
  }

  // ----- Speech Processing Methods -----
  
  /// Process confirmation speech
  void _processConfirmationSpeech(String recognizedText) {
    _logDebug('In confirmation state, checking text for confirmation: $recognizedText');
    String lowerText = recognizedText.toLowerCase();
    
    if (_directCheckForPositiveResponse(lowerText)) {
      _logDebug('Direct positive response detected in speech update');
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      handleConfirmationResponse(true);
    }
    else if (_directCheckForNegativeResponse(lowerText)) {
      _logDebug('Direct negative response detected in speech update');
      
      // Important: Stop listening first to prevent further processing of "nej" as input
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      
      // Now handle the negative response
      handleConfirmationResponse(false);
    }
  }

  /// Directly handle system in doubt state
  void _directHandleSystemInDoubt(String recognizedText) {
    if (_possibleBirds.isEmpty) {
      _logDebug('WARNING: In system in doubt state but no possible birds available');
      return;
    }

    String lowerText = recognizedText.toLowerCase();
    _logDebug('Direct handling of system in doubt text: $lowerText');
    
    if (_directCheckForPositiveResponse(lowerText) && _possibleBirds.isNotEmpty) {
      _logDebug('Detected positive response in doubt state - selecting first option');
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      handleBirdSelection(_possibleBirds[0]);
      return;
    }
    else if (_directCheckForNegativeResponse(lowerText)) {
      _logDebug('Detected negative response in doubt state - dismissing');
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      resetConfirmationState();
      return;
    }
    
    // Check for bird names
    for (String bird in _possibleBirds) {
      if (lowerText.contains(bird.toLowerCase())) {
        _logDebug('Found bird name in recognized text: $bird');
        if (_speechService.isListening) {
          _speechService.stopListening();
        }
        handleBirdSelection(bird);
        return;
      }
    }
    
    // Check for dismissal commands
    if (_isDismissalCommand(lowerText)) {
      _logDebug('Detected dismiss command');
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      resetConfirmationState();
    }
  }

  /// Process word response in doubt state
  void _processWordResponseInDoubtState(String word) {
    if (_isPositiveResponse(word) || _isNegativeResponse(word)) {
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      
      if (_isPositiveResponse(word) && _possibleBirds.isNotEmpty) {
        _logDebug('Positive response in doubt state - selecting first option: ${_possibleBirds[0]}');
        handleBirdSelection(_possibleBirds[0]);
      } else if (_isNegativeResponse(word)) {
        _logDebug('Negative response in doubt state - dismissing');
        resetConfirmationState();
      }
    }
  }

  /// Process bird names in recognized text
  void _processBirdNames(String text) {
    _logDebug('No special word found, trying bird names');
    _birdService.processText(text);
    
    if (_birdService.possibleMatches.length > 1 && _birdService.confidence < 0.7) {
      handleSystemInDoubt(_birdService.possibleMatches);
    }
    else if (_birdService.matchedBird.isNotEmpty) {
      handleBirdRecognition(_birdService.matchedBird);
    }
  }

  /// Process special words in recognized text
  void _processSpecialWords(String word) {
    _logDebug('Found special word: $word');
    
    if (word == 'slet' || word == 'delete') {
      handleDeleteObservation();
    }
    // Add other special word handlers here
  }

  /// Find alternative birds when user responds negatively
  void _findAlternativeBirds([String? forcedOriginalBird]) {
    final String birdToUse = forcedOriginalBird ?? _currentBirdInQuestion;
    _logDebug('Processing negative response - preparing to show alternatives for: $birdToUse');
    
    // Reset possible birds list to ensure clean state
    _possibleBirds = [];
    
    // First try to use existing matches from the bird service
    if (_birdService.possibleMatches.length > 1) {
      _possibleBirds = _birdService.possibleMatches
          .where((bird) => bird != birdToUse)
          .take(3)
          .toList();
      _logDebug('Using existing matches sorted by confidence: ${_possibleBirds.join(", ")}');
    } else {
      // Find phonetically similar birds (explicitly use the original bird name)
      _birdService.processText(birdToUse);
      
      if (_birdService.possibleMatches.length > 1) {
        _possibleBirds = _birdService.possibleMatches
            .where((bird) => bird != birdToUse)
            .take(3)
            .toList();
        _logDebug('Using phonetic matches: ${_possibleBirds.join(", ")}');
      } else {
        // Use any available recognized text as a last resort
        String textToProcess = _speechService.recognizedText.isNotEmpty ? 
            _speechService.recognizedText : birdToUse;
        
        // Skip processing if the text is just a "no" response
        if (_directCheckForNegativeResponse(textToProcess.toLowerCase())) {
          textToProcess = birdToUse;
          _logDebug('Text contains negative response, using original bird name instead: $birdToUse');
        }
        
        _birdService.processText(textToProcess);
        
        _possibleBirds = _birdService.possibleMatches
            .where((bird) => bird != birdToUse)
            .take(3)
            .toList();
        _logDebug('Using text processing matches: ${_possibleBirds.join(", ")}');
      }
    }
    
    // ALWAYS add fallback birds - this ensures we have at least some options
    _addFallbackBirds(birdToUse);
    
    _logDebug('Final possible birds by confidence: ${_possibleBirds.join(", ")}');
  }

  /// Add fallback birds if we don't have enough options
  void _addFallbackBirds([String? birdToExclude]) {
    final String excludeBird = birdToExclude ?? _currentBirdInQuestion;
    _logDebug('Adding fallback birds, current count: ${_possibleBirds.length}, excluding: $excludeBird');
    
    // First try phonetically similar birds
    List<String> fallbackBirds = _getFallbackBirdsBasedOnPhonetics(excludeBird);
    
    for (String bird in fallbackBirds) {
      if (!_possibleBirds.contains(bird) && bird != excludeBird) {
        _possibleBirds.add(bird);
        _logDebug('Added fallback bird: $bird');
        if (_possibleBirds.length >= 3) break;
      }
    }
    
    // Ensure we have at least one bird - this is critical
    if (_possibleBirds.isEmpty) {
      _logDebug('No alternative birds found, adding defaults from all birds');
      List<String> allBirds = _birdService.birdNames;
      
      // If for some reason birdNames is empty, create a hard-coded fallback list
      if (allBirds.isEmpty) {
        _logDebug('WARNING: birdService.birdNames is empty! Using emergency fallback list');
        allBirds = ['Solsort', 'Musvit', 'Gråspurv', 'Blåmejse', 'Husskade'];
      }
      
      allBirds.shuffle();
      for (String bird in allBirds) {
        if (bird != excludeBird) {
          _possibleBirds.add(bird);
          _logDebug('Added default bird: $bird');
          if (_possibleBirds.length >= 3) break;
        }
      }
      
      // Final emergency failsafe - if still empty, add a hard-coded bird
      if (_possibleBirds.isEmpty) {
        _logDebug('EMERGENCY: Adding hard-coded fallback bird');
        _possibleBirds.add('Solsort');
      }
    }
    
    _logDebug('Final fallback birds count: ${_possibleBirds.length}');
  }

  // ----- Audio Handlers -----
  
  /// Handle different types of audio completion
  void _handleAudioCompletion(String playbackType) {
    switch (playbackType) {
      case 'bird_question':
        _transitionToState(RecognitionState.waitingForConfirmation);
        _resumeListeningForConfirmation();
        break;
        
      case 'bird_confirmation':
      case 'bird_denied':
      case 'okay_observation_er_slettet':
        _transitionToState(RecognitionState.idle);
        _resumeListeningAfterAudio();
        break;
        
      case 'start_listening':
        _transitionToState(RecognitionState.listening);
        if (!_speechService.isListening) {
          _speechService.startListening();
        }
        break;
        
      case 'stop_listening':
        _processRecognitionResults();
        break;
        
      case 'confirmation_timeout':
        _resumeListeningAfterAudio();
        break;

      case 'systemet_er_i_tvil':
        _transitionToState(RecognitionState.systemInDoubt);
        _resumeListeningForConfirmation();
        break;
    }
  }
  
  /// Resume listening specifically for confirmation
  void _resumeListeningForConfirmation() {
    _logDebug('Resuming listening specifically for confirmation');
    
    if (!_speechService.isListening) {
      _speechService.clearRecognizedText();
      _speechService.startListening();
      _logDebug('Now actively listening for confirmation response (ja/nej)');
    }
  }

  /// Resume listening after audio playback
  void _resumeListeningAfterAudio() {
    if (!_speechService.isListening) {
      _logDebug('Resuming listening after audio');
      _speechService.startListening();
    }
  }

  /// Pause listening for audio playback
  void _pauseListeningForAudio() {
    if (_speechService.isListening) {
      _speechService.stopListening();
    }
  }

  /// Process the final recognition results
  void _processRecognitionResults() {
    if (_currentState == RecognitionState.waitingForConfirmation) {
      _processConfirmationResponse();
    } 
    else if (_birdService.matchedBird.isNotEmpty && 
             _currentState != RecognitionState.processingBirdRecognition) {
      handleBirdRecognition(_birdService.matchedBird);
    }
  }

  /// Process confirmation response from recognized text
  void _processConfirmationResponse() {
    String text = _speechService.recognizedText.toLowerCase();
    _logDebug('Processing confirmation response from text: $text');
    
    if (_directCheckForPositiveResponse(text)) {
      _logDebug('Positive response detected in final text processing');
      handleConfirmationResponse(true);
    } 
    else if (_directCheckForNegativeResponse(text)) {
      _logDebug('Negative response detected in final text processing');
      
      // Important: Save the original bird name before processing the response
      final String originalBird = _currentBirdInQuestion;
      
      // Clear the text to prevent "nej" from being processed
      _speechService.clearRecognizedText();
      
      handleConfirmationResponse(false);
    } 
    else if (_isRepeatRequest(text)) {
      _logDebug('Repeating bird question for: $_currentBirdInQuestion');
      _audioService.playBirdQuestion(_currentBirdInQuestion);
    }
  }

  // ----- Helper Methods -----
  
  /// Reset all recognition services
  void _resetRecognitionServices() {
    _wordService.reset();
    _birdService.reset();
  }

  /// Transition to a new state
  void _transitionToState(RecognitionState newState) {
    _logDebug('State transition: $_currentState -> $newState');
    
    // Reset state-specific data when leaving certain states
    if (_currentState == RecognitionState.systemInDoubt && 
        newState != RecognitionState.systemInDoubt) {
      _possibleBirds = [];
    }
    
    if (_currentState == RecognitionState.waitingForConfirmation && 
        newState != RecognitionState.waitingForConfirmation && 
        newState != RecognitionState.processingConfirmation) {
      _currentBirdInQuestion = '';
    }
    
    _currentState = newState;
    notifyListeners();
  }

  /// Start confirmation timeout timer
  void _startConfirmationTimeout() {
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(Duration(seconds: _confirmationTimeoutSeconds), () {
      if (_currentState == RecognitionState.waitingForConfirmation || 
          _currentState == RecognitionState.systemInDoubt) {
        _logDebug('Confirmation timed out');
        _transitionToState(RecognitionState.idle);
        _audioService.playPrompt('confirmation_timeout');
      }
    });
  }

  /// Create and upload an observation
  Future<void> _createAndUploadObservation() async {
    BirdObservation? createdObservation = await _observationUploader.saveAndUploadObservation(
      _currentBirdInQuestion,
      quantity: 1,  // Default quantity
      observerId: 1 // Default observer ID
    );
    
    if (createdObservation != null) {
      _logDebug('Successfully saved and uploaded observation for $_currentBirdInQuestion');
      _latestObservation = createdObservation;
      notifyListeners();
    } else {
      _logDebug('Failed to save/upload observation: ${_observationUploader.errorMessage}');
    }
  }

  // ----- Helper methods for phonetic similarity -----
  
  /// Get fallback birds based on phonetic similarity
  List<String> _getFallbackBirdsBasedOnPhonetics(String birdName) {
    _logDebug('Getting phonetically similar birds to: $birdName');
    
    List<String> allBirds = _birdService.birdNames;
    if (allBirds.isEmpty) {
      _logDebug('WARNING: No birds in birdService.birdNames, using emergency list');
      return ['Solsort', 'Musvit', 'Gråspurv', 'Blåmejse', 'Husskade'];
    }
    
    // Skip if bird name is empty or just a response word
    if (birdName.isEmpty || 
        _isPositiveResponse(birdName.toLowerCase()) || 
        _isNegativeResponse(birdName.toLowerCase())) {
      _logDebug('Bird name is empty or a response word, using random birds');
      allBirds.shuffle();
      return allBirds.take(5).toList();
    }
    
    String firstLetter = birdName.isNotEmpty ? birdName[0].toLowerCase() : '';
    
    // Birds that start with the same letter
    List<String> similarBirds = allBirds
        .where((bird) => 
            bird != birdName && 
            bird.isNotEmpty && 
            bird[0].toLowerCase() == firstLetter)
        .toList();
    
    // Add birds with similar length if needed
    if (similarBirds.length < 5) {
      int targetLength = birdName.length;
      List<String> lengthSimilarBirds = allBirds
          .where((bird) => 
              bird != birdName && 
              !similarBirds.contains(bird) &&
              (bird.length >= targetLength - 2 && bird.length <= targetLength + 2))
          .toList();
      
      lengthSimilarBirds.shuffle();
      similarBirds.addAll(lengthSimilarBirds.take(5 - similarBirds.length));
    }
    
    // If somehow we still don't have enough birds, add some random ones
    if (similarBirds.length < 3) {
      _logDebug('Not enough similar birds found, adding random ones');
      List<String> randomBirds = allBirds
          .where((bird) => bird != birdName && !similarBirds.contains(bird))
          .toList();
      randomBirds.shuffle();
      similarBirds.addAll(randomBirds.take(5 - similarBirds.length));
    }
    
    similarBirds.shuffle();
    return similarBirds;
  }

  // ----- Text Analysis Utilities -----
  
  /// Direct check for positive responses
  bool _directCheckForPositiveResponse(String text) {
    // Check for single words
    if (text.trim() == "ja" || text.trim() == "yes" || text.trim() == "jo" || 
        text.trim() == "jep" || text.trim() == "jeps" || text.trim() == "ok" ||
        text.trim() == "okay" || text.trim() == "rigtigt") {
      return true;
    }
    
    // Check for phrases
    return text.contains(" ja ") || text.contains(" yes ") || 
           text.startsWith("ja ") || text.startsWith("yes ") ||
           text.endsWith(" ja") || text.endsWith(" yes") ||
           text.contains(" jo ") || text.startsWith("jo ") || text.endsWith(" jo") ||
           text.contains("correct") || text.contains("rigtigt");
  }

  /// Direct check for negative responses
  bool _directCheckForNegativeResponse(String text) {
    // Check for single words
    if (text.trim() == "nej" || text.trim() == "no" || text.trim() == "ikke" ||
        text.trim() == "forkert" || text.trim() == "næppe") {
      return true;
    }
    
    // Check for phrases
    return text.contains(" nej ") || text.contains(" no ") || 
           text.startsWith("nej ") || text.startsWith("no ") ||
           text.endsWith(" nej") || text.endsWith(" no") ||
           text.contains("ikke") || text.contains("forkert");
  }

  /// Check if a single word is a positive response
  bool _isPositiveResponse(String word) {
    return word == 'ja' || word == 'yes' || word == 'jeps' || word == 'yeah' || 
           word == 'jo' || word == 'okay' || word == 'ok' || word == 'jep' || 
           word == 'correct' || word == 'rigtigt';
  }

  /// Check if a single word is a negative response
  bool _isNegativeResponse(String word) {
    return word == 'nej' || word == 'no' || word == 'ikke' || 
           word == 'forkert' || word == 'næppe';
  }

  /// Check if text is a request to repeat
  bool _isRepeatRequest(String text) {
    return text.contains('gentag') || text.contains('hvad') || 
           text.contains('repeat') || text.contains('what') || 
           text.contains('undskyld');
  }

  /// Check if text contains a dismissal command
  bool _isDismissalCommand(String text) {
    return text.contains('ingen') || text.contains('none') || 
           text.contains('annuller') || text.contains('cancel');
  }

  // ----- Debugging Utilities -----
  
  /// Debug the current state
  void _debugCurrentState() {
    _logDebug('===== SPEECH COORDINATOR STATE DIAGNOSTIC =====');
    _logDebug('Current state: $_currentState');
    _logDebug('Is listening: ${_speechService.isListening}');
    _logDebug('Current bird in question: $_currentBirdInQuestion');
    _logDebug('Possible birds: ${_possibleBirds.join(", ")}');
    _logDebug('Recognized text: ${_speechService.recognizedText}');
    _logDebug('WordService special word: ${_wordService.recognizedSpecialWord}');
    _logDebug('BirdService matched bird: ${_birdService.matchedBird}');
    _logDebug('BirdService possible matches: ${_birdService.possibleMatches.join(", ")}');
    _logDebug('BirdService confidence: ${_birdService.confidence}');
    _logDebug('Is confirmation timer active: ${_confirmationTimer?.isActive}');
    _logDebug('Is manual input active: $_isManualInputActive');
    _logDebug('=============================================');
  }

  /// Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('SpeechCoordinator: $message');
    }
  }
}