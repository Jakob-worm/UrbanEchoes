import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  // Main player map - now we'll have multiple players per observation
  final Map<String, List<AudioPlayer>> _playerPools = {};
  final Map<String, bool> _isActive = {};
  final Map<String, String> _activeFolders = {}; // Track the folder for each observation
  final AzureStorageService _storageService = AzureStorageService();
  final Random _random = Random();

  // Cache sound files by folder to avoid repeated API calls
  final Map<String, List<String>> _soundFileCache = {};

  // Parameters for panning calculation
  final double _panningExponent = 0.5; // Square root for constant power pan law
  
  // Number of players to create per observation (for overlapping sounds)
  final int _playersPerObservation = 3;
  
  // Pool index tracking
  final Map<String, int> _currentPlayerIndex = {};
  
  // Track active players for each observation
  final Map<String, Set<AudioPlayer>> _activePlayers = {};

  // Public method that LocationService will call
  Future<void> startSound(
      String folderPath, String observationId, double pan, double volume) async {
    return startSequentialRandomSoundsWithPanning(
        folderPath, observationId, pan, volume);
  }

  // Start playing random sounds in sequence for an observation with panning
  Future<void> startSequentialRandomSoundsWithPanning(
      String folderPath, String observationId, double pan, double volume) async {
    // If already active, just update panning and volume
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    debugPrint('Starting new sound player pool for observation $observationId');

    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;
    _activePlayers[observationId] = {};

    // Pre-cache sound files if not already cached
    if (!_soundFileCache.containsKey(folderPath)) {
      try {
        debugPrint("Caching sound files for folder: $folderPath");
        List<String> files = await _storageService.listFiles(folderPath);
        if (files.isNotEmpty) {
          _soundFileCache[folderPath] = files;
        } else {
          debugPrint('No sound files found in folder: $folderPath');
          _isActive[observationId] = false;
          return;
        }
      } catch (e) {
        debugPrint('Error caching sound files: $e');
        _isActive[observationId] = false;
        return;
      }
    }

    // Create a pool of players for this observation if it doesn't exist
    if (!_playerPools.containsKey(observationId)) {
      _playerPools[observationId] = [];
      _currentPlayerIndex[observationId] = 0;
    }

    // Ensure we have enough players initialized
    while (_playerPools[observationId]!.length < _playersPerObservation) {
      AudioPlayer player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await _applyPanningAndVolume(player, pan, volume);
      _playerPools[observationId]!.add(player);
    }

    // Start playing immediately
    _startInitialSounds(folderPath, observationId, pan, volume);
  }

  // Start initial sounds for this observation
  void _startInitialSounds(String folderPath, String observationId, double pan, double volume) {
    // Start with initial sound
    _playRandomSound(folderPath, observationId, pan, volume);
    
    // Add more sounds with slight delays to create a more natural soundscape
    Future.delayed(Duration(milliseconds: _random.nextInt(2000) + 1000), () {
      if (_isActive[observationId] == true) {
        _playRandomSound(folderPath, observationId, pan, volume);
      }
    });
  }

  // Play a random sound for a specific observation
  Future<void> _playRandomSound(String folderPath, String observationId, double pan, double volume) async {
    if (!_isActive[observationId]!) return;
    
    try {
      // Get sound files
      List<String> files = _soundFileCache[folderPath] ?? [];
      if (files.isEmpty) return;
      
      // Pick a random file
      String randomFile = files[_random.nextInt(files.length)];
      
      // Create a new player for this sound
      AudioPlayer player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await _applyPanningAndVolume(player, pan, volume);
      
      // Track this player
      _activePlayers[observationId]?.add(player);
      
      // Play the sound
      await player.play(UrlSource(randomFile));
      debugPrint('Playing sound for observation $observationId: $randomFile');
      
      // Schedule next sound after this one completes
      player.onPlayerComplete.listen((_) {
        // Remove this player from active players
        _activePlayers[observationId]?.remove(player);
        player.dispose();
        
        if (_isActive[observationId] == true) {
          // Schedule next sound with a random delay
          Future.delayed(Duration(milliseconds: _random.nextInt(3000) + 1000), () {
            if (_isActive[observationId] == true) {
              _playRandomSound(folderPath, observationId, pan, volume);
            }
          });
        }
      });
      
      // Schedule another sound to overlap if we have fewer than desired concurrent sounds
      if (_activePlayers[observationId]!.length < _playersPerObservation) {
        Future.delayed(Duration(milliseconds: _random.nextInt(4000) + 2000), () {
          if (_isActive[observationId]! && _activePlayers[observationId]!.length < _playersPerObservation) {
            _playRandomSound(folderPath, observationId, pan, volume);
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing sound for observation $observationId: $e');
      // Try again after a delay
      Future.delayed(Duration(seconds: 2), () {
        if (_isActive[observationId] == true) {
          _playRandomSound(folderPath, observationId, pan, volume);
        }
      });
    }
  }

  // For backward compatibility
  Future<void> startSequentialRandomSounds(
      String folderPath, String observationId) async {
    // Default to center panning (0.0) and full volume (1.0)
    await startSequentialRandomSoundsWithPanning(
        folderPath, observationId, 0.0, 1.0);
  }

  // Apply panning and volume to an audio player
  Future<void> _applyPanningAndVolume(
      AudioPlayer player, double pan, double volume) async {
    // Apply constant power panning law
    double adjustedPan = _applyPanningLaw(pan);

    // Convert pan value (-1.0 to 1.0) to balance value for audioplayers
    // audioplayers uses -1.0 (left) to 1.0 (right) for balance
    await player.setBalance(adjustedPan);

    // Set volume (0.0 to 1.0)
    await player.setVolume(volume);
  }

  // Apply constant power panning law
  double _applyPanningLaw(double rawPan) {
    // Ensure pan is within range
    if (rawPan < -1.0) rawPan = -1.0;
    if (rawPan > 1.0) rawPan = 1.0;

    // Apply constant power panning law
    // Using square root by default for constant power curve
    return rawPan < 0
        ? -pow(-rawPan, _panningExponent).toDouble()
        : pow(rawPan, _panningExponent).toDouble();
  }

  // Update panning and volume for all active players
  Future<void> updatePanningAndVolume(
      String observationId, double pan, double volume) async {
    if (_activePlayers.containsKey(observationId)) {
      try {
        for (var player in _activePlayers[observationId]!) {
          await _applyPanningAndVolume(player, pan, volume);
        }
      } catch (e) {
        debugPrint(
            'Error updating panning/volume for observation $observationId: $e');
      }
    }
  }

  // Stop playing sounds for an observation
  Future<void> stopSounds(String observationId) async {
    // Mark as inactive first to prevent new sounds from starting
    debugPrint('Stopping sounds for observation $observationId');
    _isActive[observationId] = false;

    // Stop all active players for this observation
    if (_activePlayers.containsKey(observationId)) {
      for (var player in _activePlayers[observationId]!) {
        try {
          await player.stop();
          await player.dispose();
        } catch (e) {
          debugPrint('Error stopping sound for observation $observationId: $e');
        }
      }
      _activePlayers[observationId]?.clear();
    }
  }

  Future<void> playRandomSoundFromFolder(String folderPath, double volume) async {
    AudioPlayer player = AudioPlayer();

    try {
      // Ensure sound files are cached
      if (!_soundFileCache.containsKey(folderPath)) {
        debugPrint("Fetching sound files for folder: $folderPath");
        List<String> files = await _storageService.listFiles(folderPath);
        if (files.isNotEmpty) {
          _soundFileCache[folderPath] = files;
        } else {
          debugPrint('No sound files found in folder: $folderPath');
          return;
        }
      }

      // Select a random file
      List<String> files = _soundFileCache[folderPath]!;
      if (files.isEmpty) {
        debugPrint('No cached sound files available for folder: $folderPath');
        return;
      }
      String randomFile = files[_random.nextInt(files.length)];

      debugPrint('Playing random sound from folder: $folderPath, file: $randomFile');

      // Set volume and play
      await player.setVolume(volume);
      await player.play(UrlSource(randomFile));
    } catch (e) {
      debugPrint('Failed to play random sound from folder $folderPath: $e');
    }
  }

  // Clean up resources
  void dispose() {
    debugPrint('Disposing all sound players');
    // Stop all active players
    for (var observationId in _activePlayers.keys) {
      for (var player in _activePlayers[observationId]!) {
        try {
          player.stop();
          player.dispose();
        } catch (e) {
          debugPrint('Error disposing player for observation $observationId: $e');
        }
      }
    }
    
    // Clean up other resources
    _playerPools.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
    _currentPlayerIndex.clear();
    _activePlayers.clear();
  }
}