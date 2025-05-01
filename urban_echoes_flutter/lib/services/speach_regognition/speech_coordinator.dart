import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/observation_uploader.dart';
import 'package:urban_echoes/services/recording_player_service.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/speech_recognition_service.dart';
import 'package:urban_echoes/services/speach_regognition/word_recognition.dart';

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
    // Listen for speech recognition updates
    _speechService.addListener(_onSpeechUpdate);
    _wordService.addListener(_onWordUpdate);
    
    // Add listener for audio completion events
    _audioService.addListener(_onAudioStateChanged);
  }

  final RecordingPlayerService _audioService;
  final BirdRecognitionService _birdService;
  final ObservationUploader _observationUploader; // Add this line
  String _currentBirdInQuestion = '';
  final bool _debugMode;
  // State for confirmation workflow
  bool _isWaitingForConfirmation = false;

  final SpeechRecognitionService _speechService;
  final WordRecognitionService _wordService;

  @override
  void dispose() {
    _speechService.removeListener(_onSpeechUpdate);
    _wordService.removeListener(_onWordUpdate);
    _audioService.removeListener(_onAudioStateChanged);
    super.dispose();
  }

  // Getters to expose underlying services
  SpeechRecognitionService get speechService => _speechService;

  BirdRecognitionService get birdService => _birdService;

  WordRecognitionService get wordService => _wordService;

  RecordingPlayerService get audioService => _audioService;

  bool get isListening => _speechService.isListening;

  String get recognizedText => _speechService.recognizedText;

  double get confidence => _speechService.confidence;

  String? get errorMessage => _speechService.errorMessage ??
                             _birdService.errorMessage;

  // Confirmation workflow getters
  bool get isWaitingForConfirmation => _isWaitingForConfirmation;

  String get currentBirdInQuestion => _currentBirdInQuestion;

  // Handle deletion of the last observation
  void handleDeleteObservation() {
    _logDebug('Handling delete observation command');
    
    // Stop listening temporarily while playing the audio response
    if (_speechService.isListening) {
      _speechService.stopListening();
    }
    
    // Play the confirmation audio
    _audioService.playPrompt('okay_observation_er_slettet');
    
    // Here you would typically delete the last observation from storage
    // Example: _databaseService.deleteLastObservation();
    
    // The audio completion handler will take care of resuming speech recognition
  }

  void handleBirdRecognition(String birdName) {
    if (birdName.isNotEmpty) {
      _logDebug('Handling bird recognition: $birdName');
      
      // Stop listening temporarily while playing the audio
      if (_speechService.isListening) {
        _speechService.stopListening();
      }
      
      // Play the bird question announcement with the two audio files in sequence
      _audioService.playBirdQuestion(birdName);
      
      // Set waiting for confirmation state
      _isWaitingForConfirmation = true;
      _currentBirdInQuestion = birdName;
      notifyListeners();
      
      // The audio completion listener will handle resuming the speech recognition
    }
  }

  // Updated handleConfirmationResponse method in SpeechCoordinator class
  void handleConfirmationResponse(bool confirmed) {
    if (!_isWaitingForConfirmation) return;
    
    _logDebug('Handling confirmation response: ${confirmed ? "Yes" : "No"}');
    
    // Stop listening temporarily while playing the audio response
    if (_speechService.isListening) {
      _speechService.stopListening();
    }
    
    if (confirmed) {
      // User confirmed the bird sighting
      // Play "Observation for [bird name] er oprettet" using the sequence method
      _audioService.playBirdConfirmation(_currentBirdInQuestion);
      
      // Save and upload the observation using ObservationUploader
      _observationUploader.saveAndUploadObservation(
        _currentBirdInQuestion,
        quantity: 1,  // Default quantity
        observerId: 1 // Default observer ID (you might want to make this configurable)
      ).then((success) {
        if (success) {
          _logDebug('Successfully saved and uploaded observation for $_currentBirdInQuestion');
        } else {
          _logDebug('Failed to save/upload observation: ${_observationUploader.errorMessage}');
          // Optionally, you could play an error sound or show a notification to the user
        }
      });
    } else {
      // User denied the bird sighting - play the deletion confirmation sound
      _audioService.playPrompt('okay_observation_er_slettet');
      
      // Optionally, if you need to do something when an observation is rejected
      // For example, logging that a suggestion was declined
    }
    
    // Reset confirmation state
    _isWaitingForConfirmation = false;
    _currentBirdInQuestion = '';
    notifyListeners();
    
    // The audio completion listener will handle resuming the speech recognition
  }

  // Methods to control speech recognition
  Future<bool> startListening() async {
    _logDebug('Starting listening through coordinator');
    
    // Stop any ongoing audio before starting to listen
    if (_audioService.isPlaying) {
      await _audioService.stopAudio();
    }
    
    // Reset existing results before starting
    _wordService.reset();
    _birdService.reset();
    
    // Start listening immediately instead of playing audio first
    return await _speechService.startListening();
  }

  Future<bool> stopListening() async {
    _logDebug('Stopping listening through coordinator');
    
    bool result = await _speechService.stopListening();
    
    // Play the stopping audio
    await _audioService.playPrompt('stop_listening');
    
    // The final recognition results will be processed after the audio completes
    // via the audio state change listener
    return result;
  }

  // Handle audio state changes
  void _onAudioStateChanged() {
    // If audio was playing and has now stopped
    if (!_audioService.isPlaying && _audioService.lastPlaybackType.isNotEmpty) {
      _logDebug('Audio completed: ${_audioService.lastPlaybackType}');
      
      // Handle different types of audio completion
      switch (_audioService.lastPlaybackType) {
        case 'bird_question':
          _resumeListeningAfterBirdQuestion();
          break;
        case 'bird_confirmation':
          _resumeListeningAfterConfirmation();
          break;
        case 'bird_denied':
          _resumeListeningAfterDenial();
          break;
        case 'okay_observation_er_slettet':
          _resumeListeningAfterObservationDeleted();
          break;
        case 'start_listening':
          // Start listening after the intro sound has completed
          if (!_speechService.isListening) {
            _speechService.startListening();
          }
          break;
        case 'stop_listening':
          // Process final recognition results after the stop sound
          _processRecognitionResults();
          break;
      }
      
      // Reset the last playback type after handling it
      _audioService.resetLastPlaybackType();
    }
  }

  // Resume listening after a bird question has played
  void _resumeListeningAfterBirdQuestion() {
    if (!_speechService.isListening) {
      _logDebug('Resuming listening after bird question');
      _speechService.startListening();
    }
  }

  // Resume listening after confirmation
  void _resumeListeningAfterConfirmation() {
    if (!_speechService.isListening) {
      _logDebug('Resuming listening after confirmation');
      _speechService.startListening();
    }
  }

  // Resume listening after denial
  void _resumeListeningAfterDenial() {
    if (!_speechService.isListening) {
      _logDebug('Resuming listening after denial');
      _speechService.startListening();
    }
  }

  // Resume listening after observation deleted message
  void _resumeListeningAfterObservationDeleted() {
    if (!_speechService.isListening) {
      _logDebug('Resuming listening after observation deleted');
      _speechService.startListening();
    }
  }

  // Handle speech recognition updates
  void _onSpeechUpdate() {
    if (_speechService.recognizedText.isNotEmpty) {
      _logDebug('Processing recognized text: ${_speechService.recognizedText}');
      
      // First try special words
      _wordService.processText(_speechService.recognizedText);
      
      // If no special word found, try bird names
      if (_wordService.recognizedSpecialWord.isEmpty) {
        _logDebug('No special word found, trying bird names');
        _birdService.processText(_speechService.recognizedText);
        
        // Check if a bird was recognized immediately after processing
        if (_birdService.matchedBird.isNotEmpty) {
          handleBirdRecognition(_birdService.matchedBird);
        }
      } else {
        _logDebug('Found special word: ${_wordService.recognizedSpecialWord}');
        // Handle special word "slet" or "delete" to delete the last observation
        if (_wordService.recognizedSpecialWord == 'slet' || 
            _wordService.recognizedSpecialWord == 'delete') {
          handleDeleteObservation();
        }
      }
    }
  }

  // Handle special word updates
  void _onWordUpdate() {
    if (_wordService.isConfirmationWord && _isWaitingForConfirmation) {
      _logDebug('Processing confirmation word: ${_wordService.recognizedSpecialWord}');
      
      // Handle Yes/No response
      if (_wordService.recognizedSpecialWord == 'ja') {
        handleConfirmationResponse(true);
      } else if (_wordService.recognizedSpecialWord == 'nej') {
        handleConfirmationResponse(false);
      }
    }
  }

  // Process the final recognition results
  void _processRecognitionResults() {
    // If already waiting for confirmation, we're in a dialog
    if (_isWaitingForConfirmation) {
      // Check for confirmation words in the recognized text
      String text = _speechService.recognizedText.toLowerCase();
      
      if (text.contains('ja') || text.contains('jo') || text.contains('yes') || 
          text.contains('jep') || text.contains('rigtigt')) {
        handleConfirmationResponse(true);
      } else if (text.contains('nej') || text.contains('no') || text.contains('ikke') || 
                text.contains('forkert')) {
        handleConfirmationResponse(false);
      }
      // Else continue waiting for confirmation
    } 
    // If not waiting for confirmation and a bird was recognized
    else if (_birdService.matchedBird.isNotEmpty) {
      handleBirdRecognition(_birdService.matchedBird);
    }
  }

  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('SpeechCoordinator: $message');
    }
  }
}