import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'ObservationService.dart';

class LocationService extends ChangeNotifier {
  // Services
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();
  final AzureStorageService _storageService = AzureStorageService();
  final Set<String> _preloadedAudioFolders = {};
  
  // State
  bool _isInitialized = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _observations = [];
  final Map<String, Map<String, dynamic>> _activeObservations = {};
  
  // Audio file cache
  final Map<String, List<String>> _audioFileCache = {};
  
  // Settings
  bool _isLocationTrackingEnabled = true;
  bool _isAudioEnabled = true;
  final double _maxRange = 200.0; // meters
  
  // Debug
  final bool _debugMode = true;
  
  // Getters
  bool get isInitialized => _isInitialized;
  Position? get currentPosition => _currentPosition;
  bool get isLocationTrackingEnabled => _isLocationTrackingEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  List<Map<String, dynamic>> get activeObservations => _activeObservations.values.toList();
  
  void _log(String message) {
    if (_debugMode) {
      debugPrint('[LocationService] $message');
    }
  }
  
  // Initialize the service
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      return;
    }
    
    // Initialize Azure Storage Service
    await _storageService.initialize();
    
    // Set up buffering timeout handler
    _soundPlayer.onBufferingTimeout = (String observationId) {
      _log('Audio buffering timeout for observation: $observationId');
    };
    
    // Get API URL from context
    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';
    
    // Cache the scaffold messenger
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // 1. Request location permission
      bool permissionGranted = await _requestLocationPermission();
      if (!permissionGranted) {
        throw Exception('Location permission denied');
      }
      
      // 2. Fetch observations
      _observations = await ObservationService(apiUrl: apiUrl).fetchObservations();
      
      // 3. Filter valid observations (with sound directories)
      _observations = _observations.where((obs) {
        if (obs["sound_directory"] == null) {
          _log('Skipping observation with null sound directory: ${obs["id"]}');
          return false;
        }
        return true;
      }).toList();
      
      _log('Loaded ${_observations.length} valid observations');
      
      // 4. Start location tracking
      _startLocationTracking();
      
      _isInitialized = true;
      notifyListeners();
      
    } catch (e) {
      _log('Error initializing LocationService: $e');
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to initialize location services. Please check your settings.')),
        );
      }
    }
  }
  
  // Request location permission
  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
  
  // Start tracking location
  void _startLocationTracking() {
    if (!_isLocationTrackingEnabled) {
      return;
    }
    
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
      timeLimit: Duration(seconds: 5),
    );
    
    // Listen for position updates
    _geolocatorPlatform
        .getPositionStream(locationSettings: locationSettings)
        .listen(_handlePositionUpdate);
    
    // Get initial position
    _geolocatorPlatform.getCurrentPosition().then(_handlePositionUpdate);
    
    _log('Started location tracking');
  }
  
  // Call this in _handlePositionUpdate
void _handlePositionUpdate(Position position) {
  _currentPosition = position;
  _log('Position update: ${position.latitude}, ${position.longitude}');
  
  if (_isLocationTrackingEnabled) {
    _updateActiveObservations(position);
    _prefetchNearbyAudio(position); // Add this line
  }
  
  notifyListeners();
}
  
  // Update which observations are active based on proximity
  void _updateActiveObservations(Position position) {
    // Track which observations are in range
    Set<String> observationsInRange = {};
    bool activeObservationsChanged = false;
    int inRangeCount = 0;
    
    // Calculate which observations are in range
    for (var obs in _observations) {
      // Skip observations without required fields
      if (obs["latitude"] == null || obs["longitude"] == null || obs["sound_directory"] == null) {
        continue;
      }
      
      final String id = '${obs["id"]}';
      final double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        obs["latitude"], obs["longitude"]
      );
      
      // Calculate audio settings based on distance
      final double volume = _calculateVolume(distance);
      final double pan = _calculatePan(
        position.latitude, position.longitude,
        obs["latitude"], obs["longitude"]
      );
      
      // Check if in range
      if (distance <= _maxRange) {
        inRangeCount++;
        observationsInRange.add(id);
        
        // Add to active observations if not already active
        if (!_activeObservations.containsKey(id)) {
          _log('Adding observation to active list: ${obs["bird_name"]} (ID: $id)');
          _activeObservations[id] = Map<String, dynamic>.from(obs); // Create a copy
          activeObservationsChanged = true;
          
          // Add to audio manager if audio enabled
          if (_isAudioEnabled) {
            _startSound(obs, pan, volume);
          }
        } else if (_isAudioEnabled) {
          // Update existing sound's volume and panning
          _soundPlayer.updatePanningAndVolume(id, pan, volume);
        }
      }
    }
    
    // Remove observations that are no longer in range
    List<String> toRemove = [];
    _activeObservations.forEach((id, obs) {
      if (!observationsInRange.contains(id)) {
        toRemove.add(id);
      }
    });
    
    for (String id in toRemove) {
      _log('Removing observation from active list: ${_activeObservations[id]?["bird_name"]} (ID: $id)');
      _activeObservations.remove(id);
      if (_isAudioEnabled) {
        _soundPlayer.stopSounds(id);
      }
      activeObservationsChanged = true;
    }
    
    if (activeObservationsChanged) {
      _log('Active observations updated: ${_activeObservations.length} active (from $inRangeCount in range)');
      
      // Debug log all active observations
      _activeObservations.forEach((id, obs) {
        _log('Active: ${obs["bird_name"]} (ID: $id)');
      });
      
      notifyListeners();
    }
  }
  
  // Calculate volume based on distance
  double _calculateVolume(double distance) {
    // Linear falloff with minimum volume
    const double minVolume = 0.05; // Minimum volume at max distance
    const double maxVolume = 1.0;  // Maximum volume at center
    
    double falloff = 1.0 - (distance / _maxRange);
    double volume = minVolume + falloff * (maxVolume - minVolume);
    return volume.clamp(minVolume, maxVolume);
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
    const double pi = 3.1415926535897932;
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
  
  // Get audio files for a directory (with caching)
  Future<List<String>> _getAudioFiles(String directory) async {
    // Return cached results if available
    if (_audioFileCache.containsKey(directory)) {
      return _audioFileCache[directory]!;
    }
    
    try {
      // Fetch files from Azure Storage
      _log('Fetching audio files for: $directory');
      final files = await _storageService.listFiles(directory);
      
      // Cache the results
      _audioFileCache[directory] = files;
      _log('Cached ${files.length} audio files for $directory');
      
      return files;
    } catch (e) {
      _log('Error getting audio files: $e');
      return [];
    }
  }

 Future<void> _prefetchNearbyAudio(Position position) async {
  // Find observations just outside the active range
  final prefetchRange = _maxRange * 1.5;  // 50% further than activation range
  
  for (var obs in _observations) {
    final String? directory = obs["sound_directory"];
    if (directory == null || _preloadedAudioFolders.contains(directory)) {
      continue;
    }
    
    if (obs["latitude"] != null && obs["longitude"] != null) {
      final double distance = Geolocator.distanceBetween(
        position.latitude, position.longitude,
        obs["latitude"], obs["longitude"]
      );
      
      if (distance <= prefetchRange) {
        // Pre-fetch in background
        _log('Pre-fetching audio for ${obs["bird_name"]}');
        _preloadedAudioFolders.add(directory);
        
        _getAudioFiles(directory).then((_) {
          _log('Successfully pre-fetched ${obs["bird_name"]} audio');
        });
      }
    }
  }
}

  
  // Start sound for an observation
  Future<void> _startSound(Map<String, dynamic> observation, double pan, double volume) async {
    final String id = '${observation["id"]}';
    final String? directory = observation["sound_directory"];
    
    if (directory == null || directory.isEmpty) {
      _log('Cannot start sound: directory is null or empty for ${observation["bird_name"]}');
      return;
    }
    
    try {
      _soundPlayer.startSound(directory, id, pan, volume);
      _log('Started sound for ${observation["bird_name"]} with pan=$pan, volume=$volume');
    } catch (e) {
      _log('Error starting sound: $e');
    }
  }
  
  // Toggle location tracking
  void toggleLocationTracking(bool enabled) {
    if (_isLocationTrackingEnabled == enabled) {
      return;
    }
    
    _isLocationTrackingEnabled = enabled;
    
    if (enabled) {
      _startLocationTracking();
    } else {
      // Stop all sounds
      for (var id in _activeObservations.keys) {
        _soundPlayer.stopSounds(id);
      }
      _activeObservations.clear();
    }
    
    notifyListeners();
  }
  
  // Toggle audio
  void toggleAudio(bool enabled) {
    if (_isAudioEnabled == enabled) {
      return;
    }
    
    _isAudioEnabled = enabled;
    
    if (!enabled) {
      // Stop all active sounds
      for (var id in _activeObservations.keys) {
        _soundPlayer.stopSounds(id);
      }
    } else if (_currentPosition != null) {
      // Re-add all active sound sources
      for (var obs in _activeObservations.values) {
        final String id = '${obs["id"]}';
        final double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude, _currentPosition!.longitude,
          obs["latitude"], obs["longitude"]
        );
        
        final double volume = _calculateVolume(distance);
        final double pan = _calculatePan(
          _currentPosition!.latitude, _currentPosition!.longitude,
          obs["latitude"], obs["longitude"]
        );
        
        _startSound(obs, pan, volume);
      }
    }
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _soundPlayer.dispose();
    _activeObservations.clear();
    super.dispose();
  }
}