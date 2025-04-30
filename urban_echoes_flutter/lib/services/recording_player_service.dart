import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class RecordingPlayerService extends ChangeNotifier {
  // Two dedicated players for precise control
  final AudioPlayer _introPlayer = AudioPlayer();
  final AudioPlayer _birdPlayer = AudioPlayer();
  final AudioPlayer _outroPlayer = AudioPlayer(); // New player for the third part
  
  // State variables
  bool _isPlaying = false;
  bool _isMuted = false;
  final bool _debugMode;
  
  // Track what type of audio was last played
  String _lastPlaybackType = '';
  int _sequenceCompletedCount = 0;
  int _expectedCompletions = 0;
  
  // Constructor
  RecordingPlayerService({bool debugMode = false}) : _debugMode = debugMode {
    _initAudioPlayers();
  }
  
  void _initAudioPlayers() {
    // Setup completion listeners
    _introPlayer.onPlayerComplete.listen((_) {
      _logDebug('Intro playback completed');
      _sequenceCompletedCount++;
      _checkSequenceCompletion();
    });
    
    _birdPlayer.onPlayerComplete.listen((_) {
      _logDebug('Bird name playback completed');
      _sequenceCompletedCount++;
      _checkSequenceCompletion();
    });
    
    _outroPlayer.onPlayerComplete.listen((_) {
      _logDebug('Outro playback completed');
      _sequenceCompletedCount++;
      _checkSequenceCompletion();
    });
    
    _logDebug('Audio players initialized');
  }
  
  // Check if the sequence is complete and notify listeners
  void _checkSequenceCompletion() {
    if (_sequenceCompletedCount >= _expectedCompletions) {
      _logDebug('Audio sequence completed: $_lastPlaybackType');
      _isPlaying = false;
      _sequenceCompletedCount = 0;
      notifyListeners(); // This will trigger the onAudioStateChanged in SpeechCoordinator
    }
  }
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  String get lastPlaybackType => _lastPlaybackType;
  
  // Play bird question with callback-based timing
  Future<void> playBirdQuestion(String birdName) async {
    if (_isMuted) return;
    
    _logDebug('Playing bird question for: $birdName with callbacks');
    
    // Stop any current playback
    await stopAudio();
    
    try {
      // Reset sequence counter and set type
      _sequenceCompletedCount = 0;
      _expectedCompletions = 2; // Intro + Bird Name
      _lastPlaybackType = 'bird_question';
      
      // 1. Set up the completion handler for the intro
      _introPlayer.onPlayerComplete.listen((event) {
        _logDebug('Intro completed, playing bird name immediately');
        if (!_isMuted) {
          // Play bird name right after intro completes
          String simplifiedName = _simplifyName(birdName);
          String birdPath = 'audio/recorded/birds/$simplifiedName.mp3';
          _birdPlayer.play(AssetSource(birdPath));
        }
      }, cancelOnError: true);
      
      // 2. Start playing intro
      await _introPlayer.play(AssetSource('audio/recorded/har_du_observeret_en.mp3'));
      _isPlaying = true;
      notifyListeners();
      
    } catch (e) {
      _logDebug('Error in playBirdQuestion: $e');
      _isPlaying = false;
      _lastPlaybackType = '';
      notifyListeners();
    }
  }
  
  // Play confirmation with the callback-based sequence
  Future<void> playBirdConfirmation(String birdName) async {
    if (_isMuted) return;
    
    _logDebug('Playing bird confirmation for: $birdName with callbacks');
    
    // Stop any current playback
    await stopAudio();
    
    try {
      // Reset sequence counter and set type
      _sequenceCompletedCount = 0;
      _expectedCompletions = 3; // Part1 + Bird Name + Part3
      _lastPlaybackType = 'bird_confirmation';
      
      // Prepare files
      String simplifiedName = _simplifyName(birdName);
      String birdPath = 'audio/recorded/birds/$simplifiedName.mp3';
      
      // Set up one-time completion handler for part 1
      _introPlayer.onPlayerComplete.listen((event) {
        _logDebug('Part 1 completed, playing bird name immediately');
        if (!_isMuted) {
          _birdPlayer.play(AssetSource(birdPath));
        }
      }, cancelOnError: true);
      
      // Set up one-time completion handler for bird name
      _birdPlayer.onPlayerComplete.listen((event) {
        _logDebug('Bird name completed, playing part 3 immediately');
        if (!_isMuted) {
          _outroPlayer.play(AssetSource('audio/recorded/er_oprettet.mp3'));
        }
      }, cancelOnError: true);
      
      // Start the sequence with part 1
      _isPlaying = true;
      notifyListeners();
      await _introPlayer.play(AssetSource('audio/recorded/observation_for.mp3'));
      
    } catch (e) {
      _logDebug('Error in playBirdConfirmation: $e');
      _isPlaying = false;
      _lastPlaybackType = '';
      notifyListeners();
    }
  }
  
  // Regular prompt playback
  Future<void> playPrompt(String promptKey) async {
    if (_isMuted) return;
    
    try {
      _logDebug('Playing prompt: $promptKey');
      
      // Reset counters and set the last playback type
      _sequenceCompletedCount = 0;
      _expectedCompletions = 1;
      _lastPlaybackType = promptKey;
      
      // Special case for bird names
      if (promptKey.startsWith('bird_name:')) {
        final birdName = promptKey.substring('bird_name:'.length);
        String simplifiedName = _simplifyName(birdName);
        String path = 'audio/recorded/birds/$simplifiedName.mp3';
        
        await stopAudio();
        await _birdPlayer.play(AssetSource(path));
        _isPlaying = true;
        notifyListeners();
        return;
      }
      
      // Map standard prompts
      String path;
      switch (promptKey) {
        case 'har_du_observeret_en':
          path = 'audio/recorded/har_du_observeret_en.mp3';
          break;
        case 'observation_for':
          path = 'audio/recorded/observation_for.mp3';
          break;
        case 'er_oprettet':
          path = 'audio/recorded/er_oprettet.mp3';
          break;
        case 'start_listening':
          path = 'audio/recorded/start_listening.mp3';
          break;
        case 'stop_listening':
          path = 'audio/recorded/stop_listening.mp3';
          break;
        case 'bird_confirmed':
          path = 'audio/recorded/bird_confirmed.mp3';
          break;
        case 'bird_denied':
          path = 'audio/recorded/bird_denied.mp3';
          break;
        default:
          path = 'audio/silent.mp3';
      }
      
      await stopAudio();
      await _introPlayer.play(AssetSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error in playPrompt: $e');
      _isPlaying = false;
      _lastPlaybackType = '';
      notifyListeners();
    }
  }
  
  // Simplify Danish characters for filenames
  String _simplifyName(String name) {
    return name
        .replaceAll('æ', 'ae')
        .replaceAll('ø', 'o')
        .replaceAll('å', 'a')
        .replaceAll('Æ', 'Ae')
        .replaceAll('Ø', 'O')
        .replaceAll('Å', 'A')
        .toLowerCase()
        .trim();
  }
  
  // Play a specific bird sound directly
  Future<void> playBirdSound(String birdName) async {
    if (_isMuted) return;
    
    try {
      _logDebug('Playing bird sound: $birdName');
      
      // Reset counters and set type
      _sequenceCompletedCount = 0;
      _expectedCompletions = 1;
      _lastPlaybackType = 'bird_sound';
      
      String simplifiedName = _simplifyName(birdName);
      String path = 'audio/recorded/birds/$simplifiedName.mp3';
      
      await stopAudio();
      await _birdPlayer.play(AssetSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing bird sound: $e');
      _isPlaying = false;
      _lastPlaybackType = '';
      notifyListeners();
    }
  }
  
  // Stop audio playback
  Future<void> stopAudio() async {
    // Stop all players
    await _introPlayer.stop();
    await _birdPlayer.stop();
    await _outroPlayer.stop();
    
    // Reset state
    _isPlaying = false;
    _sequenceCompletedCount = 0;
    // We don't reset _lastPlaybackType here so that the coordinator can still respond to it
    
    notifyListeners();
  }
  
  // Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;
    _logDebug('Mute state changed: $_isMuted');
    
    if (_isMuted && _isPlaying) {
      stopAudio();
    }
    
    notifyListeners();
  }
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('RecordingPlayerService: $message');
    }
  }
  
  // Reset the last playback type (useful after handling completion)
  void resetLastPlaybackType() {
    _lastPlaybackType = '';
  }
  
  // Clean up resources
  @override
  void dispose() {
    _logDebug('Disposing audio players');
    _introPlayer.dispose();
    _birdPlayer.dispose();
    _outroPlayer.dispose();
    super.dispose();
  }
}