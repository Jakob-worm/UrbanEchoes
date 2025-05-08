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

  late RecordingPlayerService _audioService;
  late BirdRecognitionService _birdService;
  final int _confirmationTimeoutSeconds = 15;
  Timer? _confirmationTimer;
  String _currentBirdInQuestion = '';
  // State management
  RecognitionState _currentState = RecognitionState.idle;

  // Configuration
  final bool _debugMode;

  // Observation tracking
  BirdObservation? _latestObservation;

  final ObservationUploader _observationUploader;
  List<String> _possibleBirds = [];
  // Services
  late SpeechRecognitionService _speechService;

  late WordRecognitionService _wordService;

  @override
  void dispose() {
    _removeListeners();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  bool _isManualInputActive = false;
  final BirdDataLoader birdDataLoader = BirdDataLoader();

  // Getters
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

  // Service access (for testing and external control)
  SpeechRecognitionService get speechService => _speechService;

  BirdRecognitionService get birdService => _birdService;

  WordRecognitionService get wordService => _wordService;

  RecordingPlayerService get audioService => _audioService;

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
  
  _logDebug('Handling confirmation response: ${confirmed ? "Yes" : "No"}');
  
  // Stop listening while playing audio
  _pauseListeningForAudio();
  
  if (confirmed) {
    // Transition to confirmation processing state for "yes"
    _transitionToState(RecognitionState.processingConfirmation);
    
    // User confirmed bird sighting
    _audioService.playBirdConfirmation(_currentBirdInQuestion);
    
    // Save and upload observation
    await _createAndUploadObservation();
  } else {
    // For "no" response, we want to find birds with similar phonetic patterns
    
    // First, check if we already have multiple possible matches from previous processing
    if (_birdService.possibleMatches.length > 1) {
      // Use the existing possible matches, which are already sorted by confidence
      _possibleBirds = _birdService.possibleMatches
          .where((bird) => bird != _currentBirdInQuestion)
          .take(3)
          .toList();
      
      _logDebug('Using existing matches sorted by confidence: ${_possibleBirds.join(", ")}');
    } else {
      // We need to find phonetically similar birds
      // Process the current bird name to find phonetically similar birds
      _birdService.processText(_currentBirdInQuestion);
      
      // Now check if we have matches again
      if (_birdService.possibleMatches.length > 1) {
        _possibleBirds = _birdService.possibleMatches
            .where((bird) => bird != _currentBirdInQuestion)
            .take(3)
            .toList();
        
        _logDebug('Using phonetic matches: ${_possibleBirds.join(", ")}');
      } else {
        // As a last resort, process the entire recognized text again
        _birdService.processText(_speechService.recognizedText);
        
        _possibleBirds = _birdService.possibleMatches
            .where((bird) => bird != _currentBirdInQuestion)
            .take(3)
            .toList();
        
        _logDebug('Using text processing matches: ${_possibleBirds.join(", ")}');
      }
    }
    
    // If we still don't have enough options, add some phonetically similar birds
    if (_possibleBirds.length < 3) {
      // Get some fallback birds
      List<String> fallbackBirds = _getFallbackBirdsBasedOnPhonetics(_currentBirdInQuestion);
      
      // Add them to our list without duplicates
      for (String bird in fallbackBirds) {
        if (!_possibleBirds.contains(bird) && bird != _currentBirdInQuestion) {
          _possibleBirds.add(bird);
          if (_possibleBirds.length >= 3) break;
        }
      }
    }
    
    _logDebug('Final possible birds by confidence: ${_possibleBirds.join(", ")}');
    
    // Set the state and then play the audio
    _transitionToState(RecognitionState.systemInDoubt);
    
    // Play the system in doubt prompt
    _audioService.playPrompt('systemet_er_i_tvil');
    
    // Extra notification to ensure UI updates
    notifyListeners();
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

/// Process voice command in system in doubt state
void processVoiceCommandInDoubtState(String command) {
  if (_currentState != RecognitionState.systemInDoubt) return;
  
  _logDebug('Processing voice command in doubt state: $command');
  
  String lowerCommand = command.toLowerCase();
  
  // Check if the command contains any bird name from the possible birds list
  for (String bird in _possibleBirds) {
    if (lowerCommand.contains(bird.toLowerCase())) {
      _logDebug('Found bird name in command: $bird');
      handleBirdSelection(bird);
      return;
    }
  }
  
  // If no bird name found, check for dismissal commands
  if (lowerCommand.contains('ingen') || 
      lowerCommand.contains('none') || 
      lowerCommand.contains('annuller') || 
      lowerCommand.contains('cancel')) {
    _logDebug('Dismiss command detected');
    resetConfirmationState();
  }
}

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

// Helper method to get fallback birds based on phonetic similarity
List<String> _getFallbackBirdsBasedOnPhonetics(String birdName) {
  // This is a simplified approach - in a real implementation, you'd want
  // to use a more sophisticated phonetic algorithm
  
  // Get all available birds
  List<String> allBirds = _birdService.birdNames;
  
  // Simple logic: prefer birds that start with the same first letter
  String firstLetter = birdName.isNotEmpty ? birdName[0].toLowerCase() : '';
  
  // Filter birds that start with the same letter and aren't the original bird
  List<String> similarBirds = allBirds
      .where((bird) => 
          bird != birdName && 
          bird.isNotEmpty && 
          bird[0].toLowerCase() == firstLetter)
      .toList();
  
  // If we don't have enough, add more birds
  if (similarBirds.length < 5) {
    // Add birds that have similar length
    int targetLength = birdName.length;
    List<String> lengthSimilarBirds = allBirds
        .where((bird) => 
            bird != birdName && 
            !similarBirds.contains(bird) &&
            (bird.length >= targetLength - 2 && bird.length <= targetLength + 2))
        .toList();
    
    // Shuffle these to get some variety
    lengthSimilarBirds.shuffle();
    
    // Add them to our similar birds list
    similarBirds.addAll(lengthSimilarBirds.take(5 - similarBirds.length));
  }
  
  // Shuffle and return
  similarBirds.shuffle();
  return similarBirds;
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
  
  // Handle system in doubt state specially
  if (_currentState == RecognitionState.systemInDoubt) {
    processVoiceCommandInDoubtState(recognizedText);
    return;
  }
  
  // Skip processing if in confirmation or doubt flow
  if (_currentState == RecognitionState.waitingForConfirmation || 
      _currentState == RecognitionState.processingBirdRecognition) {
    _logDebug('Skipping recognition processing - already in confirmation flow');
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
    // Process confirmation words when waiting for confirmation
    if (_wordService.isConfirmationWord) {
      _logDebug('Processing confirmation word: ${_wordService.recognizedSpecialWord}');
      
      String word = _wordService.recognizedSpecialWord;
      
      // Check if we're in a state where confirmation is relevant
      if (_currentState == RecognitionState.waitingForConfirmation || 
          _currentState == RecognitionState.systemInDoubt) {
        
        // Process positive responses
        if (_isPositiveResponse(word)) {
          _logDebug('Positive response detected: $word');
          handleConfirmationResponse(true);
        } 
        // Process negative responses
        else if (_isNegativeResponse(word)) {
          _logDebug('Negative response detected: $word');
          handleConfirmationResponse(false);
        }
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

void activateManualInput() {
  _logDebug('Activating manual input mode');
  _isManualInputActive = true;
  
  // Play the audio prompt for manual bird input
  _audioService.playPrompt('indtast_den_fulg_du_så');
  
  notifyListeners();
}

void deactivateManualInput() {
  _isManualInputActive = false;
  notifyListeners();
}

void handleManualBirdSelection(String birdName) {
  if (birdName.isNotEmpty) {
    // Clear any previous recognition state
    _birdService.reset();
    
    // Process the exact bird name to set it as the matched bird
    // This will set _matchedBird and confidence in the bird service
    _birdService.processText(birdName);
    
    // Set the current bird in question for confirmation
    _currentBirdInQuestion = birdName;
    
    // Turn off manual input mode
    _isManualInputActive = false;
    
    // Start confirmation timeout
    _startConfirmationTimeout();
    
    // Transition to waiting for confirmation
    _transitionToState(RecognitionState.waitingForConfirmation);
    
    // Optionally play the confirmation audio
    _audioService.playBirdQuestion(birdName);
  }
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
  return word == 'ja' || word == 'yes' || word == 'jeps' || word == 'yeah' || 
         word == 'jo' || word == 'okay' || word == 'ok' || word == 'jep' || 
         word == 'correct' || word == 'rigtigt';
}

/// Check if a single word is a negative response
bool _isNegativeResponse(String word) {
  return word == 'nej' || word == 'no' || word == 'ikke' || 
         word == 'forkert' || word == 'næppe';
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