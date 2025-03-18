import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _isActive = {};
  final Map<String, String> _activeFolders = {};
  final AzureStorageService _storageService = AzureStorageService();
  final Random _random = Random();

  final Map<String, List<String>> _soundFileCache = {};
  final double _panningExponent = 0.5;

  Future<void> startSound(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    debugPrint('Starting sound for observation $observationId');
    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;

    await _cacheSoundFiles(folderPath);
    await _initializePlayer(observationId, pan, volume);
    _playRandomSound(folderPath, observationId, pan, volume);
  }

  Future<void> _cacheSoundFiles(String folderPath) async {
    if (_soundFileCache.containsKey(folderPath)) return;

    try {
      debugPrint("Caching sound files for folder: $folderPath");
      List<String> files = await _storageService.listFiles(folderPath);
      if (files.isNotEmpty) {
        _soundFileCache[folderPath] = files;
      } else {
        debugPrint('No sound files found in folder: $folderPath');
      }
    } catch (e) {
      debugPrint('Error caching sound files: $e');
    }
  }

  Future<void> _initializePlayer(String observationId, double pan, double volume) async {
    // Clean up existing player if any
    if (_players.containsKey(observationId)) {
      await _players[observationId]!.dispose();
    }
    
    AudioPlayer player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.stop);
    await _applyPanningAndVolume(player, pan, volume);
    _players[observationId] = player;
  }

  Future<void> _playRandomSound(String folderPath, String observationId, double pan, double volume) async {
    if (!_isActive[observationId]!) return;

    try {
      List<String> files = _soundFileCache[folderPath] ?? [];
      if (files.isEmpty) return;

      // Get a random sound file
      String randomFile = files[_random.nextInt(files.length)];
      AudioPlayer player = _players[observationId]!;
      
      // Make sure panning and volume are up to date
      await _applyPanningAndVolume(player, pan, volume);
      
      // Play the sound
      await player.play(UrlSource(randomFile));
      debugPrint('Playing sound for observation $observationId: $randomFile');

      // Set up completion handler to play another sound after a random delay
      player.onPlayerComplete.listen((_) {
        if (_isActive[observationId] == true) {
          // Random delay between 3-8 seconds for natural bird call spacing
          Future.delayed(Duration(milliseconds: _random.nextInt(5000) + 3000), () {
            if (_isActive[observationId] == true) {
              _playRandomSound(folderPath, observationId, pan, volume);
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error playing sound for observation $observationId: $e');
      // Try again after a delay if there was an error
      Future.delayed(Duration(seconds: 2), () {
        if (_isActive[observationId] == true) {
          _playRandomSound(folderPath, observationId, pan, volume);
        }
      });
    }
  }

  Future<void> _applyPanningAndVolume(AudioPlayer player, double pan, double volume) async {
    double adjustedPan = _applyPanningLaw(pan);
    await player.setBalance(adjustedPan);
    await player.setVolume(volume);
  }

  double _applyPanningLaw(double rawPan) {
    if (rawPan < -1.0) rawPan = -1.0;
    if (rawPan > 1.0) rawPan = 1.0;
    return rawPan < 0 ? -pow(-rawPan, _panningExponent).toDouble() : pow(rawPan, _panningExponent).toDouble();
  }

  Future<void> updatePanningAndVolume(String observationId, double pan, double volume) async {
    if (_players.containsKey(observationId)) {
      try {
        await _applyPanningAndVolume(_players[observationId]!, pan, volume);
      } catch (e) {
        debugPrint('Error updating panning/volume for observation $observationId: $e');
      }
    }
  }

  Future<void> stopSounds(String observationId) async {
    debugPrint('Stopping sounds for observation $observationId');
    _isActive[observationId] = false;

    if (_players.containsKey(observationId)) {
      try {
        await _players[observationId]!.stop();
        await _players[observationId]!.dispose();
        _players.remove(observationId);
      } catch (e) {
        debugPrint('Error stopping sound for observation $observationId: $e');
      }
    }
  }

  Future<void> playRandomSoundFromFolder(String folderPath, double volume) async {
    AudioPlayer player = AudioPlayer();

    try {
      if (!_soundFileCache.containsKey(folderPath)) {
        debugPrint("Fetching sound files for folder: $folderPath");
        List<String> files = await _storageService.listFiles(folderPath);
        if (files.isNotEmpty) {
          _soundFileCache[folderPath] = files;
        } else {
          debugPrint('No sound files found in folder: $folderPath');
          player.dispose();
          return;
        }
      }

      List<String> files = _soundFileCache[folderPath]!;
      if (files.isEmpty) {
        debugPrint('No cached sound files available for folder: $folderPath');
        player.dispose();
        return;
      }
      String randomFile = files[_random.nextInt(files.length)];

      debugPrint('Playing random sound from folder: $folderPath, file: $randomFile');
      await player.setVolume(volume);
      await player.play(UrlSource(randomFile));
      
      // Dispose the player after it completes
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('Failed to play random sound from folder $folderPath: $e');
      player.dispose();
    }
  }

  void dispose() {
    debugPrint('Disposing all sound players');
    for (var observationId in _players.keys) {
      try {
        _players[observationId]!.stop();
        _players[observationId]!.dispose();
      } catch (e) {
        debugPrint('Error disposing player for observation $observationId: $e');
      }
    }

    _players.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
  }
}