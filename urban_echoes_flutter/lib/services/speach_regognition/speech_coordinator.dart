import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/models/bird_observation.dart';
import 'package:urban_echoes/services/observation/observation_uploader.dart';
import 'package:urban_echoes/services/recording_player_service.dart';
import 'package:urban_echoes/services/service_config.dart';
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
  // Constructor
  SpeechCoordinator({
    required SpeechRecognitionService speechService,
    required BirdRecognitionService birdService,
    required WordRecognitionService wordService,
    required RecordingPlayerService audioService,
    required ObservationUploader observationUploader,
    bool? debugMode,
  }) : _speechService = speechService,
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
  String _currentBirdInQuestion = '';
  List<String> _possibleBirds = [];
  Timer? _confirmationTimer;
  
  // Observation tracking
  BirdObservation? _latestObservation;

  // Getters
  RecognitionState get currentState => _currentState;
  bool get isListening => _speechService.isListening;
  String get recognizedText => _speechService.recognizedText;
  double get confidence => _speechService.confidence;
  String? get errorMessage => _speechService.errorMessage ?? _birdService.errorMessage;
  bool get isWaitingForConfirmation => _currentState == RecognitionState.waitingForConfirmation;
  bool get isSystemInDoubt => _currentState == RecognitionState.systemInDoubt;
  String get currentBirdInQuestion => _currentBirdInQuestion;
  List<String> get possibleBirds => _possibleBirds;
  BirdObservation? get latestObservation => _latestObservation;
  
  // Service access (for testing and external control)
  SpeechRecognitionService get speechService => _speechService;
  BirdRecognitionService get birdService => _birdService;
  WordRecognitionService get wordService => _wordService;
  RecordingPlayerService get audioService => _audioService;

  /// Initialize all service listeners
  void _initializeListeners() {
    _speechService.addListener(_onSpeechUpdate);
    _wordService.addListener(_onWordUpdate);
    _audioService.addListener(_onAudioStateChanged);
    _logDebug('Service listeners initialized');
  }

  @override
  void dispose() {
    _removeListeners();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  /// Remove all service listeners
  void _removeListeners() {
    _speechService.removeListener(_onSpeechUpdate);
    _wordService.removeListener(_onWordUpdate);
    _audioService.removeListener(_onAudioStateChanged);
    _logDebug('Service listeners removed');
  }

  /// Update services without recreating the coordinator
  void updateServices({
    SpeechRecognitionService? speechService,
    BirdRecognitionService? birdService,
    WordRecognitionService? wordService,
    RecordingPlayerService? audioService,
  }) {
    _logDebug('Updating services in SpeechCoordinator');
    
    // Remove listeners from old services
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

  //
  // ----- Workflow Entry Points -----
  //

  /// Start listening for speech input
  Future<bool> startListening() async {
    _logDebug('Starting listening through coordinator');
    
    // Reset state to ensure clean start
    _transitionToState(RecognitionState.idle);
    
    // Stop any ongoing audio before starting to listen
    if (_audioService.isPlaying) {
      await _audioService.stopAudio();
    }
    
    // Reset services
    _resetRecognitionServices();
    
    // Start listening
    bool result = await _speechService.startListening();
    if (result) {
      _transitionToState(RecognitionState.listening);
    }
    
    return result;
  }

  /// Stop listening for speech input
  Future<bool> stopListening() async {
    _logDebug('Stopping listening through coordinator');
    
    // Stop listening
    bool result = await _speechService.stopListening();
    
    // Play the stopping audio
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

  //
  // ----- Bird Recognition Handlers -----
  //

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
    
    // Set bird in question
    _currentBirdInQuestion = birdName;
    
    // Stop listening while playing audio
    _pauseListeningForAudio();
    
    // Start confirmation timeout
    _startConfirmationTimeout();
    
    // Play bird question
    _audioService.playBirdQuestion(birdName);
    
    // State will transition to waitingForConfirmation after audio completes
  }

  /// Handle when the system is in doubt between multiple birds
  void handleSystemInDoubt(List<String> birds) {
    // Skip if already processing or no birds
    if (_currentState == RecognitionState.processingBirdRecognition || 
        _currentState == RecognitionState.systemInDoubt || 
        birds.isEmpty) {
      return;
    }
    
    _logDebug('System is in doubt about: ${birds.join(", ")}');
    _transitionToState(RecognitionState.processingBirdRecognition);
    
    // Save possible birds (limit to 3)
    _possibleBirds = birds.take(3).toList();
    
    // Stop listening while playing audio
    _pauseListeningForAudio();
    
    // Start confirmation timeout
    _startConfirmationTimeout();
    
    // Play system in doubt prompt
    _audioService.playPrompt('systemet_er_i_tvil');
    
    // Will transition to systemInDoubt state after audio completes
  }

  /// Handle bird selection from the doubt UI
  void handleBirdSelection(String selectedBird) {
    // Cancel the timeout timer
    _confirmationTimer?.cancel();
    
    _logDebug('Bird selected from doubt UI: $selectedBird');
    
    // Reset doubt state
    _possibleBirds = [];
    
    // Continue with normal bird recognition flow
    handleBirdRecognition(selectedBird);
  }

  /// Handle deletion of the last observation
  void handleDeleteObservation() {
    _logDebug('Handling delete observation command');
    
    // Stop listening while playing audio
    _pauseListeningForAudio();
    
    // Play confirmation audio
    _audioService.playPrompt('okay_observation_er_slettet');
    
    // Implement deletion logic here
    // Example: _databaseService.deleteLastObservation();
  }

  /// Handle user's confirmation response (yes/no)
  Future<void> handleConfirmationResponse(bool confirmed) async {
    // Validate state
    if (_currentState != RecognitionState.waitingForConfirmation) {
      return;
    }
    
    // Cancel timeout timer
    _confirmationTimer?.cancel();
    
    // Transition to confirmation processing state
    _transitionToState(RecognitionState.processingConfirmation);
    
    _logDebug('Handling confirmation response: ${confirmed ? "Yes" : "No"}');
    
    // Stop listening while playing audio
    _pauseListeningForAudio();
    
    if (confirmed) {
      // User confirmed bird sighting
      _audioService.playBirdConfirmation(_currentBirdInQuestion);
      
      // Save and upload observation
      await _createAndUploadObservation();
    } else {
      // User denied bird sighting
      _audioService.playPrompt('okay_observation_er_slettet');
    }
    
    // State will reset after audio completes
  }

  //
  // ----- Event Handlers -----
  //

  /// Handle audio state changes
  void _onAudioStateChanged() {
    // If audio was playing and has now stopped
    if (!_audioService.isPlaying && _audioService.lastPlaybackType.isNotEmpty) {
      _logDebug('Audio completed: ${_audioService.lastPlaybackType}');
      
      // Handle different audio completion events based on playback type
      _handleAudioCompletion(_audioService.lastPlaybackType);
      
      // Reset the last playback type
      _audioService.resetLastPlaybackType();
    }
  }

  /// Handle speech recognition updates
  void _onSpeechUpdate() {
    String recognizedText = _speechService.recognizedText;
    if (recognizedText.isEmpty) return;
    
    _logDebug('Processing recognized text: $recognizedText');
    
    // Skip processing if in confirmation or doubt flow
    if (_currentState == RecognitionState.waitingForConfirmation || 
        _currentState == RecognitionState.processingBirdRecognition || 
        _currentState == RecognitionState.systemInDoubt) {
      _logDebug('Skipping recognition processing - already in confirmation or doubt flow');
      return;
    }
    
    // Process for special words first
    _wordService.processText(recognizedText);
    
    // If no special word found, try bird names
    if (_wordService.recognizedSpecialWord.isEmpty) {
      _processBirdNames(recognizedText);
    } else {
      _processSpecialWords(_wordService.recognizedSpecialWord);
    }
  }

  /// Handle special word updates
  void _onWordUpdate() {
    // Only process confirmation words when waiting for confirmation
    if (_wordService.isConfirmationWord && _currentState == RecognitionState.waitingForConfirmation) {
      _logDebug('Processing confirmation word: ${_wordService.recognizedSpecialWord}');
      
      String word = _wordService.recognizedSpecialWord;
      
      // Process positive responses
      if (_isPositiveResponse(word)) {
        handleConfirmationResponse(true);
      } 
      // Process negative responses
      else if (_isNegativeResponse(word)) {
        handleConfirmationResponse(false);
      }
    }
  }

  //
  // ----- Helper Methods -----
  //

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
    
    // Update state
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
        
        // Reset state
        _transitionToState(RecognitionState.idle);
        
        // Play timeout sound
        _audioService.playPrompt('confirmation_timeout');
      }
    });
  }

  /// Pause listening for audio playback
  void _pauseListeningForAudio() {
    if (_speechService.isListening) {
      _speechService.stopListening();
    }
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
      // Optional error handling here
    }
  }

  void resetConfirmationState() {
  _logDebug('Resetting confirmation state');
  _confirmationTimer?.cancel();
  _currentBirdInQuestion = '';
  _possibleBirds = [];
  _transitionToState(RecognitionState.idle);
  notifyListeners();
}

  /// Process bird names in recognized text
  void _processBirdNames(String text) {
    _logDebug('No special word found, trying bird names');
    _birdService.processText(text);
    
    // Handle multiple possible matches with low confidence
    if (_birdService.possibleMatches.length > 1 && _birdService.confidence < 0.7) {
      handleSystemInDoubt(_birdService.possibleMatches);
    }
    // Handle single bird with high confidence
    else if (_birdService.matchedBird.isNotEmpty) {
      handleBirdRecognition(_birdService.matchedBird);
    }
  }

  /// Process special words in recognized text
  void _processSpecialWords(String word) {
    _logDebug('Found special word: $word');
    
    // Handle "delete" command
    if (word == 'slet' || word == 'delete') {
      handleDeleteObservation();
    }
    // Add other special word handlers here
  }

  /// Handle different types of audio completion
  void _handleAudioCompletion(String playbackType) {
    switch (playbackType) {
      case 'bird_question':
        _transitionToState(RecognitionState.waitingForConfirmation);
        _resumeListeningAfterAudio();
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
        break;
    }
  }

  /// Resume listening after audio playback
  void _resumeListeningAfterAudio() {
    if (!_speechService.isListening) {
      _logDebug('Resuming listening after audio');
      _speechService.startListening();
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
    
    // Check for different types of responses
    if (_containsPositiveResponse(text)) {
      handleConfirmationResponse(true);
    } 
    else if (_containsNegativeResponse(text)) {
      handleConfirmationResponse(false);
    } 
    else if (_isRepeatRequest(text)) {
      // Repeat the bird question
      _logDebug('Repeating bird question for: $_currentBirdInQuestion');
      _audioService.playBirdQuestion(_currentBirdInQuestion);
    }
    // Otherwise continue waiting for confirmation
  }

  /// Check if a single word is a positive response
  bool _isPositiveResponse(String word) {
    return word == 'ja' || word == 'yes' || word == 'jeps' || word == 'yeah';
  }

  /// Check if a single word is a negative response
  bool _isNegativeResponse(String word) {
    return word == 'nej' || word == 'no';
  }

  /// Check if text contains a positive response
  bool _containsPositiveResponse(String text) {
    return text.contains('ja') || text.contains('jo') || 
           text.contains('yes') || text.contains('jep') || 
           text.contains('rigtigt') || text.contains('okay') || 
           text.contains('selvfølgelig') || text.contains('naturligvis');
  }

  /// Check if text contains a negative response
  bool _containsNegativeResponse(String text) {
    return text.contains('nej') || text.contains('no') || 
           text.contains('ikke') || text.contains('forkert') || 
           text.contains('næppe');
  }

  /// Check if text is a request to repeat
  bool _isRepeatRequest(String text) {
    return text.contains('gentag') || text.contains('hvad') || 
           text.contains('repeat') || text.contains('what') || 
           text.contains('undskyld');
  }

  /// Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('SpeechCoordinator: $message');
    }
  }
}