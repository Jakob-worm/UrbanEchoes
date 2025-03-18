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
  
  // Cache for sound files with expiration
  final Map<String, List<String>> _soundFileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {}; // Track when cache was populated
  final Duration _cacheExpiration = Duration(hours: 1); // Expire cache after 1 hour
  
  // Spatial audio configuration
  final double _panningExponent = 0.5;
  
  // Buffering timeout
  final Map<String, Timer?> _bufferingTimers = {};
  final Duration _bufferingTimeout = Duration(seconds: 10);
  
  // Retry mechanism
  final Map<String, int> _retryCount = {};
  final int _maxRetries = 3;
  
  // Debug info
  int get activePlayerCount => _players.length;

  // Event callback for buffering timeout
  Function(String observationId)? onBufferingTimeout;

  // Start sound for an observation with retry logic
  Future<void> startSound(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    debugPrint('🔊 Starting sound for observation $observationId');
    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;
    _retryCount[observationId] = 0;

    await _cacheSoundFiles(folderPath);
    await _initializePlayer(observationId);
    await _applyPanningAndVolume(_players[observationId]!, pan, volume);
    await _playRandomSound(folderPath, observationId, pan, volume);
    
    _logActivePlayers();
  }

  void _logActivePlayers() {
    debugPrint('🎵 Active players: ${_players.length}, IDs: ${_players.keys.join(", ")}');
  }

  // Cache sound files with expiration check
  Future<void> _cacheSoundFiles(String folderPath) async {
    // Check if cache exists and is still valid
    if (_soundFileCache.containsKey(folderPath)) {
      DateTime? cacheTime = _cacheTimestamps[folderPath];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime) < _cacheExpiration) {
        debugPrint("📁 Using cached sound files for folder: $folderPath");
        return;
      }
    }

    try {
      debugPrint("📁 Fetching sound files for folder: $folderPath");
      List<String> files = await _storageService.listFiles(folderPath);
      if (files.isNotEmpty) {
        _soundFileCache[folderPath] = files;
        _cacheTimestamps[folderPath] = DateTime.now();
        debugPrint("📁 Cached ${files.length} files for $folderPath");
      } else {
        debugPrint('❌ No sound files found in folder: $folderPath');
      }
    } catch (e) {
      debugPrint('❌ Error caching sound files: $e');
      // Keep old cache if it exists
      if (!_soundFileCache.containsKey(folderPath)) {
        _soundFileCache[folderPath] = [];
      }
    }
  }

  // Initialize audio player with better error handling
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
    
    try {
      // Use low latency mode for better performance with ambient sounds
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      
      // Try to set mixing options if supported
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
    
    // Set up completion listener once during initialization
    player.onPlayerComplete.listen((_) {
      _handlePlaybackComplete(observationId);
    });
    
    debugPrint('🎵 Initialized player for $observationId');
  }

  // Handle playback completion
  void _handlePlaybackComplete(String observationId) {
    debugPrint('✅ Sound completed for $observationId');
    _cancelBufferingTimeout(observationId);
    
    if (_isActive[observationId] == true) {
      String? folderPath = _activeFolders[observationId];
      if (folderPath != null) {
        // Reset retry count on successful playback
        _retryCount[observationId] = 0;
        
        // Random delay between 3-8 seconds
        int delay = _random.nextInt(5000) + 3000;
        debugPrint('⏱️ Scheduling next sound for $observationId in $delay ms');
        
        Future.delayed(Duration(milliseconds: delay), () {
          if (_isActive[observationId] == true) {
            // Get the last known panning and volume values
            double pan = 0.0;
            double volume = 1.0;
            try {
              if (_players.containsKey(observationId)) {
                pan = _players[observationId]!.balance;
                volume = _players[observationId]!.volume;
              }
            } catch (e) {
              // Use defaults if unable to retrieve
            }
            
            _playRandomSound(folderPath, observationId, pan, volume);
          }
        });
      }
    }
  }

  // Play a random sound file with better retry logic
  Future<void> _playRandomSound(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] != true) return;

    try {
      List<String> files = _soundFileCache[folderPath] ?? [];
      if (files.isEmpty) {
        debugPrint('❌ No sound files available for $folderPath, trying to refresh cache');
        await _cacheSoundFiles(folderPath);
        files = _soundFileCache[folderPath] ?? [];
        
        if (files.isEmpty) {
          debugPrint('❌ Still no sound files after refresh, stopping sound for $observationId');
          _isActive[observationId] = false;
          return;
        }
      }
      
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
      
    } catch (e) {
      debugPrint('❌ Error in _playRandomSound: $e');
      _handlePlaybackError(folderPath, observationId, pan, volume);
    }
  }

  // Start buffering timeout
  void _startBufferingTimeout(String observationId) {
    _cancelBufferingTimeout(observationId);
    
    _bufferingTimers[observationId] = Timer(_bufferingTimeout, () {
      debugPrint('⏱️ Buffering timeout for $observationId');
      if (_isActive[observationId] == true) {
        // Notify listener about buffering timeout
        if (onBufferingTimeout != null) {
          onBufferingTimeout!(observationId);
        }
        
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

  // Handle playback errors with retry logic
  void _handlePlaybackError(String folderPath, String observationId, double pan, double volume) {
    if (_isActive[observationId] != true) return;
    
    _cancelBufferingTimeout(observationId);
    
    // Increment retry count
    int retries = (_retryCount[observationId] ?? 0) + 1;
    _retryCount[observationId] = retries;
    
    debugPrint('🔄 Handling playback error for $observationId (retry $retries/$_maxRetries)');
    
    // Clean up existing player
    if (_players.containsKey(observationId)) {
      try {
        _players[observationId]!.stop();
        _players[observationId]!.dispose();
        _players.remove(observationId);
      } catch (e) {
        debugPrint('❌ Error cleaning up player: $e');
      }
    }
    
    // If exceed max retries, give up
    if (retries > _maxRetries) {
      debugPrint('❌ Exceeded maximum retries for $observationId, stopping');
      _isActive[observationId] = false;
      return;
    }
    
    // Exponential backoff for retries (1s, 2s, 4s)
    int delayMs = 1000 * (1 << (retries - 1));
    
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_isActive[observationId] == true) {
        debugPrint('🔄 Retrying sound for $observationId after $delayMs ms');
        _initializePlayer(observationId).then((_) {
          _applyPanningAndVolume(_players[observationId]!, pan, volume).then((_) {
            _playRandomSound(folderPath, observationId, pan, volume);
          });
        });
      }
    });
  }

  // Apply panning and volume with error handling
  Future<void> _applyPanningAndVolume(AudioPlayer player, double pan, double volume) async {
    double adjustedPan = _applyPanningLaw(pan);
    
    try {
      await player.setBalance(adjustedPan);
      await player.setVolume(volume);
    } catch (e) {
      debugPrint('❌ Error applying panning/volume: $e');
    }
  }

  // Apply panning curve for more natural spatial audio
  double _applyPanningLaw(double rawPan) {
    if (rawPan < -1.0) rawPan = -1.0;
    if (rawPan > 1.0) rawPan = 1.0;
    return rawPan < 0 ? 
      -pow(-rawPan, _panningExponent).toDouble() : 
      pow(rawPan, _panningExponent).toDouble();
  }

  // Update panning and volume for active sound
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
    _retryCount.remove(observationId);
    
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

  // Play a one-shot sound (for UI feedback, etc.)
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
      
      // Check cache or fetch files
      if (!_soundFileCache.containsKey(folderPath) || 
          DateTime.now().difference(_cacheTimestamps[folderPath] ?? DateTime(2000)) > _cacheExpiration) {
        debugPrint("📁 Fetching sound files for one-shot");
        List<String> files = await _storageService.listFiles(folderPath);
        if (files.isNotEmpty) {
          _soundFileCache[folderPath] = files;
          _cacheTimestamps[folderPath] = DateTime.now();
        } else {
          debugPrint('❌ No sound files found');
          oneTimePlayer.dispose();
          return;
        }
      }

      List<String> files = _soundFileCache[folderPath] ?? [];
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
      Timer(Duration(minutes: 2), () {
        try {
          oneTimePlayer.stop().then((_) => oneTimePlayer.dispose());
        } catch (e) {
          // Player might already be disposed
        }
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
    _retryCount.clear();
    _cacheTimestamps.clear();
    onBufferingTimeout = null;
  }
}