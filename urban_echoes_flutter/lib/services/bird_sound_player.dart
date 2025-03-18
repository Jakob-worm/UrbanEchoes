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
  
  // Track scheduled sound timers to prevent conflicts
  final Map<String, List<Future<void>>> _scheduledSounds = {};

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
    _scheduledSounds[observationId] = [];

    // Create a pool of players for this observation if it doesn't exist
    if (!_playerPools.containsKey(observationId)) {
      _playerPools[observationId] = [];
      _currentPlayerIndex[observationId] = 0;
      
      // Create multiple players for this observation
      for (int i = 0; i < _playersPerObservation; i++) {
        AudioPlayer player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        _playerPools[observationId]!.add(player);
      }
    }

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

    // Apply panning and volume to all players in the pool
    for (var player in _playerPools[observationId]!) {
      await _applyPanningAndVolume(player, pan, volume);
    }

    // Schedule first sounds with slight delays to create more natural soundscape
    _scheduleNextSounds(folderPath, observationId, pan, volume);
  }

  // Schedule multiple sounds to create an overlapping soundscape
  void _scheduleNextSounds(String folderPath, String observationId, double pan, double volume) {
    // Schedule first sound immediately
    _playNextRandomSoundWithPanning(folderPath, observationId, pan, volume);
    
    // Schedule more sounds with delays for natural effect
    if (_isActive[observationId] == true) {
      // Create random delays between 2-8 seconds for next sounds
      int delaySeconds = _random.nextInt(6) + 2;
      var scheduledSound = Future.delayed(Duration(seconds: delaySeconds), () {
        if (_isActive[observationId] == true) {
          _playNextRandomSoundWithPanning(folderPath, observationId, pan, volume);
        }
      });
      
      // Keep track of scheduled sounds
      _scheduledSounds[observationId]?.add(scheduledSound);
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

  // Update panning and volume for all players in a pool
  Future<void> updatePanningAndVolume(
      String observationId, double pan, double volume) async {
    if (_playerPools.containsKey(observationId)) {
      try {
        for (var player in _playerPools[observationId]!) {
          await _applyPanningAndVolume(player, pan, volume);
        }
      } catch (e) {
        debugPrint(
            'Error updating panning/volume for observation $observationId: $e');
      }
    }
  }

  // Get the next available player from the pool using round-robin
  AudioPlayer _getNextPlayer(String observationId) {
    if (!_currentPlayerIndex.containsKey(observationId)) {
      _currentPlayerIndex[observationId] = 0;
    }
    
    int index = _currentPlayerIndex[observationId]!;
    // Move to next player for next time
    _currentPlayerIndex[observationId] = (index + 1) % _playersPerObservation;
    
    return _playerPools[observationId]![index];
  }

  // Play the next random sound with panning from the folder
  Future<void> _playNextRandomSoundWithPanning(
      String folderPath, String observationId, double pan, double volume) async {
    try {
      // Check if still active
      if (_isActive[observationId] != true) {
        debugPrint(
            'Observation $observationId no longer active, skipping sound');
        return;
      }

      // Use cached files if available, otherwise fetch from storage
      List<String> files;
      if (_soundFileCache.containsKey(folderPath)) {
        files = _soundFileCache[folderPath]!;
      } else {
        debugPrint("Fetching sound files for folder: $folderPath");
        files = await _storageService.listFiles(folderPath);

        // Cache the files for future use
        if (files.isNotEmpty) {
          _soundFileCache[folderPath] = files;
        }
      }

      if (files.isEmpty) {
        debugPrint('No bird sounds found in folder: $folderPath');
        return;
      }

      // Pick a random file
      String randomFile = files[_random.nextInt(files.length)];
      
      // Get next available player from the pool
      AudioPlayer player = _getNextPlayer(observationId);
      
      // Apply current panning and volume settings
      await _applyPanningAndVolume(player, pan, volume);

      // Try to play the selected file
      try {
        await player.play(UrlSource(randomFile));
        debugPrint('Playing sound file: $randomFile for observation $observationId');
        
        // Schedule the next sound after this one finishes
        player.onPlayerComplete.first.then((_) {
          if (_isActive[observationId] == true) {
            // Schedule with a random delay
            int delayMs = _random.nextInt(4000) + 1000; // 1-5 seconds
            var scheduledSound = Future.delayed(Duration(milliseconds: delayMs), () {
              if (_isActive[observationId] == true) {
                _playNextRandomSoundWithPanning(folderPath, observationId, pan, volume);
              }
            });
            
            // Keep track of scheduled sounds
            _scheduledSounds[observationId]?.add(scheduledSound);
          }
        });
      } catch (e) {
        debugPrint('Failed to play sound file $randomFile: $e');

        // If there was an error, attempt to play another sound after a delay
        if (_isActive[observationId] == true) {
          var scheduledSound = Future.delayed(Duration(seconds: 1), () {
            _playNextRandomSoundWithPanning(
                folderPath, observationId, pan, volume);
          });
          
          // Keep track of scheduled sounds
          _scheduledSounds[observationId]?.add(scheduledSound);
        }
      }
    } catch (e) {
      debugPrint(
          'Failed to play bird sound for observation $observationId: $e');

      // If there was an error, attempt to play another sound after a delay
      if (_isActive[observationId] == true) {
        var scheduledSound = Future.delayed(Duration(seconds: 3), () {
          _playNextRandomSoundWithPanning(
              folderPath, observationId, pan, volume);
        });
        
        // Keep track of scheduled sounds
        _scheduledSounds[observationId]?.add(scheduledSound);
      }
    }
  }

  // Stop playing sounds for an observation
  Future<void> stopSounds(String observationId) async {
    // Mark as inactive first to prevent new sounds from starting
    debugPrint('Stopping sounds for observation $observationId');
    _isActive[observationId] = false;

    // Stop all players for this observation
    if (_playerPools.containsKey(observationId)) {
      for (var player in _playerPools[observationId]!) {
        try {
          await player.stop();
        } catch (e) {
          debugPrint('Error stopping sound for observation $observationId: $e');
        }
      }
    }
    
    // Clear any scheduled sounds for this observation
    _scheduledSounds.remove(observationId);
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
    for (var observationId in _playerPools.keys) {
      for (var player in _playerPools[observationId]!) {
        try {
          player.stop();
          player.dispose();
        } catch (e) {
          debugPrint('Error disposing player for observation $observationId: $e');
        }
      }
    }
    _playerPools.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
    _currentPlayerIndex.clear();
    _scheduledSounds.clear();
  }
}