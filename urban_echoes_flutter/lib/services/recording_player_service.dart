import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class RecrodingPlayerService extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isMuted = false;
  final bool _debugMode;
  
  // Constructor
  RecrodingPlayerService({bool debugMode = false}) : _debugMode = debugMode {
    _initAudio();
  }
  
  // Initialize audio player
  Future<void> _initAudio() async {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      notifyListeners();
    });
  }
  
  // Getters
  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  
  // Play audio prompt from assets
  Future<void> playPrompt(String promptKey) async {
    if (_isMuted) return;
    
    if (_isPlaying) {
      await stopAudio();
    }
    
    try {
      _logDebug('Playing audio prompt: $promptKey');
      
      final path = _getAudioPath(promptKey);
      await _audioPlayer.play(AssetSource(path));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _logDebug('Error playing audio: $e');
    }
  }
  
  // Stop audio playback
  Future<void> stopAudio() async {
    if (_isPlaying) {
      _logDebug('Stopping audio playback');
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
    }
  }
  
  // Toggle mute state
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted && _isPlaying) {
      stopAudio();
    }
    notifyListeners();
  }
  
  // Map prompt keys to audio file paths
  String _getAudioPath(String promptKey) {
    final Map<String, String> audioMap = {
      'start_listening': 'audio/recorded/start_listening.mp3',
      // Add more audio prompts as needed
    };
    
    // Return the path or a default if not found
    return audioMap[promptKey] ?? 'audio/default.mp3';
  }
  
  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('AudioService: $message');
    }
  }
  
  // Clean up resources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}