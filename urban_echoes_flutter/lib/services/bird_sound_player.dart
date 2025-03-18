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
  
  // Track player initialization state
  final Map<String, bool> _isPlayerInitialized = {};
  
  // Cache for sound files with expiration
  final Map<String, List<String>> _soundFileCache = {};
  final Map<String, DateTime> _cacheTimestamps = {}; // Track when cache was populated
  final Duration _cacheExpiration = Duration(hours: 1); // Expire cache after 1 hour
  
  // Track volume settings
  final Map<String, double> _volumeSettings = {};
  final Map<String, double> _panSettings = {};
  
  // Spatial audio configuration
  final double _panningExponent = 0.5;
  
  // Buffering timeout
  final Map<String, Timer?> _bufferingTimers = {};
  final Duration _bufferingTimeout = Duration(seconds: 10);
  
  // Retry mechanism
  final Map<String, int> _retryCount = {};
  final int _maxRetries = 3;

  // Track player usage
  final Map<String, bool> _playerInUse = {};
  
  // Mutex to prevent concurrent access
  final Map<String, bool> _playerLock = {};
  
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

    debugPrint('🔊 Starting sound for observation $observationId with volume=$volume, pan=$pan');
    
    // Store the volume/pan settings even before player is initialized
    _volumeSettings[observationId] = volume;
    _panSettings[observationId] = pan;
    
    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;
    _retryCount[observationId] = 0;

    await _cacheSoundFiles(folderPath);
    await _initializePlayer(observationId);
    
    if (_players.containsKey(observationId) && _isPlayerInitialized[observationId] == true) {
      await _applyPanningAndVolume(_players[observationId]!, pan, volume, observationId);
      await _playRandomSound(folderPath, observationId, pan, volume);
    } else {
      debugPrint('❌ Failed to initialize player for $observationId');
    }
    
    _logActivePlayers();
  }

  void _logActivePlayers() {
    debugPrint('🎵 Active players: ${_players.length}, IDs: ${_players.keys.join(", ")}');
    for (var id in _players.keys) {
      debugPrint('  - Player $id: volume=${_volumeSettings[id] ?? "unknown"}, pan=${_panSettings[id] ?? "unknown"}');
    }
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
    // Acquire lock
    if (_playerLock[observationId] == true) {
      debugPrint('⚠️ Player initialization already in progress for $observationId');
      return;
    }
    
    _playerLock[observationId] = true;
    
    try {
      // Clean up any existing player
      if (_players.containsKey(observationId)) {
        try {
          _isPlayerInitialized[observationId] = false;
          _playerInUse[observationId] = false;
          
          // Try to stop
          if (_players[observationId]!.state != PlayerState.disposed) {
            await _players[observationId]!.stop().catchError((e) {
              debugPrint('❌ Error stopping player (cleanup): $e');
            });
          }
          
          // Try to dispose
          if (_players[observationId]!.state != PlayerState.disposed) {
            await _players[observationId]!.dispose().catchError((e) {
              debugPrint('❌ Error disposing player (cleanup): $e');
            });
          }
          
          _players.remove(observationId);
        } catch (e) {
          debugPrint('❌ Error cleaning up existing player: $e');
        }
      }
      
      // Create new audio player with specific settings
      debugPrint('Creating new AudioPlayer instance for $observationId');
      AudioPlayer player = AudioPlayer();
      _players[observationId] = player;
      _playerInUse[observationId] = true;
      
      try {
        // Use low latency mode for better performance with ambient sounds
        await player.setPlayerMode(PlayerMode.lowLatency).catchError((e) {
          debugPrint('❌ Error setting player mode: $e');
        });
        
        await player.setReleaseMode(ReleaseMode.stop).catchError((e) {
          debugPrint('❌ Error setting release mode: $e');
        });
        
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
      
      // Set up completion listener once during initialization
      player.onPlayerComplete.listen((event) {
        if (_isActive[observationId] == true) {
          _handlePlaybackComplete(observationId);
        }
      });
      
      // Mark as initialized
      _isPlayerInitialized[observationId] = true;
      
      // Apply volume settings if they were already set
      if (_volumeSettings.containsKey(observationId) && _panSettings.containsKey(observationId)) {
        await _applyPanningAndVolume(
          player, 
          _panSettings[observationId]!, 
          _volumeSettings[observationId]!,
          observationId
        );
      }
      
      debugPrint('🎵 Initialized player for $observationId');
    } catch (e) {
      debugPrint('❌ Error initializing audio player: $e');
    } finally {
      // Release lock
      _playerLock[observationId] = false;
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
        debugPrint('⏱️ Scheduling next sound for $observationId in $delay ms');
        
        Future.delayed(Duration(milliseconds: delay), () {
          if (_isActive[observationId] == true) {
            // Get the stored volume/pan values
            double pan = _panSettings[observationId] ?? 0.0;
            double volume = _volumeSettings[observationId] ?? 1.0;
            
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
      
      // Ensure player is initialized
      if (!_players.containsKey(observationId) || 
          _isPlayerInitialized[observationId] != true || 
          _playerInUse[observationId] != true) {
        await _initializePlayer(observationId);
        if (!_players.containsKey(observationId) || 
            _isPlayerInitialized[observationId] != true || 
            _playerInUse[observationId] != true) {
          debugPrint('❌ Failed to initialize player for $observationId');
          return;
        }
        await _applyPanningAndVolume(_players[observationId]!, pan, volume, observationId);
      }
      
      AudioPlayer player = _players[observationId]!;
      
      // Select random file
      String randomFile;
      try {
        randomFile = files[_random.nextInt(files.length)];
      } catch (e) {
        debugPrint('❌ Error selecting random file: $e');
        _handlePlaybackError(folderPath, observationId, pan, volume);
        return;
      }
      
      // Start buffering timeout
      _startBufferingTimeout(observationId);
      
      debugPrint('🎵 Playing sound for $observationId: $randomFile');
      
      try {
        // Force set volume again right before playing
        await _applyPanningAndVolume(player, pan, volume, observationId);
        
        // Safe play with error handling
        await player.play(UrlSource(randomFile)).catchError((e) {
          debugPrint('❌ Error playing sound: $e');
          _handlePlaybackError(folderPath, observationId, pan, volume);
        });
        
        // Check volume setting after playing
        try {
          double actualVolume = player.volume;
          double actualBalance = player.balance;
          debugPrint('Volume check for $observationId - Target: $volume, Actual: $actualVolume, Pan - Target: $pan, Actual: $actualBalance');
        } catch (e) {
          debugPrint('❌ Error checking volume: $e');
        }
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
          double pan = _panSettings[observationId] ?? 0.0;
          double volume = _volumeSettings[observationId] ?? 1.0;
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

  // Handle playback errors with retry logic
  void _handlePlaybackError(String folderPath, String observationId, double pan, double volume) {
    if (_isActive[observationId] != true) return;
    
    _cancelBufferingTimeout(observationId);
    
    // Increment retry count
    int retries = (_retryCount[observationId] ?? 0) + 1;
    _retryCount[observationId] = retries;
    
    debugPrint('🔄 Handling playback error for $observationId (retry $retries/$_maxRetries)');
    
    // Clean up existing player safely
    if (_players.containsKey(observationId)) {
      try {
        if (_players[observationId]!.state != PlayerState.disposed) {
          _players[observationId]!.stop().catchError((e) {
            debugPrint('❌ Error stopping player (error handler): $e');
          });
        }
      } catch (e) {
        debugPrint('❌ Error stopping player: $e');
      }
      
      try {
        if (_players[observationId]!.state != PlayerState.disposed) {
          _players[observationId]!.dispose().catchError((e) {
            debugPrint('❌ Error disposing player (error handler): $e');
          });
        }
      } catch (e) {
        debugPrint('❌ Error disposing player: $e');
      }
      
      _players.remove(observationId);
      _isPlayerInitialized[observationId] = false;
      _playerInUse[observationId] = false;
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
          if (_players.containsKey(observationId) && 
              _isPlayerInitialized[observationId] == true && 
              _playerInUse[observationId] == true) {
            _applyPanningAndVolume(
              _players[observationId]!, 
              pan, 
              volume,
              observationId
            ).then((_) {
              _playRandomSound(folderPath, observationId, pan, volume);
            });
          }
        });
      }
    });
  }

  // Apply panning and volume with error handling and better verification
  Future<void> _applyPanningAndVolume(AudioPlayer player, double pan, double volume, String observationId) async {
    double adjustedPan = _applyPanningLaw(pan);
    
    // Store the requested values
    _panSettings[observationId] = pan;
    _volumeSettings[observationId] = volume;
    
    debugPrint('Setting volume=$volume, pan=$pan for $observationId');
    
    try {
      // Try to set balance
      await player.setBalance(adjustedPan).catchError((e) {
        debugPrint('❌ Error setting balance: $e');
      });
      
      // Try to set volume
      await player.setVolume(volume).catchError((e) {
        debugPrint('❌ Error setting volume: $e');
      });
      
      // Verify the settings took effect
      try {
        double actualVolume = player.volume;
        double actualBalance = player.balance;
        
        debugPrint('Volume verification for $observationId - requested: $volume, actual: $actualVolume');
        debugPrint('Balance verification for $observationId - requested: $adjustedPan, actual: $actualBalance');
        
        // If values are significantly different, try one more time
        if ((actualVolume - volume).abs() > 0.01 || (actualBalance - adjustedPan).abs() > 0.01) {
          debugPrint('⚠️ Volume/balance mismatch detected, trying again');
          
          // Try to set balance again
          await player.setBalance(adjustedPan).catchError((e) {
            debugPrint('❌ Error setting balance (retry): $e');
          });
          
          // Try to set volume again
          await player.setVolume(volume).catchError((e) {
            debugPrint('❌ Error setting volume (retry): $e');
          });
        }
      } catch (e) {
        debugPrint('❌ Error verifying volume/balance: $e');
      }
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
    // Store the requested values regardless of player status
    _panSettings[observationId] = pan;
    _volumeSettings[observationId] = volume;
    
    if (!_players.containsKey(observationId) || 
        _isPlayerInitialized[observationId] != true || 
        _playerInUse[observationId] != true) {
      debugPrint('⚠️ Cannot update panning: player not found for $observationId');
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
    _retryCount.remove(observationId);
    
    if (_players.containsKey(observationId)) {
      try {
        // Only attempt to stop if the player is not disposed
        if (_players[observationId]!.state != PlayerState.disposed) {
          await _players[observationId]!.stop().catchError((e) {
            debugPrint('❌ Error stopping sound: $e');
          });
        }
      } catch (e) {
        debugPrint('❌ Error stopping sound: $e');
      }
      
      try {
        // Only attempt to dispose if the player is not already disposed
        if (_players[observationId]!.state != PlayerState.disposed) {
          await _players[observationId]!.dispose().catchError((e) {
            debugPrint('❌ Error disposing player: $e');
          });
        }
      } catch (e) {
        debugPrint('❌ Error disposing player: $e');
      }
      
      _players.remove(observationId);
      _isPlayerInitialized[observationId] = false;
      _playerInUse[observationId] = false;
      
      debugPrint('🎵 Removed player for $observationId, remaining: ${_players.length}');
    }
  }

  // Play a one-shot sound (for UI feedback, etc.)
  Future<void> playRandomSoundFromFolder(String folderPath, double volume) async {
    AudioPlayer oneTimePlayer = AudioPlayer();
    bool playerInitialized = false;

    try {
      await oneTimePlayer.setPlayerMode(PlayerMode.lowLatency);
      playerInitialized = true;
      
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
          if (playerInitialized && oneTimePlayer.state != PlayerState.disposed) {
            await oneTimePlayer.dispose().catchError((e) {
              // Ignore cleanup errors
            });
          }
          return;
        }
      }

      List<String> files = _soundFileCache[folderPath] ?? [];
      if (files.isEmpty) {
        debugPrint('❌ No cached sound files');
        if (playerInitialized && oneTimePlayer.state != PlayerState.disposed) {
          await oneTimePlayer.dispose().catchError((e) {
            // Ignore cleanup errors
          });
        }
        return;
      }
      
      String randomFile = files[_random.nextInt(files.length)];

      // Setup completion listener
      oneTimePlayer.onPlayerComplete.listen((_) {
        if (playerInitialized && oneTimePlayer.state != PlayerState.disposed) {
          oneTimePlayer.dispose().catchError((e) {
            // Ignore cleanup errors
          });
        }
      });
      
      debugPrint('🎵 Playing one-shot sound: $randomFile with volume=$volume');
      
      // Apply volume explicitly
      await oneTimePlayer.setVolume(volume).catchError((e) {
        debugPrint('❌ Error setting volume for one-shot sound: $e');
      });
      
      // Verify volume set correctly
      try {
        debugPrint('One-shot sound volume verification - requested: $volume, actual: ${oneTimePlayer.volume}');
      } catch (e) {
        debugPrint('❌ Error verifying volume: $e');
      }
      
      await oneTimePlayer.play(UrlSource(randomFile));
      
      // Safety cleanup
      Timer(Duration(minutes: 2), () {
        try {
          if (playerInitialized && oneTimePlayer.state != PlayerState.disposed) {
            oneTimePlayer.stop().then((_) {
              oneTimePlayer.dispose().catchError((e) {
                // Ignore cleanup errors
              });
            }).catchError((e) {
              // Ignore cleanup errors
            });
          }
        } catch (e) {
          // Player might already be disposed
        }
      });
      
    } catch (e) {
      debugPrint('❌ Failed to play one-shot sound: $e');
      if (playerInitialized && oneTimePlayer.state != PlayerState.disposed) {
        oneTimePlayer.dispose().catchError((e) {
          // Ignore cleanup errors
        });
      }
    }
  }

  // Clean up all resources
  void dispose() {
    debugPrint('🧹 Disposing all sound players');
    
    for (var timer in _bufferingTimers.values) {
      timer?.cancel();
    }
    
    // Make a copy of keys to avoid concurrent modification
    final playerKeys = List<String>.from(_players.keys);
    
    for (var observationId in playerKeys) {
      try {
        // Only attempt to stop and dispose if player isn't already disposed
        if (_players[observationId]!.state != PlayerState.disposed) {
          _players[observationId]!.stop().then((_) {
            if (_players[observationId]!.state != PlayerState.disposed) {
              _players[observationId]!.dispose().catchError((e) {
                // Ignore cleanup errors
              });
            }
          }).catchError((e) {
            // Ignore cleanup errors
            if (_players[observationId]!.state != PlayerState.disposed) {
              _players[observationId]!.dispose().catchError((e) {
                // Ignore cleanup errors
              });
            }
          });
        }
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
    _isPlayerInitialized.clear();
    _playerInUse.clear();
    _playerLock.clear();
    _volumeSettings.clear();
    _panSettings.clear();
    onBufferingTimeout = null;
  }
}