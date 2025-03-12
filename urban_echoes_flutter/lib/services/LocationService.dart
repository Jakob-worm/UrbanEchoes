import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'ObservationService.dart';

class LocationService {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final BirdSoundPlayer _birdSoundPlayer = BirdSoundPlayer();
  List<Map<String, dynamic>> _observations = [];
  bool _isInitialized = false;

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    _observations =
        await ObservationService(apiUrl: apiUrl).fetchObservations();
    _startTrackingLocation();
    _isInitialized = true;
  }

  void _startTrackingLocation() {
    _geolocatorPlatform.getPositionStream().listen((Position position) {
      _checkProximityToPoints(position);
    });
  }

  void _checkProximityToPoints(Position position) {
    for (var obs in _observations) {
      final distance = Distance().as(
        LengthUnit.Meter,
        LatLng(position.latitude, position.longitude),
        LatLng(obs["latitude"], obs["longitude"]),
      );

      if (distance <= 100) {
        _playSound(obs["sound_directory"]);
      }
    }
  }

  void _playSound(String soundUrl) {
    try {
      _birdSoundPlayer.playRandomSound(soundUrl);
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void dispose() {
    _birdSoundPlayer.dispose();
  }
}
