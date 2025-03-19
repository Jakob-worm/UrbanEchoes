import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/SpatialAudioManager.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';
import 'ObservationService.dart';

class LocationManager extends ChangeNotifier {
  // Services
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final SpatialAudioManager _audioManager = SpatialAudioManager();
  final AzureStorageService _storageService = AzureStorageService();
  
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
      debugPrint('[LocationManager] $message');
    }
  }
  
  // Initialize the service
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      return;
    }
    
    // Initialize Azure Storage Service
    await _storageService.initialize();
    
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
      _log('Error initializing LocationManager: $e');
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
  
  // Handle position update
  void _handlePositionUpdate(Position position) {
    _currentPosition = position;
    _log('Position update: ${position.latitude}, ${position.longitude}');
    
    if (_isLocationTrackingEnabled) {
      _updateActiveObservations(position);
      
      if (_isAudioEnabled) {
        _audioManager.updateUserPosition(position);
      }
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
            _addSoundSource(obs);
          }
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
        _audioManager.removeSoundSource(id);
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
  
  // Add sound source to audio manager
  Future<void> _addSoundSource(Map<String, dynamic> observation) async {
    final String id = '${observation["id"]}';
    final String? directory = observation["sound_directory"];
    
    if (directory == null || directory.isEmpty) {
      _log('Cannot add sound source: directory is null or empty for ${observation["bird_name"]}');
      return;
    }
    
    try {
      // Get actual audio files from the directory
      List<String> audioFiles = await _getAudioFiles(directory);
      
      if (audioFiles.isNotEmpty) {
        _audioManager.addSoundSource(
          id,
          observation["latitude"],
          observation["longitude"],
          audioFiles
        );
        _log('Added sound source for ${observation["bird_name"]} with ${audioFiles.length} audio files');
      } else {
        _log('No audio files found for ${observation["bird_name"]} in $directory');
      }
    } catch (e) {
      _log('Error adding sound source: $e');
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
      _audioManager.stopAllSounds();
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
      _audioManager.stopAllSounds();
    } else if (_currentPosition != null) {
      // Re-add all active sound sources
      for (var obs in _activeObservations.values) {
        _addSoundSource(obs);
      }
      
      // Update with current position
      if (_currentPosition != null) {
        _audioManager.updateUserPosition(_currentPosition!);
      }
    }
    
    notifyListeners();
  }
  
  @override
  void dispose() {
    _audioManager.dispose();
    _activeObservations.clear();
    super.dispose();
  }
}