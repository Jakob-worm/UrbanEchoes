import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class SpatialAudioManager {
  // Configuration
  final double _maxDistance = 200.0; // Max distance to hear sound (meters)
  final double _minVolume = 0.05;    // Minimum volume at max distance
  final double _maxVolume = 1.0;     // Maximum volume at center

  // Audio players
  final Map<String, AudioPlayer> _players = {};
  final Map<String, String> _currentFiles = {};
  final Map<String, Timer> _playerTimers = {};
  final Random _random = Random();
  
  // Sound sources
  final Map<String, _SoundSource> _soundSources = {};
  
  // Debugging
  final bool _debugMode = true;

  void _log(String message) {
    if (_debugMode) {
      debugPrint(message);
    }
  }

  // Add a sound source at a specific location
  void addSoundSource(String id, double latitude, double longitude, List<String> audioUrls) {
    if (audioUrls.isEmpty) {
      _log('Cannot add sound source with no audio URLs');
      return;
    }
    
    _soundSources[id] = _SoundSource(
      id: id,
      latitude: latitude,
      longitude: longitude,
      audioUrls: audioUrls,
    );
    
    _log('Added sound source: $id at $latitude, $longitude with ${audioUrls.length} sounds');
    
    // Start playing this sound source immediately if not already playing
    if (!_players.containsKey(id)) {
      _createPlayerAndPlay(id, audioUrls);
    }
  }
  
  // Remove a sound source
  void removeSoundSource(String id) {
    if (_soundSources.containsKey(id)) {
      _soundSources.remove(id);
      _stopSound(id);
      _log('Removed sound source: $id');
    }
  }
  
  // Update user position
  void updateUserPosition(Position position) {
    // Check each sound source
    for (var source in _soundSources.values) {
      final distance = _calculateDistance(
        position.latitude, position.longitude,
        source.latitude, source.longitude
      );
      
      if (distance <= _maxDistance) {
        // Sound is in range
        final pan = _calculatePan(
          position.latitude, position.longitude,
          source.latitude, source.longitude
        );
        
        final volume = _calculateVolume(distance);
        
        // Start or update sound
        if (!_players.containsKey(source.id)) {
          _createPlayerAndPlay(source.id, source.audioUrls, pan, volume);
        } else {
          _updatePlayerSettings(source.id, pan, volume);
        }
      } else if (_players.containsKey(source.id)) {
        // Sound is out of range but playing - stop it
        _stopSound(source.id);
      }
    }
  }
  
  // Calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
  
  // Calculate panning based on relative position
  double _calculatePan(double userLat, double userLng, double soundLat, double soundLng) {
    // Calculate bearing to sound
    double bearing = _calculateBearing(userLat, userLng, soundLat, soundLng);
    
    // Normalize bearing to -180 to 180
    if (bearing > 180) bearing -= 360;
    if (bearing < -180) bearing += 360;
    
    // Map to -1 to 1 for audio pan
    double pan = bearing / 90.0;
    return pan.clamp(-1.0, 1.0);
  }
  
  // Calculate bearing between points
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    // Convert to radians
    lat1 = lat1 * pi / 180;
    lng1 = lng1 * pi / 180;
    lat2 = lat2 * pi / 180;
    lng2 = lng2 * pi / 180;

    // Calculate bearing
    double y = sin(lng2 - lng1) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lng2 - lng1);
    double bearingRad = atan2(y, x);

    // Convert to degrees
    double bearingDeg = bearingRad * 180 / pi;
    return (bearingDeg + 360) % 360;
  }
  
  // Calculate volume based on distance
  double _calculateVolume(double distance) {
    // Linear falloff with minimum volume
    double falloff = 1.0 - (distance / _maxDistance);
    double volume = _minVolume + falloff * (_maxVolume - _minVolume);
    return volume.clamp(_minVolume, _maxVolume);
  }
  
  // Create a new audio player and start playing
  void _createPlayerAndPlay(String id, List<String> audioUrls, [double pan = 0.0, double volume = 0.5]) {
    _log('CREATING NEW PLAYER FOR $id');
    
    try {
      // Create a new player
      AudioPlayer player = AudioPlayer();
      _players[id] = player;
      
      // Configure the player for this sound source
      player.setReleaseMode(ReleaseMode.stop);
      
      // Set pan and volume
      _updatePlayerSettings(id, pan, volume);
      
      // Set up completion listener
      player.onPlayerComplete.listen((_) {
        _log('Sound completed for $id');
        // Schedule next sound with random delay
        _scheduleNextSound(id, audioUrls);
      });
      
      // Start playing a random sound
      _playRandomSound(id, audioUrls);
      
      _log('Created player for $id');
    } catch (e) {
      _log('Error creating player: $e');
    }
  }
  
  // Update player settings (pan and volume)
  void _updatePlayerSettings(String id, double pan, double volume) {
    if (!_players.containsKey(id)) return;
    
    try {
      final player = _players[id]!;
      
      player.setVolume(volume);
      player.setBalance(pan);
      
      _log('Updated player $id: pan=$pan, volume=$volume');
    } catch (e) {
      _log('Error updating player settings: $e');
    }
  }
  
  // Play a random sound from the list
  void _playRandomSound(String id, List<String> audioUrls) {
    if (audioUrls.isEmpty || !_players.containsKey(id)) return;
    
    try {
      final player = _players[id]!;
      
      // Pick a random audio file
      String audioUrl = audioUrls[_random.nextInt(audioUrls.length)];
      
      // Don't play the same file twice in a row if possible
      if (audioUrls.length > 1 && audioUrl == _currentFiles[id]) {
        audioUrl = audioUrls[(audioUrls.indexOf(audioUrl) + 1) % audioUrls.length];
      }
      
      _currentFiles[id] = audioUrl;
      
      _log('Playing sound for $id: $audioUrl');
      
      // Use play with UrlSource to play the file
      player.play(UrlSource(audioUrl)).catchError((error) {
        _log('Error playing sound: $error');
        // Schedule retry
        _scheduleNextSound(id, audioUrls, immediate: false);
      });
    } catch (e) {
      _log('Error in playRandomSound: $e');
      // Schedule retry
      _scheduleNextSound(id, audioUrls, immediate: false);
    }
  }
  
  // Schedule the next sound to play
  void _scheduleNextSound(String id, List<String> audioUrls, {bool immediate = false}) {
    // Cancel any existing timer
    _playerTimers[id]?.cancel();
    
    // Random delay between 1-4 seconds (or immediate)
    final delay = immediate ? 0 : _random.nextInt(3000) + 1000;
    
    _playerTimers[id] = Timer(Duration(milliseconds: delay), () {
      if (_players.containsKey(id)) {
        _playRandomSound(id, audioUrls);
      }
    });
  }
  
  // Stop a sound
  void _stopSound(String id) {
    _playerTimers[id]?.cancel();
    _playerTimers.remove(id);
    
    if (_players.containsKey(id)) {
      try {
        final player = _players[id]!;
        
        // Force release the player
        player.stop().then((_) {
          player.dispose();
          _players.remove(id);
          _currentFiles.remove(id);
          _log('Stopped sound for $id');
        }).catchError((e) {
          _log('Error stopping sound: $e');
          _players.remove(id);
        });
      } catch (e) {
        _log('Error in stopSound: $e');
        _players.remove(id);
      }
    }
  }
  
  // Stop all sounds
  void stopAllSounds() {
    List<String> ids = List<String>.from(_players.keys);
    for (String id in ids) {
      _stopSound(id);
    }
    _log('Stopped all sounds');
  }
  
  // Dispose
  void dispose() {
    stopAllSounds();
    _playerTimers.forEach((_, timer) => timer.cancel());
    _playerTimers.clear();
    _soundSources.clear();
    _log('SpatialAudioManager disposed');
  }
}

// Class to represent a sound source
class _SoundSource {
  final String id;
  final double latitude;
  final double longitude;
  final List<String> audioUrls;
  
  _SoundSource({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.audioUrls,
  });
}