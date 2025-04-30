import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class RecordingPlayerService extends ChangeNotifier {
  // Two dedicated players for precise control
  final AudioPlayer _introPlayer = AudioPlayer();
  final AudioPlayer _birdPlayer = AudioPlayer();
  
  // Add this state variable - it's used by SpeechCoordinator
  bool _isPlaying = false;
  bool _isMuted = false;
  final bool _debugMode;
  
  // Fixed intro durations for timing in milliseconds
  final Map<String, int> _introDurations = {
    'har_du_observeret_en': 1500,
    'du_har_observeret_en': 1500,
  };
  
  // Constructor
  RecordingPlayerService({bool debugMode = false}) : _debugMode = debugMode {
    _initAudioPlayers();
  }
  
  void _initAudioPlayers() {
    // Setup completion listeners
    _introPlayer.onPlayerComplete.listen((_) {
      _logDebug('Intro playback completed');
      // Only set isPlaying to false if bird player is also not playing
      if (!_birdIsPlaying) {
        _isPlaying = false;
        notifyListeners();
      }
    });
    
    _birdPlayer.onPlayerComplete.listen((_) {
      _logDebug('Bird name playback completed');
      // Always set isPlaying to false when bird name completes
      _isPlaying = false;
      notifyListeners();
    });
    
    _logDebug('Audio players initialized');
  }
  
  // CRITICAL: Add this getter for SpeechCoordinator compatibility
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  bool get _birdIsPlaying => false; // Helper method to check bird player state
  
  // Play bird question with precise timing
  Future<void> playBirdQuestion(String birdName) async {
    if (_isMuted) return;
    
    _logDebug('Playing bird question for: $birdName with precise timing');
    
    // Stop any current playback
    await stopAudio();
    
    try {
      // 1. Prepare both audio files
      _logDebug('Preparing intro and bird audio');
      
      // Get duration either from map or use default
      final introDuration = _introDurations['har_du_observeret_en'] ?? 1500; 
      
      // Calculate when to start bird name (milliseconds before intro ends)
      final birdNameStartOffset = 200; // Adjust this value as needed
      final birdNameStartTime = introDuration - birdNameStartOffset;
      
      _logDebug('Intro duration: ${introDuration}ms, starting bird name ${birdNameStartOffset}ms before end');
      
      // 2. Start playing intro
      await _introPlayer.play(AssetSource('audio/recorded/har_du_observeret_en.mp3'));
      _isPlaying = true;
      notifyListeners();
      
      // 3. Set up timer to start bird name at precise moment
      Future.delayed(Duration(milliseconds: birdNameStartTime), () async {
        if (!_isMuted) {
          _logDebug('Starting bird name at timed offset');
          
          // Get the bird name file path
          String simplifiedName = _simplifyName(birdName);
          String birdPath = 'audio/recorded/birds/$simplifiedName.mp3';
          
          // Play bird name on its own player
          await _birdPlayer.play(AssetSource(birdPath));
        }
      });
      
    } catch (e) {
      _logDebug('Error in playBirdQuestion: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }
  
  // Play bird confirmation with precise timing
  Future<void> playBirdConfirmation(String birdName) async {
    if (_isMuted) return;
    
    _logDebug('Playing bird confirmation for: $birdName with precise timing');
    
    // Stop any current playback
    await stopAudio();
    
    try {
      // 1. Prepare both audio files
      _logDebug('Preparing confirmation and bird audio');
      
      // Get duration either from map or use default
      final introDuration = _introDurations['du_har_observeret_en'] ?? 1500; 
      
      // Calculate when to start bird name (milliseconds before intro ends)
      final birdNameStartOffset = 200; // Adjust this value as needed
      final birdNameStartTime = introDuration - birdNameStartOffset;
      
      _logDebug('Confirmation duration: ${introDuration}ms, starting bird name ${birdNameStartOffset}ms before end');
      
      // 2. Start playing confirmation
      await _introPlayer.play(AssetSource('audio/recorded/du_har_observeret_en.mp3'));
      _isPlaying = true;
      notifyListeners();
      
      // 3. Set up timer to start bird name at precise moment
      Future.delayed(Duration(milliseconds: birdNameStartTime), () async {
        if (!_isMuted) {
          _logDebug('Starting bird name at timed offset');
          
          // Get the bird name file path
          String simplifiedName = _simplifyName(birdName);
          String birdPath = 'audio/recorded/birds/$simplifiedName.mp3';
          
          // Play bird name on its own player
          await _birdPlayer.play(AssetSource(birdPath));
        }
      });
      
    } catch (e) {
      _logDebug('Error in playBirdConfirmation: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }
  
  // Regular prompt playback
  Future<void> playPrompt(String promptKey) async {
    if (_isMuted) return;
    
    try {
      _logDebug('Playing prompt: $promptKey');
      
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
        case 'du_har_observeret_en':
          path = 'audio/recorded/du_har_observeret_en.mp3';
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
          path = 'audio/seilent.mp3';
      }
      
      await stopAudio();
      await _introPlayer.play(AssetSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error in playPrompt: $e');
      _isPlaying = false;
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
      
      String simplifiedName = _simplifyName(birdName);
      String path = 'audio/recorded/birds/$simplifiedName.mp3';
      
      await stopAudio();
      await _birdPlayer.play(AssetSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing bird sound: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }
  
  // Try to play a test bird sound from the Test directory
  Future<void> playTestBirdSound() async {
    if (_isMuted) return;
    
    try {
      _logDebug('Attempting to play test bird sound');
      
      // Try the test bird sound you listed in your assets
      final path = 'audio/Test/XC521615 - Blåmejse - Cyanistes caeruleus.mp3';
      
      await stopAudio();
      await _birdPlayer.play(AssetSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing test bird sound: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }
  
  // Stop audio playback
  Future<void> stopAudio() async {
    // Stop both players
    await _introPlayer.stop();
    await _birdPlayer.stop();
    
    _isPlaying = false;
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
  
  // Clean up resources
  @override
  void dispose() {
    _logDebug('Disposing audio players');
    _introPlayer.dispose();
    _birdPlayer.dispose();
    super.dispose();
  }
}