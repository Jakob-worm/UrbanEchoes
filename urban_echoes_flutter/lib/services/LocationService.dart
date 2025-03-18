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

  // Added a flag to check if location tracking is enabled
  bool _isLocationTrackingEnabled = true;

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );

  // Track the active bird sound information
  final Map<String, Map<String, dynamic>> _activeBirdSounds = {};

  // Track which observations are currently active
  final Map<String, bool> _activeObservations = {};

  // Spatial grid for quick lookups (using 1km grid cells)
  final Map<String, List<Map<String, dynamic>>> _spatialGrid = {};
  final int _gridSize = AppConstants.gridSize;

  // Parameters for spatial audio
  final double _maxAudioDistance = AppConstants.defaultPointRadius;

  // Getter for active sounds
  List<Map<String, dynamic>> getActiveBirdSounds() {
    return _activeBirdSounds.values.toList();
  }

  // Getters for tracking state
  bool get isInitialized => _isInitialized;
  bool get isLocationTrackingEnabled => _isLocationTrackingEnabled;

  // Toggle location tracking
  void toggleLocationTracking(bool enabled) {
    _isLocationTrackingEnabled = enabled;
    if (enabled) {
      _startTrackingLocation();
    } else {
      // Stop all active sounds when tracking is disabled
      _stopAllSounds();
    }
  }

  // Stop all active sounds
  void _stopAllSounds() {
    List<String> activeIds = List<String>.from(_activeObservations.keys.where((id) => _activeObservations[id] == true));
    for (String id in activeIds) {
      _stopSounds(id);
      _activeObservations[id] = false;
      _activeBirdSounds.remove(id);
    }
  }

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      debugPrint('LocationService already initialized, skipping...');
      return;
    }

    // Force reinitialize any existing audio resources
    _birdSoundPlayer.dispose();
    _activeBirdSounds.clear();
    _activeObservations.clear();

    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    try {
      _observations =
          await ObservationService(apiUrl: apiUrl).fetchObservations();

      // Initialize active observations map
      // Generate a unique ID for each observation
      for (var obs in _observations) {
        // Create a unique ID combining coordinates and other unique values
        String uniqueId = "${obs["latitude"]}_${obs["longitude"]}_${obs["sound_directory"]}";
        obs["uniqueId"] = uniqueId;  // Add uniqueId to observation
        _activeObservations[uniqueId] = false;
      }

      // Build spatial grid for efficient lookups
      _buildSpatialGrid();

      await _requestLocationPermission();
      _startTrackingLocation();
      _isInitialized = true;

      debugPrint(
          'LocationService initialized with ${_observations.length} observations');
    } catch (e) {
      debugPrint('Failed to initialize LocationService: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load bird observations. Please check your internet connection.')),
      );
    }
  }

  // Create a spatial grid for efficient proximity queries
  void _buildSpatialGrid() {
    _spatialGrid.clear();
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
    int latIndex = (lat * 111319 / _gridSize).floor();
    int lngIndex = (lng * 111319 * cos(lat * pi / 180) / _gridSize).floor();

    return '$latIndex:$lngIndex';
  }

  // Get all grid cells that could contain points within range
  List<String> _getNeighboringCells(double lat, double lng) {
    List<String> cells = [];
    String centerCell = _getGridCellKey(lat, lng);
    cells.add(centerCell);

    // Add adjacent cells - use a larger radius to be safe
    int latIndex = (lat * 111319 / _gridSize).floor();
    int lngIndex = (lng * 111319 * cos(lat * pi / 180) / _gridSize).floor();

    for (int i = -3; i <= 3; i++) {
      for (int j = -3; j <= 3; j++) {
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
    if (!_isLocationTrackingEnabled) {
      debugPrint('Location tracking is disabled, not starting');
      return;
    }

    // First cancel any previous streams
    _geolocatorPlatform.getPositionStream().listen(null).cancel();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter:
          2, // Update when user moves just 2 meters for more frequent updates
      timeLimit: Duration(seconds: 3), // More frequent updates
    );

    _geolocatorPlatform
        .getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _processLocationUpdate(position);
    });

    debugPrint('Started location tracking');
  }

  void _processLocationUpdate(Position position) {
    if (!_isLocationTrackingEnabled) {
      debugPrint('Location tracking is disabled, ignoring update');
      return;
    }

    // Debug position updates
    debugPrint('Position update: ${position.latitude}, ${position.longitude}');

    // Process all nearby observations
    _checkProximityToPoints(position);
  }

  // Modified method to process proximity and calculate panning
  void _checkProximityToPoints(Position position) {
    debugPrint('Checking proximity to observation points...');

    // Get all potentially relevant grid cells
    List<String> cells =
        _getNeighboringCells(position.latitude, position.longitude);

    // Track which observations should be active
    Set<String> observationsInRange = {};

    // First pass: find all observations in range
    for (String cell in cells) {
      if (!_spatialGrid.containsKey(cell)) continue;

      for (var obs in _spatialGrid[cell]!) {
        final String uniqueId = obs["uniqueId"];

        // Skip if already checked
        if (observationsInRange.contains(uniqueId)) continue;

        final distance = Distance().as(
          LengthUnit.Meter,
          LatLng(position.latitude, position.longitude),
          LatLng(obs["latitude"], obs["longitude"]),
        );

        // User is inside the observation area
        if (distance <= _maxAudioDistance) {
          observationsInRange.add(uniqueId);
        }
      }
    }

    debugPrint('Found ${observationsInRange.length} observations in range');

    // Second pass: start/update sounds for observations in range
    for (String uniqueId in observationsInRange) {
      var obs = _observations.firstWhere((o) => o["uniqueId"] == uniqueId);

      // Calculate panning and volume
      final double pan = _calculatePanning(position.latitude,
          position.longitude, obs["latitude"], obs["longitude"]);

      // Calculate volume based on distance
      final distance = Distance().as(
        LengthUnit.Meter,
        LatLng(position.latitude, position.longitude),
        LatLng(obs["latitude"], obs["longitude"]),
      );
      final double volume = _calculateVolume(distance);

      if (!_activeObservations.containsKey(uniqueId) || !_activeObservations[uniqueId]!) {
        // Start playing sound
        debugPrint(
            'Starting sound for observation $uniqueId with pan=$pan, volume=$volume');
        _startSound(obs["sound_directory"], uniqueId, pan, volume);
        _activeObservations[uniqueId] = true;
        _activeBirdSounds[uniqueId] = obs;
      } else {
        // Update existing sound
        debugPrint(
            'Updating sound for observation $uniqueId with pan=$pan, volume=$volume');
        _updatePanningAndVolume(uniqueId, pan, volume);
      }
    }

    // Third pass: stop sounds for observations out of range
    List<String> toStop = [];
    _activeObservations.forEach((uniqueId, isActive) {
      if (isActive && !observationsInRange.contains(uniqueId)) {
        toStop.add(uniqueId);
      }
    });

    for (String uniqueId in toStop) {
      debugPrint('Stopping sound for observation $uniqueId (out of range)');
      _stopSounds(uniqueId);
      _activeObservations[uniqueId] = false;
      _activeBirdSounds.remove(uniqueId);
    }
  }

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

  double _calculateVolume(double distance) {
    // Linear falloff with distance
    double volume = 1.0 - (distance / _maxAudioDistance);

    // Ensure volume is between 0.0 and 1.0
    if (volume < 0.0) volume = 0.0;
    if (volume > 1.0) volume = 1.0;

    return volume;
  }

  // Simplified method to start a sound
  Future<void> _startSound(String soundDirectory, String observationId, double pan,
      double volume) async {
    try {
      debugPrint(
          'Starting sound for observation $observationId from $soundDirectory');
      await _birdSoundPlayer.startSound(
          soundDirectory, observationId, pan, volume);
    } catch (e) {
      debugPrint('Error starting bird sounds: $e');
    }
  }

  // Update panning and volume for already playing sounds
  Future<void> _updatePanningAndVolume(
      String observationId, double pan, double volume) async {
    try {
      await _birdSoundPlayer.updatePanningAndVolume(observationId, pan, volume);
    } catch (e) {
      debugPrint('Error updating panning and volume: $e');
    }
  }

  // Stop sounds for an observation
  Future<void> _stopSounds(String observationId) async {
    try {
      await _birdSoundPlayer.stopSounds(observationId);
    } catch (e) {
      debugPrint('Error stopping bird sounds: $e');
    }
  }

  void dispose() {
    // Stop all active sounds
    _activeObservations.forEach((id, isActive) {
      if (isActive) {
        _birdSoundPlayer.stopSounds(id);
      }
    });
    _birdSoundPlayer.dispose();

    _activeObservations.clear();
    _activeBirdSounds.clear();
    _spatialGrid.clear();
    _observations.clear();
    _isInitialized = false;
  }
}