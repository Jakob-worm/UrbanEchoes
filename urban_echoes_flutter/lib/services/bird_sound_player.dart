import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  // Core player management
  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _isActive = {};
  final Map<String, String> _activeFolders = {};
  final AzureStorageService _storageService = AzureStorageService();
  final Random _random = Random();
  
  // Cache for sound files
  final Map<String, List<String>> _soundFileCache = {};
  
  // Spatial audio configuration
  final double _panningExponent = 0.5;
  
  // Buffering timeout
  final Map<String, Timer?> _bufferingTimers = {};
  final Duration _bufferingTimeout = Duration(seconds: 10);
  
  // Debug info
  int get activePlayerCount => _players.length;

  // Start sound for an observation
  Future<void> startSound(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    debugPrint('🔊 Starting sound for observation $observationId');
    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;

    await _cacheSoundFiles(folderPath);
    await _initializePlayer(observationId);
    await _applyPanningAndVolume(_players[observationId]!, pan, volume);
    await _playRandomSound(folderPath, observationId, pan, volume);
    
    // Log active players for debugging
    _logActivePlayers();
  }

  void _logActivePlayers() {
    debugPrint('🎵 Active players: ${_players.length}, IDs: ${_players.keys.join(", ")}');
  }

  // Cache sound files for a directory
  Future<void> _cacheSoundFiles(String folderPath) async {
    if (_soundFileCache.containsKey(folderPath)) return;

    try {
      debugPrint("📁 Caching sound files for folder: $folderPath");
      List<String> files = await _storageService.listFiles(folderPath);
      if (files.isNotEmpty) {
        _soundFileCache[folderPath] = files;
        debugPrint("📁 Cached ${files.length} files for $folderPath");
      } else {
        debugPrint('❌ No sound files found in folder: $folderPath');
      }
    } catch (e) {
      debugPrint('❌ Error caching sound files: $e');
    }
  }

  // Initialize audio player
  Future<void> _initializePlayer(String observationId) async {
    if (_players.containsKey(observationId)) {
      try {
        await _players[observationId]!.stop();
        await _players[observationId]!.dispose();
      } catch (e) {
        debugPrint('❌ Error cleaning up existing player: $e');
      }
    }
    
    // Create new audio player with specific settings
    AudioPlayer player = AudioPlayer();
    
    // CRITICAL FIX: Disable audio focus handling to allow multiple sounds
    try {
      // Use low latency mode which is more suitable for short ambient sounds
      // and often doesn't cause audio focus stealing on Android
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      
      // On some versions, we can also set audio attributes directly
      try {
        // Attempt to set mix mode through alternate API if available
        // ignore: unnecessary_cast
        final playerInstance = player as dynamic;
        if (playerInstance.setMixWithOthers != null) {
          await playerInstance.setMixWithOthers(true);
        }
      } catch (e) {
        // Ignore if method not available
      }
    } catch (e) {
      debugPrint('⚠️ Error setting audio options: $e');
    }
    
    _players[observationId] = player;
    debugPrint('🎵 Initialized player for $observationId, total players: ${_players.length}');
  }

  // Play a random sound file
  Future<void> _playRandomSound(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] != true) return;

    try {
      List<String> files = _soundFileCache[folderPath] ?? [];
      if (files.isEmpty) return;

      if (!_players.containsKey(observationId)) {
        await _initializePlayer(observationId);
        await _applyPanningAndVolume(_players[observationId]!, pan, volume);
      }
      
      AudioPlayer player = _players[observationId]!;
      
      // Select random file
      String randomFile = files[_random.nextInt(files.length)];
      
      // Start buffering timeout
      _startBufferingTimeout(observationId);
      
      debugPrint('🎵 Playing sound for $observationId: $randomFile');
      
      try {
        await player.play(UrlSource(randomFile));
      } catch (e) {
        debugPrint('❌ Error playing sound: $e');
        _handlePlaybackError(folderPath, observationId, pan, volume);
        return;
      }

      // Handle completion
      player.onPlayerComplete.listen((_) {
        debugPrint('✅ Sound completed for $observationId');
        _cancelBufferingTimeout(observationId);
        
        if (_isActive[observationId] == true) {
          // Random delay between 3-8 seconds
          int delay = _random.nextInt(5000) + 3000;
          debugPrint('⏱️ Scheduling next sound for $observationId in $delay ms');
          
          Future.delayed(Duration(milliseconds: delay), () {
            if (_isActive[observationId] == true) {
              _playRandomSound(folderPath, observationId, pan, volume);
            }
          });
        }
      });
      
    } catch (e) {
      debugPrint('❌ Error in _playRandomSound: $e');
      Future.delayed(Duration(seconds: 2), () {
        if (_isActive[observationId] == true) {
          _playRandomSound(folderPath, observationId, pan, volume);
        }
      });
    }
  }

  // Start buffering timeout
  void _startBufferingTimeout(String observationId) {
    _cancelBufferingTimeout(observationId);
    
    _bufferingTimers[observationId] = Timer(_bufferingTimeout, () {
      debugPrint('⏱️ Buffering timeout for $observationId');
      if (_isActive[observationId] == true) {
        String? folderPath = _activeFolders[observationId];
        if (folderPath != null) {
          _handlePlaybackError(folderPath, observationId, 0.0, 1.0);
        }
      }
    });
  }

  // Cancel buffering timeout
  void _cancelBufferingTimeout(String observationId) {
    _bufferingTimers[observationId]?.cancel();
    _bufferingTimers[observationId] = null;
  }

  // Handle playback errors
  void _handlePlaybackError(String folderPath, String observationId, double pan, double volume) {
    if (_isActive[observationId] != true) return;
    
    debugPrint('🔄 Handling playback error for $observationId');
    _cancelBufferingTimeout(observationId);
    
    if (_players.containsKey(observationId)) {
      try {
        _players[observationId]!.stop();
        _players[observationId]!.dispose();
        _players.remove(observationId);
      } catch (e) {
        debugPrint('❌ Error cleaning up player: $e');
      }
    }
    
    Future.delayed(Duration(seconds: 2), () {
      if (_isActive[observationId] == true) {
        debugPrint('🔄 Retrying sound for $observationId');
        _initializePlayer(observationId).then((_) {
          _applyPanningAndVolume(_players[observationId]!, pan, volume).then((_) {
            _playRandomSound(folderPath, observationId, pan, volume);
          });
        });
      }
    });
  }

  // Apply panning and volume
  Future<void> _applyPanningAndVolume(AudioPlayer player, double pan, double volume) async {
    double adjustedPan = _applyPanningLaw(pan);
    
    try {
      await player.setBalance(adjustedPan);
      await player.setVolume(volume);
    } catch (e) {
      debugPrint('❌ Error applying panning/volume: $e');
    }
  }

  // Apply panning curve
  double _applyPanningLaw(double rawPan) {
    if (rawPan < -1.0) rawPan = -1.0;
    if (rawPan > 1.0) rawPan = 1.0;
    return rawPan < 0 ? 
      -pow(-rawPan, _panningExponent).toDouble() : 
      pow(rawPan, _panningExponent).toDouble();
  }

  // Update panning and volume
  Future<void> updatePanningAndVolume(String observationId, double pan, double volume) async {
    if (!_players.containsKey(observationId)) {
      debugPrint('⚠️ Cannot update panning: player not found for $observationId');
      return;
    }
    
    try {
      await _applyPanningAndVolume(_players[observationId]!, pan, volume);
    } catch (e) {
      debugPrint('❌ Error updating panning/volume: $e');
    }
  }

  // Stop sounds for an observation
  Future<void> stopSounds(String observationId) async {
    debugPrint('🛑 Stopping sounds for $observationId');
    _isActive[observationId] = false;
    _cancelBufferingTimeout(observationId);
    
    if (_players.containsKey(observationId)) {
      try {
        await _players[observationId]!.stop();
        await _players[observationId]!.dispose();
        _players.remove(observationId);
        
        debugPrint('🎵 Removed player for $observationId, remaining: ${_players.length}');
      } catch (e) {
        debugPrint('❌ Error stopping sound: $e');
      }
    }
  }

  // Play a one-shot sound
  Future<void> playRandomSoundFromFolder(String folderPath, double volume) async {
    AudioPlayer oneTimePlayer = AudioPlayer();

    try {
      await oneTimePlayer.setPlayerMode(PlayerMode.lowLatency);
      
      // Try to set mixing options if available
      try {
        // Attempt to set mix mode through alternate API if available
        // ignore: unnecessary_cast
        final playerInstance = oneTimePlayer as dynamic;
        if (playerInstance.setMixWithOthers != null) {
          await playerInstance.setMixWithOthers(true);
        }
      } catch (e) {
        // Ignore if method not available
      }
      
      if (!_soundFileCache.containsKey(folderPath)) {
        debugPrint("📁 Fetching sound files for one-shot");
        List<String> files = await _storageService.listFiles(folderPath);
        if (files.isNotEmpty) {
          _soundFileCache[folderPath] = files;
        } else {
          debugPrint('❌ No sound files found');
          oneTimePlayer.dispose();
          return;
        }
      }

      List<String> files = _soundFileCache[folderPath]!;
      if (files.isEmpty) {
        debugPrint('❌ No cached sound files');
        oneTimePlayer.dispose();
        return;
      }
      
      String randomFile = files[_random.nextInt(files.length)];

      oneTimePlayer.onPlayerComplete.listen((_) {
        oneTimePlayer.dispose();
      });
      
      debugPrint('🎵 Playing one-shot sound: $randomFile');
      await oneTimePlayer.setVolume(volume);
      await oneTimePlayer.play(UrlSource(randomFile));
      
      // Safety cleanup
      Timer(Duration(minutes: 5), () {
        oneTimePlayer.stop().then((_) => oneTimePlayer.dispose());
      });
      
    } catch (e) {
      debugPrint('❌ Failed to play one-shot sound: $e');
      oneTimePlayer.dispose();
    }
  }

  // Clean up all resources
  void dispose() {
    debugPrint('🧹 Disposing all sound players');
    
    for (var timer in _bufferingTimers.values) {
      timer?.cancel();
    }
    
    for (var observationId in _players.keys) {
      try {
        _players[observationId]!.stop();
        _players[observationId]!.dispose();
      } catch (e) {
        debugPrint('❌ Error disposing player: $e');
      }
    }

    _players.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
    _bufferingTimers.clear();
  }
}