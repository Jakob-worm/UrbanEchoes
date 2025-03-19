
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
  
  // Track volume and pan settings
  final Map<String, double> _volumeSettings = {};
  final Map<String, double> _panSettings = {};
  
  // Buffering timeout
  final Map<String, Timer?> _bufferingTimers = {};
  late Duration _bufferingTimeout = Duration(seconds: 10);
  
  // Retry mechanism
  final Map<String, int> _retryCount = {};
  final int _maxRetries = 3;
  
  // Debug info
  int get activePlayerCount => _players.length;

  // Event callback for buffering timeout
  Function? onBufferingTimeout;

  // Start sound for an observation
  Future<void> startSound(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    // Skip observations with null directory
    if (folderPath.isEmpty) {
      debugPrint('⚠️ Skipping observation with null sound directory: $observationId');
      return;
    }

    debugPrint('🔊 Starting sound for observation $observationId with volume=$volume, pan=$pan');
    
    // Store the volume/pan settings
    _volumeSettings[observationId] = volume;
    _panSettings[observationId] = pan;
    
    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;
    _retryCount[observationId] = 0;

    await _cacheSoundFiles(folderPath);
    await _initializePlayer(observationId);
    await _playRandomSound(folderPath, observationId, pan, volume);
  }

  // Cache sound files
  Future<void> _cacheSoundFiles(String folderPath) async {
    if (_soundFileCache.containsKey(folderPath)) {
      return;
    }

    try {
      debugPrint("📁 Fetching sound files for folder: $folderPath");
      List<String> files = await _storageService.listFiles(folderPath);
      if (files.isNotEmpty) {
        _soundFileCache[folderPath] = files;
      } else {
        _soundFileCache[folderPath] = [];
      }
    } catch (e) {
      debugPrint('❌ Error caching sound files: $e');
      _soundFileCache[folderPath] = [];
    }
  }

  // Initialize audio player
  Future<void> _initializePlayer(String observationId) async {
    try {
      // Clean up any existing player
      if (_players.containsKey(observationId)) {
        await _players[observationId]!.stop().catchError((e) {});
        await _players[observationId]!.dispose().catchError((e) {});
        _players.remove(observationId);
      }
      
      // Create new audio player
      debugPrint('Creating new AudioPlayer instance for $observationId');
      AudioPlayer player = AudioPlayer();
      _players[observationId] = player;
      
      // Set basic configuration
      await player.setPlayerMode(PlayerMode.lowLatency).catchError((e) {});
      await player.setReleaseMode(ReleaseMode.stop).catchError((e) {});
      
      // Set up completion listener
      player.onPlayerComplete.listen((event) {
        if (_isActive[observationId] == true) {
          _handlePlaybackComplete(observationId);
        }
      });
      
      // Apply volume and pan
      await _applyPanningAndVolume(
        player, 
        _panSettings[observationId] ?? 0.0, 
        _volumeSettings[observationId] ?? 0.5,
        observationId
      );
    } catch (e) {
      debugPrint('❌ Error initializing audio player: $e');
    }
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
        
        Future.delayed(Duration(milliseconds: delay), () {
          if (_isActive[observationId] == true) {
            double pan = _panSettings[observationId] ?? 0.0;
            double volume = _volumeSettings[observationId] ?? 0.5;
            _playRandomSound(folderPath, observationId, pan, volume);
          }
        });
      }
    }
  }

  Duration _getBufferingTimeout(String fileUrl) {
  if (fileUrl.toLowerCase().endsWith('.wav')) {
    return Duration(seconds: 20);  // Longer timeout for WAVs
  } else {
    return Duration(seconds: 10);  // Default for MP3s
  }
}

  // Modify BirdSoundPlayer to use a more efficient approach
Future<void> _playRandomSound(String folderPath, String observationId, double pan, double volume) async {
  if (_isActive[observationId] != true) return;

  try {
    // Prioritize MP3s over WAVs because they're smaller
    List<String> files = _soundFileCache[folderPath] ?? [];
    List<String> mp3Files = files.where((file) => file.toLowerCase().endsWith('.mp3')).toList();
    
    // Use only MP3 files if available, otherwise use all files
    List<String> filesToUse = mp3Files.isNotEmpty ? mp3Files : files;
    
    if (filesToUse.isEmpty) {
      debugPrint('❌ No suitable sound files available for $folderPath');
      _isActive[observationId] = false;
      return;
    }
    
    // Get the player
    if (!_players.containsKey(observationId)) {
      await _initializePlayer(observationId);
    }
    
    AudioPlayer player = _players[observationId]!;
    
    // Select random file
    String randomFile = filesToUse[_random.nextInt(filesToUse.length)];
    
    // Increase buffering timeout for larger files (WAVs)
    if (randomFile.toLowerCase().endsWith('.wav')) {
      _bufferingTimeout = Duration(seconds: 20);  // Longer timeout for WAVs
    } else {
      _bufferingTimeout = Duration(seconds: 10);  // Default for MP3s
    }
    
    // Start buffering timeout
    _startBufferingTimeout(observationId);
    
    debugPrint('🎵 Playing sound for $observationId: $randomFile');
    
    // Set volume and pan
    await _applyPanningAndVolume(player, pan, volume, observationId);
    
    // Configure the player for better mobile streaming
    await player.setPlayerMode(PlayerMode.lowLatency);
    
    // Use a smaller buffer size for faster initial playback
    int bufferSize = randomFile.toLowerCase().endsWith('.wav') ? 4096 * 4 : 4096;
    
    // Play the sound with source configuration
    await player.play(
      UrlSource(
        randomFile,
      ),
    ).catchError((e) {
      debugPrint('❌ Error playing sound: $e');
      _handlePlaybackError(folderPath, observationId, pan, volume);
    });
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
        // Notify about buffering timeout
        if (onBufferingTimeout != null) {
          onBufferingTimeout!(observationId);
        }
        
        String? folderPath = _activeFolders[observationId];
        if (folderPath != null) {
          double pan = _panSettings[observationId] ?? 0.0;
          double volume = _volumeSettings[observationId] ?? 0.5;
          _handlePlaybackError(folderPath, observationId, pan, volume);
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
    
    _cancelBufferingTimeout(observationId);
    
    // Increment retry count
    int retries = (_retryCount[observationId] ?? 0) + 1;
    _retryCount[observationId] = retries;
    
    debugPrint('🔄 Handling playback error for $observationId (retry $retries/$_maxRetries)');
    
    // Clean up existing player
    if (_players.containsKey(observationId)) {
      try {
        _players[observationId]!.stop().catchError((e) {});
        _players[observationId]!.dispose().catchError((e) {});
      } catch (e) {}
      
      _players.remove(observationId);
    }
    
    // If exceed max retries, give up
    if (retries > _maxRetries) {
      debugPrint('❌ Exceeded maximum retries for $observationId');
      _isActive[observationId] = false;
      return;
    }
    
    // Retry with exponential backoff (1s, 2s, 4s)
    int delayMs = 1000 * (1 << (retries - 1));
    
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_isActive[observationId] == true) {
        debugPrint('🔄 Retrying sound for $observationId after $delayMs ms');
        _initializePlayer(observationId).then((_) {
          _playRandomSound(folderPath, observationId, pan, volume);
        });
      }
    });
  }

  // Apply panning and volume
  Future<void> _applyPanningAndVolume(AudioPlayer player, double pan, double volume, String observationId) async {
    try {
      // Try to set balance and volume
      await player.setBalance(pan).catchError((e) {});
      await player.setVolume(volume).catchError((e) {});
    } catch (e) {
      debugPrint('❌ Error applying panning/volume: $e');
    }
  }

  // Update panning and volume for active sound
  Future<void> updatePanningAndVolume(String observationId, double pan, double volume) async {
    // Store the requested values
    _panSettings[observationId] = pan;
    _volumeSettings[observationId] = volume;
    
    if (!_players.containsKey(observationId)) {
      debugPrint('! Cannot update panning: player not found for $observationId');
      return;
    }
    
    try {
      await _applyPanningAndVolume(_players[observationId]!, pan, volume, observationId);
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
        await _players[observationId]!.stop().catchError((e) {});
        await _players[observationId]!.dispose().catchError((e) {});
      } catch (e) {}
      
      _players.remove(observationId);
      debugPrint('🎵 Removed player for $observationId, remaining: ${_players.length}');
    }
  }

  // Clean up all resources
  void dispose() {
    debugPrint('🧹 Disposing all sound players');
    
    for (var timer in _bufferingTimers.values) {
      timer?.cancel();
    }
    
    for (var id in List<String>.from(_players.keys)) {
      try {
        _players[id]!.stop().catchError((e) {});
        _players[id]!.dispose().catchError((e) {});
      } catch (e) {}
    }

    _players.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
    _bufferingTimers.clear();
    _retryCount.clear();
    _volumeSettings.clear();
    _panSettings.clear();
    onBufferingTimeout = null;
  }
}