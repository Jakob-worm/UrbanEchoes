import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  final Map<int, AudioPlayer> _players = {};
  final Map<int, bool> _isActive = {};
  final Map<int, String> _activeFolders =
      {}; // Track the folder for each observation
  final AzureStorageService _storageService = AzureStorageService();
  final Random _random = Random();

  // Cache sound files by folder to avoid repeated API calls
  final Map<String, List<String>> _soundFileCache = {};

  // Parameters for panning calculation
  final double _panningExponent = 0.5; // Square root for constant power pan law

  // Public method that LocationService will call
  Future<void> startSound(
      String folderPath, int observationId, double pan, double volume) async {
    return startSequentialRandomSoundsWithPanning(
        folderPath, observationId, pan, volume);
  }

  // Start playing random sounds in sequence for an observation with panning
  Future<void> startSequentialRandomSoundsWithPanning(
      String folderPath, int observationId, double pan, double volume) async {
    // If already active, just update panning and volume
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    debugPrint('Starting new sound player for observation $observationId');

    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;

    // Create a dedicated player for this observation if it doesn't exist
    if (!_players.containsKey(observationId)) {
      _players[observationId] = AudioPlayer();

      // Configure for multiple streams
      await _players[observationId]!.setReleaseMode(ReleaseMode.stop);

      // Set up completion listener to play the next sound
      _players[observationId]!.onPlayerComplete.listen((_) {
        // When sound finishes, play another if still active
        if (_isActive[observationId] == true) {
          _playNextRandomSoundWithPanning(
              _activeFolders[observationId]!, observationId, pan, volume);
        }
      });
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

    // Apply panning and volume
    await _applyPanningAndVolume(_players[observationId]!, pan, volume);

    // Start playing the first sound
    await _playNextRandomSoundWithPanning(
        folderPath, observationId, pan, volume);
  }

  // For backward compatibility
  Future<void> startSequentialRandomSounds(
      String folderPath, int observationId) async {
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

    debugPrint('Applied pan=$adjustedPan, volume=$volume to player');
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

  // Update panning and volume for an existing player
  Future<void> updatePanningAndVolume(
      int observationId, double pan, double volume) async {
    if (_players.containsKey(observationId)) {
      try {
        await _applyPanningAndVolume(_players[observationId]!, pan, volume);
      } catch (e) {
        debugPrint(
            'Error updating panning/volume for observation $observationId: $e');
      }
    }
  }

  // Play the next random sound with panning from the folder
  Future<void> _playNextRandomSoundWithPanning(
      String folderPath, int observationId, double pan, double volume) async {
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
      debugPrint(
          'Playing sound file: $randomFile for observation $observationId');

      // Apply current panning and volume settings
      await _applyPanningAndVolume(_players[observationId]!, pan, volume);

      // Try to play the selected file
      try {
        // Ensure player isn't already playing something
        if (_players[observationId]!.state == PlayerState.playing) {
          await _players[observationId]!.stop();
        }

        await _players[observationId]!.play(UrlSource(randomFile));
        debugPrint('Sound playing for observation $observationId');
      } catch (e) {
        debugPrint('Failed to play sound file $randomFile: $e');

        // If there was an error, attempt to play another sound after a delay
        if (_isActive[observationId] == true) {
          Future.delayed(Duration(seconds: 1), () {
            _playNextRandomSoundWithPanning(
                folderPath, observationId, pan, volume);
          });
        }
      }
    } catch (e) {
      debugPrint(
          'Failed to play bird sound for observation $observationId: $e');

      // If there was an error, attempt to play another sound after a delay
      if (_isActive[observationId] == true) {
        Future.delayed(Duration(seconds: 3), () {
          _playNextRandomSoundWithPanning(
              folderPath, observationId, pan, volume);
        });
      }
    }
  }

  // Stop playing sounds for an observation
  Future<void> stopSounds(int observationId) async {
    // Mark as inactive first to prevent new sounds from starting
    debugPrint('Stopping sounds for observation $observationId');
    _isActive[observationId] = false;

    // Stop the player if it exists
    if (_players.containsKey(observationId)) {
      try {
        await _players[observationId]!.stop();
      } catch (e) {
        debugPrint('Error stopping sound for observation $observationId: $e');
      }
    }
  }

  // Clean up resources
  void dispose() {
    debugPrint('Disposing all sound players');
    for (var id in _players.keys) {
      try {
        _players[id]!.stop();
        _players[id]!.dispose();
      } catch (e) {
        debugPrint('Error disposing player for observation $id: $e');
      }
    }
    _players.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
  }
}
