import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/consants.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'ObservationService.dart';

class LocationService extends ChangeNotifier {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final BirdSoundPlayer _birdSoundPlayer = BirdSoundPlayer();
  List<Map<String, dynamic>> _observations = [];
  bool _isInitialized = false;
  Position? _lastKnownPosition;
  bool _isLocationTrackingEnabled = true;

  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );

  // Active bird sounds that widgets can observe
  final Map<String, Map<String, dynamic>> _activeBirdSounds = {};
  final Map<String, bool> _activeObservations = {};
  final Map<String, List<Map<String, dynamic>>> _spatialGrid = {};
  final int _gridSize = AppConstants.gridSize;
  
  // Audio spatial parameters
  final double _maxAudioDistance = AppConstants.defaultPointRadius;
  final double _falloffExponent = 2.0; // Quadratic falloff (2.0) sounds more natural than linear (1.0)
  final double _minVolume = 0.05; // Minimum volume at max distance
  final double _maxVolume = 1.0; // Maximum volume at center
  
  // Volume debug info
  final Map<String, double> _lastCalculatedVolumes = {};

  // Getters
  List<Map<String, dynamic>> getActiveBirdSounds() {
    return _activeBirdSounds.values.toList();
  }

  bool get isInitialized => _isInitialized;
  bool get isLocationTrackingEnabled => _isLocationTrackingEnabled;
  Position? get lastKnownPosition => _lastKnownPosition;
  
  // Get volume debug info for a specific observation
  Map<String, dynamic> getVolumeInfo(String observationId) {
    if (!_lastCalculatedVolumes.containsKey(observationId)) {
      return {"volume": 0.0, "distance": double.infinity};
    }
    
    return {
      "volume": _lastCalculatedVolumes[observationId],
      "distance": _lastCalculatedDistances[observationId],
      "maxDistance": _maxAudioDistance,
    };
  }
  
  // Map to track distances for debugging
  final Map<String, double> _lastCalculatedDistances = {};

  // Toggle location tracking
  void toggleLocationTracking(bool enabled) {
    if (_isLocationTrackingEnabled == enabled) return;
    
    _isLocationTrackingEnabled = enabled;
    if (enabled) {
      _startTrackingLocation();
    } else {
      _stopAllSounds();
    }
    notifyListeners();
  }

  // Stop all active sounds
  void _stopAllSounds() {
    List<String> activeIds = List<String>.from(_activeObservations.keys.where((id) => _activeObservations[id] == true));
    for (String id in activeIds) {
      _stopSounds(id);
      _activeObservations[id] = false;
      _activeBirdSounds.remove(id);
    }
    notifyListeners();
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
    
    // Extract what we need from context before async operations
    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';
    
    // Store the messenger for later use
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      _observations =
          await ObservationService(apiUrl: apiUrl).fetchObservations();

      // Initialize active observations map
      for (var obs in _observations) {
        String uniqueId = "${obs["latitude"]}_${obs["longitude"]}_${obs["sound_directory"]}";
        obs["uniqueId"] = uniqueId;
        _activeObservations[uniqueId] = false;
      }

      _buildSpatialGrid();
      await _requestLocationPermission();
      _startTrackingLocation();
      _isInitialized = true;
      notifyListeners();

      debugPrint(
          'LocationService initialized with ${_observations.length} observations');
    } catch (e) {
      debugPrint('Failed to initialize LocationService: $e');
      
      // Use the messenger we cached earlier
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to load bird observations. Please check your internet connection.')),
        );
      }
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

  Future<Position> _getPosition() async {
    if (_lastKnownPosition != null) {
      return _lastKnownPosition!;
    }
    return await _geolocatorPlatform.getCurrentPosition();
  }

  void _startTrackingLocation() {
    if (!_isLocationTrackingEnabled) {
      debugPrint('Location tracking is disabled, not starting');
      return;
    }

    // First cancel any previous streams
    _geolocatorPlatform.getPositionStream().listen(null).cancel();

    // Use a less frequent update interval to save battery
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update when user moves 5 meters (less frequent)
      timeLimit: Duration(seconds: 5), // Less frequent updates (5 seconds)
    );

    _geolocatorPlatform
        .getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      // Cache the position
      _lastKnownPosition = position;
      _processLocationUpdate(position);
    });

    // Get initial position
    _geolocatorPlatform.getCurrentPosition().then((position) {
      _lastKnownPosition = position;
      _processLocationUpdate(position);
    });

    debugPrint('Started location tracking with optimized settings');
  }

  void _processLocationUpdate(Position position) {
    if (!_isLocationTrackingEnabled) {
      debugPrint('Location tracking is disabled, ignoring update');
      return;
    }

    // Update the last known position
    _lastKnownPosition = position;
    
    // Debug position updates
    debugPrint('Position update: ${position.latitude}, ${position.longitude}');

    // Process all nearby observations
    _checkProximityToPoints(position);
    
    // Notify listeners about position update
    notifyListeners();
  }

  void _checkProximityToPoints(Position position) {
    debugPrint('Checking proximity to observation points...');

    // Get all potentially relevant grid cells
    List<String> cells =
        _getNeighboringCells(position.latitude, position.longitude);

    // Track which observations should be active
    Set<String> observationsInRange = {};
    bool activeSoundsChanged = false;

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

    // Process all observations in range
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
      final double volume = _calculateVolume(distance, uniqueId);
      
      // Store distance for debugging
      _lastCalculatedDistances[uniqueId] = distance;

      if (!_activeObservations.containsKey(uniqueId) || !_activeObservations[uniqueId]!) {
        // Start playing sound (for this observation)
        debugPrint(
            'Starting sound for observation $uniqueId with pan=$pan, volume=$volume');
        _startSound(obs["sound_directory"], uniqueId, pan, volume);
        _activeObservations[uniqueId] = true;
        _activeBirdSounds[uniqueId] = obs;
        activeSoundsChanged = true;
      } else {
        // Update existing sound parameters
        debugPrint(
            'Updating sound for observation $uniqueId with pan=$pan, volume=$volume');
        _updatePanningAndVolume(uniqueId, pan, volume);
      }
    }

    // Stop sounds for observations that are now out of range
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
      _lastCalculatedVolumes.remove(uniqueId);
      _lastCalculatedDistances.remove(uniqueId);
      activeSoundsChanged = true;
    }
    
    // Only notify listeners if the active sounds changed
    if (activeSoundsChanged) {
      notifyListeners();
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

  // Improved volume calculation with nonlinear falloff
  double _calculateVolume(double distance, String observationId) {
    // Normalize distance to 0-1 range
    double normalizedDistance = distance / _maxAudioDistance;
    
    // Apply non-linear falloff (quadratic)
    // The formula is: volume = maxVolume * (1 - (distance/maxDistance)^exponent) + minVolume
    // This gives a more natural falloff curve
    double volumeRange = _maxVolume - _minVolume;
    double volumeFactor = pow(1.0 - normalizedDistance.clamp(0.0, 1.0), _falloffExponent).toDouble();
    double volume = (_maxVolume - volumeRange) + (volumeRange * volumeFactor);
    
    // Ensure volume is within bounds
    volume = volume.clamp(_minVolume, _maxVolume);
    
    // Store for debugging
    _lastCalculatedVolumes[observationId] = volume;
    
    debugPrint('🔊 Volume calculation for $observationId: distance=$distance, normalized=$normalizedDistance, volume=$volume');
    
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
      debugPrint('Error updating panning/volume: $e');
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

 void handleBufferingTimeout(String observationId) {
  // If we get a buffering timeout for an observation, try another sound
  if (_activeObservations.containsKey(observationId) && _activeObservations[observationId]!) {
    final observation = _activeBirdSounds[observationId];
    if (observation != null) {
      try {
        // Use cached position instead of getting a new one
        _getPosition().then((position) {
          if (_isLocationTrackingEnabled && _activeObservations[observationId]!) {
            // Calculate new panning and volume
            final double pan = _calculatePanning(position.latitude,
                position.longitude, observation["latitude"], observation["longitude"]);
            
            final distance = Distance().as(
              LengthUnit.Meter,
              LatLng(position.latitude, position.longitude),
              LatLng(observation["latitude"], observation["longitude"]),
            );
            final double volume = _calculateVolume(distance, observationId);
            
            // Stop current sound and start a new one
            _birdSoundPlayer.stopSounds(observationId).then((_) {
              if (_isLocationTrackingEnabled && _activeObservations[observationId]!) {
                _startSound(observation["sound_directory"], observationId, pan, volume);
              }
            });
          }
        });
      } catch (e) {
        debugPrint('Error handling buffering timeout: $e');
      }
    }
  }
 }

  @override
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
    _lastCalculatedVolumes.clear();
    _lastCalculatedDistances.clear();
    _isInitialized = false;
    super.dispose();
  }
}