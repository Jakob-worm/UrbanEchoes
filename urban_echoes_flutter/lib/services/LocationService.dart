import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/consants.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'ObservationService.dart';

class LocationService {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final BirdSoundPlayer _birdSoundPlayer = BirdSoundPlayer();
  List<Map<String, dynamic>> _observations = [];
  bool _isInitialized = false;
  // Track the active bird sound information
  final Map<int, Map<String, dynamic>> _activeBirdSounds = {};

  // Track which observations are currently active
  final Map<int, bool> _activeObservations = {};

  // Spatial grid for quick lookups (using 1km grid cells)
  final Map<String, List<Map<String, dynamic>>> _spatialGrid = {};
  final int _gridSize = AppConstants.gridSize;

  // Store last position to avoid redundant checks
  Position? _lastPosition;
  String? _lastGridCell;

  static const int _locationUpdateIntervalSeconds = 5;

  // Parameters for spatial audio
  final double _maxAudioDistance =
      AppConstants.defaultPointRadius; // Maximum distance for audio (in meters)

  List<Map<String, dynamic>> getActiveBirdSounds() {
    if (_activeBirdSounds.isNotEmpty) {
      return _activeBirdSounds.values.toList();
    } else {
      return [];
    }
  }

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    _observations =
        await ObservationService(apiUrl: apiUrl).fetchObservations();

    // Initialize active observations map
    for (var obs in _observations) {
      int id = obs["id"];
      _activeObservations[id] = false;
    }

    // Build spatial grid for efficient lookups
    _buildSpatialGrid();

    await _requestLocationPermission();
    _startTrackingLocation();
    _isInitialized = true;
  }

  // Create a spatial grid for efficient proximity queries
  void _buildSpatialGrid() {
    for (var observation in _observations) {
      double lat = observation["latitude"];
      double lng = observation["longitude"];

      // Calculate grid cell key based on coordinates
      String gridKey = _getGridCellKey(lat, lng);

      // Add observation to appropriate grid cell
      if (!_spatialGrid.containsKey(gridKey)) {
        _spatialGrid[gridKey] = [];
      }
      _spatialGrid[gridKey]!.add(observation);
    }

    debugPrint('Built spatial grid with ${_spatialGrid.length} cells');
  }

  // Get the cell key for a specific latitude and longitude
  String _getGridCellKey(double lat, double lng) {
    // Convert coordinates to grid cell indices
    int latIndex =
        (lat * 111319 / _gridSize).floor(); // 1 degree lat ≈ 111.319 km
    int lngIndex = (lng * 111319 * cos(lat * pi / 180) / _gridSize)
        .floor(); // Adjust for longitude

    return '$latIndex:$lngIndex';
  }

  // Get all grid cells that could contain points within range
  List<String> _getNeighboringCells(double lat, double lng) {
    List<String> cells = [];
    String centerCell = _getGridCellKey(lat, lng);
    cells.add(centerCell);

    // Add adjacent cells (for points that might be near grid cell boundaries)
    int latIndex = (lat * 111319 / _gridSize).floor();
    int lngIndex = (lng * 111319 * cos(lat * pi / 180) / _gridSize).floor();

    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        if (i == 0 && j == 0) continue; // Skip center cell (already added)
        cells.add('${latIndex + i}:${lngIndex + j}');
      }
    }

    return cells;
  }

  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions permanently denied');
      return false;
    }

    return true;
  }

  void _startTrackingLocation() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update when user moves 10 meters
      timeLimit: Duration(seconds: _locationUpdateIntervalSeconds),
    );

    _geolocatorPlatform
        .getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _processLocationUpdate(position);
    });
  }

  void _processLocationUpdate(Position position) {
    // Check if we've moved to a new grid cell
    String currentGridCell =
        _getGridCellKey(position.latitude, position.longitude);

    // Skip processing if we're in the same grid cell and haven't moved significantly
    if (_lastPosition != null && _lastGridCell == currentGridCell) {
      double distance = Geolocator.distanceBetween(_lastPosition!.latitude,
          _lastPosition!.longitude, position.latitude, position.longitude);

      // If we haven't moved more than 0.2 meters, skip this update
      if (distance < 0.2) {
        return;
      }
    }

    _lastPosition = position;
    _lastGridCell = currentGridCell;

    // Check points only in relevant grid cells
    _checkProximityToPoints(position);
  }

  // Modified method to process proximity and calculate panning
  void _checkProximityToPoints(Position position) {
    // Get all potentially relevant grid cells
    List<String> cells =
        _getNeighboringCells(position.latitude, position.longitude);

    // Create a set of observations we've checked to avoid duplicates
    Set<int> checkedObservations = {};

    // First, check observations in current and neighboring cells
    for (String cell in cells) {
      if (!_spatialGrid.containsKey(cell)) continue;

      for (var obs in _spatialGrid[cell]!) {
        final int id = obs["id"];

        // Skip if already checked
        if (checkedObservations.contains(id)) continue;
        checkedObservations.add(id);

        final distance = Distance().as(
          LengthUnit.Meter,
          LatLng(position.latitude, position.longitude),
          LatLng(obs["latitude"], obs["longitude"]),
        );

        // User is inside the observation area
        if (distance <= _maxAudioDistance) {
          // Calculate panning and volume based on position
          final double pan = _calculatePanning(position.latitude,
              position.longitude, obs["latitude"], obs["longitude"]);

          // Calculate volume based on distance (closer = louder)
          final double volume = _calculateVolume(distance);

          if (!_activeObservations.containsKey(id) ||
              !_activeObservations[id]!) {
            // Start playing sequential random sounds with panning
            _startSequentialSoundsWithPanning(
                obs["sound_directory"], id, pan, volume);
            _activeObservations[id] = true;
          } else {
            // Update panning and volume for already playing sounds
            _updatePanningAndVolume(id, pan, volume);
          }
        }
        // User left the observation area
        else if (_activeObservations.containsKey(id) &&
            _activeObservations[id]!) {
          // Stop playing sounds
          _stopSounds(id);
          _activeObservations[id] = false;
        }
      }
    }

    // Handle any active observations that weren't in checked grid cells
    Set<int> activeIds = Set.from(_activeObservations.keys
        .where((id) => _activeObservations[id]!)
        .toList());

    Set<int> uncheckedActiveIds = activeIds.difference(checkedObservations);

    // For any active observations that weren't checked, verify if they should still be active
    for (int id in uncheckedActiveIds) {
      // Find the observation in our main list
      var obs =
          _observations.firstWhere((o) => o["id"] == id, orElse: () => {});
      if (obs.isEmpty) continue;

      final distance = Distance().as(
        LengthUnit.Meter,
        LatLng(position.latitude, position.longitude),
        LatLng(obs["latitude"], obs["longitude"]),
      );

      if (distance > _maxAudioDistance) {
        _stopSounds(id);
        _activeObservations[id] = false;
      } else {
        // Update panning and volume
        final double pan = _calculatePanning(position.latitude,
            position.longitude, obs["latitude"], obs["longitude"]);
        final double volume = _calculateVolume(distance);
        _updatePanningAndVolume(id, pan, volume);
      }
    }
  }

  // If you have access to user heading (compass direction)
  double _calculatePanning(
      double userLat, double userLng, double soundLat, double soundLng,
      [double userHeading = 0.0]) {
    double bearing = _calculateBearing(userLat, userLng, soundLat, soundLng);

    // Calculate relative bearing by considering user's heading
    double relativeBearing = bearing - userHeading;

    // Normalize to -180 to 180 range
    if (relativeBearing > 180) relativeBearing -= 360;
    if (relativeBearing < -180) relativeBearing += 360;

    // Map to -1 to 1 range, clamping at -1 and 1
    double pan = relativeBearing / 90.0;
    if (pan > 1.0) pan = 1.0;
    if (pan < -1.0) pan = -1.0;

    return pan;
  }

  // Calculate bearing in degrees from point 1 to point 2
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
    return (bearingDeg + 360) % 360; // Ensure result is between 0 and 360
  }

  // Calculate volume based on distance
  double _calculateVolume(double distance) {
    // Linear falloff with distance
    double volume = 1.0 - (distance / _maxAudioDistance);

    // Ensure volume is between 0.0 and 1.0
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;

    return volume;
  }

  // Start sequential sounds with panning
  Future<void> _startSequentialSoundsWithPanning(String soundDirectory,
      int observationId, double pan, double volume) async {
    try {
      await _birdSoundPlayer.startSequentialRandomSoundsWithPanning(
          soundDirectory, observationId, pan, volume);
      _activeBirdSounds[observationId] =
          _observations.firstWhere((obs) => obs["id"] == observationId);
    } catch (e) {
      debugPrint('Error starting bird sounds with panning: $e');
    }
  }

  // Update panning and volume for already playing sounds
  Future<void> _updatePanningAndVolume(
      int observationId, double pan, double volume) async {
    try {
      await _birdSoundPlayer.updatePanningAndVolume(observationId, pan, volume);
    } catch (e) {
      debugPrint('Error updating panning and volume: $e');
    }
  }

  // The original methods can stay as they are but should be updated to use the new panning methods
  Future<void> _startSequentialSounds(
      String soundDirectory, int observationId) async {
    // Now calls the panning version with neutral panning (center)
    await _startSequentialSoundsWithPanning(
        soundDirectory, observationId, 0.0, 1.0);
  }

  // Other methods remain unchanged
  Future<void> _stopSounds(int observationId) async {
    try {
      await _birdSoundPlayer.stopSounds(observationId);
    } catch (e) {
      debugPrint('Error stopping bird sounds: $e');
    }
  }

  // Existing methods can remain unchanged
  void dispose() {
    // Stop all active sounds
    _activeObservations.forEach((id, isActive) {
      if (isActive) {
        _birdSoundPlayer.stopSounds(id);
      }
    });
    _birdSoundPlayer.dispose();
  }
}
