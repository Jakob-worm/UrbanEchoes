import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';  // For Position class
import 'package:urban_echoes/services/manegers/location_manager.dart';
import 'package:urban_echoes/services/sound/background_audio_service.dart';
import 'package:urban_echoes/services/sound/bird_sound_player.dart';
import 'package:urban_echoes/services/storage&database/azure_storage_service.dart';
import 'observation_service.dart';

class LocationService extends ChangeNotifier {
  // Services
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();
  final AzureStorageService _storageService = AzureStorageService();
  final BackgroundAudioService _backgroundAudioService = BackgroundAudioService();
  
  // New dependency - LocationManager
  late final LocationManager _locationManager;

  // State
  bool _isInitialized = false;
  List<Map<String, dynamic>> _observations = [];
  final Map<String, Map<String, dynamic>> _activeObservations = {};

  // Throttling state
  Timer? _batchUpdateTimer;
  
  // Settings
  bool _isAudioEnabled = true;

  // Configuration
  final double _maxRange = 50; // Reduced from 200m
  final int _batchUpdateMs = 500; // Batch UI updates

  // Debug
  final bool _debugMode = true;

  // Constructor - allow dependency injection for testing
  LocationService({LocationManager? locationManager}) {
    // Initialize location manager with position update callback
    _locationManager = locationManager ?? LocationManager(
      onPositionUpdate: (position) {
        // Schedule a batch update
        _batchUpdateTimer?.cancel();
        _batchUpdateTimer = Timer(Duration(milliseconds: _batchUpdateMs), () {
          _updateActiveObservations(position);
          notifyListeners();
        });
      }
    );
  }

  // Getters
  bool get isInitialized => _isInitialized;
  Position? get currentPosition => _locationManager.currentPosition;
  bool get isLocationTrackingEnabled => _locationManager.isLocationTrackingEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  List<Map<String, dynamic>> get activeObservations =>
      _activeObservations.values.toList();

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

    // Get API URL and debug mode from context before any async operations
    bool debugMode = false;
    try {
      debugMode = Provider.of<bool>(context, listen: false);
    } catch (e) {
      _log('Error getting debug mode: $e');
    }

    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    // Cache the scaffold messenger before any async operations
    ScaffoldMessengerState? scaffoldMessenger;
    try {
      scaffoldMessenger = ScaffoldMessenger.of(context);
    } catch (e) {
      _log('Error getting ScaffoldMessenger: $e');
    }

    try {
      // 1. Initialize Azure Storage Service
      await _storageService.initialize();

      // 2. Set up error handler for audio playback
      _soundPlayer.onBufferingTimeout = (String observationId) {
        _log('Audio buffering timeout for observation: $observationId');
      };

      // 3. Initialize the location manager
      bool locationInitialized = await _locationManager.initialize();
      if (!locationInitialized) {
        _log('Warning: Location manager initialization had issues');
      }

      // 4. Fetch observations
      _log('Fetching observations from $apiUrl');
      _observations =
          await ObservationService(apiUrl: apiUrl).fetchObservations();

      // 5. Filter valid observations (with sound directories)
      _observations = _observations.where((obs) {
        if (obs["sound_directory"] == null) {
          _log('Skipping observation with null sound directory: ${obs["id"]}');
          return false;
        }
        return true;
      }).toList();

      _log('Loaded ${_observations.length} valid observations');

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _log('Error initializing LocationService: $e');
      if (scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to initialize location services. Please check your settings.')),
        );
      }
    }
  }

  void _updateActiveObservations(Position position) {
    Set<String> observationsInRange = {};
    bool activeObservationsChanged = false;
    List<Map<String, dynamic>> newObservations = [];

    // Calculate which observations are in range
    for (var obs in _observations) {
      // Skip observations without required fields
      if (obs["latitude"] == null ||
          obs["longitude"] == null ||
          obs["sound_directory"] == null) {
        continue;
      }

      final String id = '${obs["id"]}';
      final double distance = _locationManager.calculateDistance(
          position.latitude,
          position.longitude, 
          obs["latitude"], 
          obs["longitude"]);

      // Calculate audio settings based on distance
      final double volume = _calculateVolume(distance);
      final double pan = _calculatePan(position.latitude, position.longitude,
          obs["latitude"], obs["longitude"]);

      // Check if in range
      if (distance <= _maxRange) {
        observationsInRange.add(id);

        // Add to active observations if not already active
        if (!_activeObservations.containsKey(id)) {
          _log(
              'Adding observation to active list: ${obs["bird_name"]} (ID: $id)');
          _activeObservations[id] = Map<String, dynamic>.from(obs);
          _activeObservations[id]!["pan"] = pan;
          _activeObservations[id]!["volume"] = volume;
          activeObservationsChanged = true;

          // Collect new observations to start sounds with delay
          if (_isAudioEnabled) {
            newObservations.add(
                {'observation': obs, 'id': id, 'pan': pan, 'volume': volume});
          }
        } else if (_isAudioEnabled) {
          // Only update sound if significant change
          final currentPan = _activeObservations[id]!["pan"] ?? 0.0;
          final currentVolume = _activeObservations[id]!["volume"] ?? 0.5;

          if ((pan - currentPan).abs() > 0.1 ||
              (volume - currentVolume).abs() > 0.1) {
            _soundPlayer.updatePanningAndVolume(id, pan, volume);

            // Update stored values
            _activeObservations[id]!["pan"] = pan;
            _activeObservations[id]!["volume"] = volume;
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
      _log(
          'Removing observation from active list: ${_activeObservations[id]?["bird_name"]} (ID: $id)');
      _activeObservations.remove(id);
      if (_isAudioEnabled) {
        _soundPlayer.stopSounds(id);
      }
      activeObservationsChanged = true;
    }

    // Start new sounds with randomized delays
    if (newObservations.isNotEmpty) {
      _startSoundsWithNaturalDelays(newObservations);
    }

    if (activeObservationsChanged) {
      _log('Active observations updated: ${_activeObservations.length} active');

      // Log active observations only in debug
      if (_debugMode) {
        _activeObservations.forEach((id, obs) {
          _log('Active: ${obs["bird_name"]} (ID: $id)');
        });
      }

      notifyListeners();
    }
  }

  // Start sounds with natural delays
  void _startSoundsWithNaturalDelays(List<Map<String, dynamic>> observations) {
    // Use a more natural pattern for bird sounds starting
    // Some birds start quickly, others wait a bit longer

    // Shuffle the observations for more randomness
    observations.shuffle();

    // Add a base delay to avoid all sounds starting immediately
    int baseDelay = 300 + Random().nextInt(700); // 300-1000ms base delay

    // Start each sound with an incremental delay
    int currentDelay = baseDelay;

    for (var obsData in observations) {
      // Apply some randomness to each increment
      int increment =
          500 + Random().nextInt(20000); // 500-20000ms between sounds

      // Start this sound after delay
      Future.delayed(Duration(milliseconds: currentDelay), () {
        // Check if observation is still active before starting
        if (_activeObservations.containsKey(obsData['id'])) {
          var obs = obsData['observation'];
          var pan = obsData['pan'];
          var volume = obsData['volume'];

          // Start with additional random volume variation
          // for more natural effect (80-100% of calculated volume)
          double naturalVolume = volume * (0.8 + Random().nextDouble() * 0.2);
          _startSound(obs, pan, naturalVolume);

          // Log with delay info
          _log(
              '🎵 Started sound for ${obs["bird_name"]} with ${currentDelay}ms delay');
        }
      });

      // Increase delay for next sound
      currentDelay += increment;
    }
  }

  double _calculateVolume(double distance) {
    // Steeper, more dramatic falloff
    const double minVolume = 0.05; // Lower minimum for more contrast
    const double maxVolume = 0.9; // Higher maximum for nearby sounds

    // Normalized distance (0-1)
    final normalizedDistance = (distance / _maxRange).clamp(0.0, 1.0);

    // Cubic falloff (steeper than quadratic)
    final falloff =
        1.0 - (normalizedDistance * normalizedDistance * normalizedDistance);

    // Add a "close proximity boost" for very nearby sounds
    double volumeBoost = 0.0;
    if (distance < 5.0) {
      // Extra boost when very close (within 5 meters)
      volumeBoost = 0.1 * (1.0 - (distance / 5.0));
    }

    final volume = minVolume + falloff * (maxVolume - minVolume) + volumeBoost;

    return volume.clamp(minVolume, maxVolume);
  }

  double _calculatePan(
      double userLat, double userLng, double soundLat, double soundLng) {
    // Calculate distance
    double distance = _locationManager.calculateDistance(
        userLat, userLng, soundLat, soundLng);

    // Calculate bearing to sound
    double bearing = _locationManager.calculateBearing(
        userLat, userLng, soundLat, soundLng);

    // Normalize bearing to -180 to 180
    if (bearing > 180) bearing -= 360;
    if (bearing < -180) bearing += 360;

    // Calculate base pan value
    double basePan = bearing / 90.0;

    // Distance factor (closer = more pronounced panning)
    double distanceFactor = 1.0 - (distance / _maxRange).clamp(0.0, 0.8);

    // Apply distance factor to make nearby sounds have stronger panning
    double pan = basePan * (0.7 + (distanceFactor * 0.3));

    // Allow full stereo range
    return pan.clamp(-1.0, 1.0);
  }

  // Start sound for an observation
  Future<void> _startSound(
      Map<String, dynamic> observation, double pan, double volume) async {
    final String id = '${observation["id"]}';
    final String? directory = observation["sound_directory"];

    if (directory == null || directory.isEmpty) {
      _log(
          'Cannot start sound: directory is null or empty for ${observation["bird_name"]}');
      return;
    }

    try {
      _soundPlayer.startSound(directory, id, pan, volume);

      // Store pan and volume for change detection
      _activeObservations[id]!["pan"] = pan;
      _activeObservations[id]!["volume"] = volume;

      _log(
          'Started sound for ${observation["bird_name"]} with pan=$pan, volume=$volume');
    } catch (e) {
      _log('Error starting sound: $e');
    }
  }

  // Toggle location tracking
  void toggleLocationTracking(bool enabled) async {
    if (_locationManager.isLocationTrackingEnabled == enabled) {
      return;
    }

    if (enabled) {
      // Start background service first and ensure it's fully initialized
      await _backgroundAudioService.startService();
      await Future.delayed(Duration(milliseconds: 500)); // Give audio service time to initialize

      // Then start location tracking
      await _locationManager.setLocationTrackingEnabled(true);
    } else {
      // Stop all sounds
      for (var id in _activeObservations.keys) {
        _soundPlayer.stopSounds(id);
      }
      _activeObservations.clear();

      // First stop location tracking
      await _locationManager.setLocationTrackingEnabled(false);
      
      // Then stop background service
      await _backgroundAudioService.stopService();

      // Cancel any pending updates
      _batchUpdateTimer?.cancel();
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
    } else if (_locationManager.currentPosition != null) {
      // Re-add sound for active observations (with throttling)
      int delay = 0;
      for (var obs in _activeObservations.values) {
        final String id = '${obs["id"]}';
        final double distance = _locationManager.calculateDistance(
            _locationManager.currentPosition!.latitude,
            _locationManager.currentPosition!.longitude,
            obs["latitude"],
            obs["longitude"]);

        final double volume = _calculateVolume(distance);
        final double pan = _calculatePan(
            _locationManager.currentPosition!.latitude,
            _locationManager.currentPosition!.longitude, 
            obs["latitude"], 
            obs["longitude"]);

        // Stagger sound starts to avoid audio overload
        delay += 500; // Increased from 300ms
        Future.delayed(Duration(milliseconds: delay), () {
          if (_isAudioEnabled && _activeObservations.containsKey(id)) {
            _startSound(obs, pan, volume);
          }
        });
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _batchUpdateTimer?.cancel();
    _locationManager.dispose();
    _soundPlayer.dispose();
    _activeObservations.clear();
    super.dispose();
  }
}