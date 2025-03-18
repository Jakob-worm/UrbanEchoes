import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  final Map<String, List<AudioPlayer>> _playerPools = {};
  final Map<String, bool> _isActive = {};
  final Map<String, String> _activeFolders = {};
  final AzureStorageService _storageService = AzureStorageService();
  final Random _random = Random();

  final Map<String, List<String>> _soundFileCache = {};
  final double _panningExponent = 0.5;
  final int _playersPerObservation = 3;
  final Map<String, int> _currentPlayerIndex = {};
  final Map<String, Set<AudioPlayer>> _activePlayers = {};

  Future<void> startSound(String folderPath, String observationId, double pan, double volume) async {
    return startSequentialRandomSoundsWithPanning(folderPath, observationId, pan, volume);
  }

  Future<void> startSequentialRandomSoundsWithPanning(String folderPath, String observationId, double pan, double volume) async {
    if (_isActive[observationId] == true) {
      await updatePanningAndVolume(observationId, pan, volume);
      return;
    }

    debugPrint('Starting new sound player pool for observation $observationId');
    _isActive[observationId] = true;
    _activeFolders[observationId] = folderPath;
    _activePlayers[observationId] = {};

    await _cacheSoundFiles(folderPath);
    await _initializePlayerPool(observationId, pan, volume);
    _startInitialSounds(folderPath, observationId, pan, volume);
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

  Future<void> _initializePlayerPool(String observationId, double pan, double volume) async {
    if (!_playerPools.containsKey(observationId)) {
      _playerPools[observationId] = [];
      _currentPlayerIndex[observationId] = 0;
    }

    while (_playerPools[observationId]!.length < _playersPerObservation) {
      AudioPlayer player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await _applyPanningAndVolume(player, pan, volume);
      _playerPools[observationId]!.add(player);
    }
  }

  void _startInitialSounds(String folderPath, String observationId, double pan, double volume) {
    _playRandomSound(folderPath, observationId, pan, volume);
    Future.delayed(Duration(milliseconds: _random.nextInt(2000) + 1000), () {
      if (_isActive[observationId] == true) {
        _playRandomSound(folderPath, observationId, pan, volume);
      }
    });
  }

  Future<void> _playRandomSound(String folderPath, String observationId, double pan, double volume) async {
    if (!_isActive[observationId]!) return;

    try {
      List<String> files = _soundFileCache[folderPath] ?? [];
      if (files.isEmpty) return;

      String randomFile = files[_random.nextInt(files.length)];
      AudioPlayer player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await _applyPanningAndVolume(player, pan, volume);

      _activePlayers[observationId]?.add(player);
      await player.play(UrlSource(randomFile));
      debugPrint('Playing sound for observation $observationId: $randomFile');

      player.onPlayerComplete.listen((_) {
        _activePlayers[observationId]?.remove(player);
        player.dispose();
        if (_isActive[observationId] == true) {
          Future.delayed(Duration(milliseconds: _random.nextInt(3000) + 1000), () {
            if (_isActive[observationId] == true) {
              _playRandomSound(folderPath, observationId, pan, volume);
            }
          });
        }
      });

      if (_activePlayers[observationId]!.length < _playersPerObservation) {
        Future.delayed(Duration(milliseconds: _random.nextInt(4000) + 2000), () {
          if (_isActive[observationId]! && _activePlayers[observationId]!.length < _playersPerObservation) {
            _playRandomSound(folderPath, observationId, pan, volume);
          }
        });
      }
    } catch (e) {
      debugPrint('Error playing sound for observation $observationId: $e');
      Future.delayed(Duration(seconds: 2), () {
        if (_isActive[observationId] == true) {
          _playRandomSound(folderPath, observationId, pan, volume);
        }
      });
    }
  }

  Future<void> startSequentialRandomSounds(String folderPath, String observationId) async {
    await startSequentialRandomSoundsWithPanning(folderPath, observationId, 0.0, 1.0);
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
    if (_activePlayers.containsKey(observationId)) {
      try {
        for (var player in _activePlayers[observationId]!) {
          await _applyPanningAndVolume(player, pan, volume);
        }
      } catch (e) {
        debugPrint('Error updating panning/volume for observation $observationId: $e');
      }
    }
  }

  Future<void> stopSounds(String observationId) async {
    debugPrint('Stopping sounds for observation $observationId');
    _isActive[observationId] = false;

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

      List<String> files = _soundFileCache[folderPath]!;
      if (files.isEmpty) {
        debugPrint('No cached sound files available for folder: $folderPath');
        return;
      }
      String randomFile = files[_random.nextInt(files.length)];

      debugPrint('Playing random sound from folder: $folderPath, file: $randomFile');
      await player.setVolume(volume);
      await player.play(UrlSource(randomFile));
    } catch (e) {
      debugPrint('Failed to play random sound from folder $folderPath: $e');
    }
  }

  void dispose() {
    debugPrint('Disposing all sound players');
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

    _playerPools.clear();
    _isActive.clear();
    _activeFolders.clear();
    _soundFileCache.clear();
    _currentPlayerIndex.clear();
    _activePlayers.clear();
  }
}