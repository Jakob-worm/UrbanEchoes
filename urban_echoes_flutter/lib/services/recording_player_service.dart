import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class RecrodingPlayerService extends ChangeNotifier {
  // Create a pool of audio players to avoid resource conflicts
  final List<AudioPlayer> _playerPool = [];
  int _currentPlayerIndex = 0;
  bool _isPlaying = false;
  bool _isMuted = false;
  final bool _debugMode;
  
  // For sequential playback
  final List<String> _playbackQueue = [];
  bool _isProcessingQueue = false;
  
  // Constructor
  RecrodingPlayerService({bool debugMode = false}) : _debugMode = debugMode {
    _initAudioPlayers();
  }
  
  void _initAudioPlayers() {
    // Create 5 players to ensure we have enough for sequences
    for (int i = 0; i < 5; i++) {
      final player = AudioPlayer();
      
      player.onPlayerComplete.listen((_) {
        if (_currentPlayerIndex == i) {
          _logDebug('Player $i completed playback');
          _isPlaying = false;
          notifyListeners();
          
          // Process next item in queue if needed
          if (_isProcessingQueue) {
            _processNextInQueue();
          }
        }
      });
      
      
      _playerPool.add(player);
    }
    
    _logDebug('Created ${_playerPool.length} audio players in pool');
  }
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  
  // Get next available player
  AudioPlayer _getNextPlayer() {
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerPool.length;
    _logDebug('Using player $_currentPlayerIndex');
    return _playerPool[_currentPlayerIndex];
  }
  
  // Play audio prompt from assets
  Future<void> playPrompt(String promptKey) async {
    if (_isMuted) return;
    
    try {
      _logDebug('Playing audio prompt: $promptKey');
      
      String path;
      
      // Special case for bird names
      if (promptKey.startsWith('bird_name:')) {
        final birdName = promptKey.substring('bird_name:'.length);
        _logDebug('Attempting to play bird name: $birdName');
        
        // Convert special characters and make lowercase for filenames
        String simplifiedName = _simplifyName(birdName);
        
        // Try the bird name file first
        path = 'audio/recorded/birds/$simplifiedName.mp3';
        
        // As a fallback, we'll try to play the original file if simplified version fails
        final player = _getNextPlayer();
        await player.stop();
        
        try {
          await player.play(AssetSource(path));
          _isPlaying = true;
          notifyListeners();
          return;
        } catch (e) {
          _logDebug('Failed to play bird name: $e');
          
          // Fall back to silent audio as a last resort
          path = 'audio/seilent.mp3';
        }
      } else {
        // Map standard prompts
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
            // Default to silent audio if nothing matches
            path = 'audio/seilent.mp3';
        }
      }
      
      _logDebug('Using path: $path');
      
      // Get a fresh player from the pool
      final player = _getNextPlayer();
      
      // Stop any current playback
      await player.stop();
      
      // Play the audio file
      await player.play(AssetSource(path));
      
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing audio: $e');
      
      // Continue with next item if this was part of a sequence
      if (_isProcessingQueue) {
        _playbackQueue.isEmpty ? _isProcessingQueue = false : _processNextInQueue();
      }
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
  
  // Try to play a specific bird sound directly
  Future<void> playBirdSound(String birdName) async {
    try {
      _logDebug('Directly playing bird sound: $birdName');
      
      // Simplify the name for filename
      String simplifiedName = _simplifyName(birdName);
      String path = 'audio/recorded/birds/$simplifiedName.mp3';
      
      final player = _getNextPlayer();
      await player.stop();
      
      // Try to play the bird sound
      await player.play(AssetSource(path));
      
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing bird sound: $e');
    }
  }
  
  // Try to play a test bird sound from the Test directory
  Future<void> playTestBirdSound() async {
    try {
      _logDebug('Attempting to play test bird sound');
      
      // Try the test bird sound you listed in your assets
      final path = 'audio/Test/XC521615 - Blåmejse - Cyanistes caeruleus.mp3';
      
      final player = _getNextPlayer();
      await player.stop();
      
      // Try to play the test bird sound
      await player.play(AssetSource(path));
      
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing test bird sound: $e');
    }
  }
  
  // Play a bird question (plays two audio files in sequence)
  Future<void> playBirdQuestion(String birdName) async {
    if (_isMuted) return;
    
    _logDebug('Playing bird question for: $birdName');
    
    // Cancel any current playback and clear queue
    await stopAudio();
    _playbackQueue.clear();
    
    // Add the intro and bird name to the queue
    _playbackQueue.add('har_du_observeret_en');
    _playbackQueue.add('bird_name:$birdName');
    
    // Start processing the queue
    _isProcessingQueue = true;
    _processNextInQueue();
  }
  
  // Play confirmation response for bird observation
  Future<void> playBirdConfirmation(String birdName) async {
    if (_isMuted) return;
    
    _logDebug('Playing bird confirmation for: $birdName');
    
    // Cancel any current playback and clear queue
    await stopAudio();
    _playbackQueue.clear();
    
    // Add the confirmation message and bird name to the queue
    _playbackQueue.add('du_har_observeret_en');
    _playbackQueue.add('bird_name:$birdName');
    
    // Start processing the queue
    _isProcessingQueue = true;
    _processNextInQueue();
  }
  
  // Process the next audio in the queue
  Future<void> _processNextInQueue() async {
    if (!_isProcessingQueue || _playbackQueue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }
    
    // Get the next prompt and play it
    final String nextPrompt = _playbackQueue.removeAt(0);
    _logDebug('Processing next in queue: $nextPrompt (${_playbackQueue.length} remaining)');
    await playPrompt(nextPrompt);
  }
  
  // Stop audio playback
  Future<void> stopAudio() async {
    if (_isPlaying) {
      _logDebug('Stopping all audio playback');
      
      // Stop all players
      for (final player in _playerPool) {
        await player.stop();
      }
      
      _isPlaying = false;
      _isProcessingQueue = false;
      _playbackQueue.clear();
      notifyListeners();
    }
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
    
    for (final player in _playerPool) {
      player.dispose();
    }
    
    super.dispose();
  }
}