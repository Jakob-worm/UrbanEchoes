import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/background_audio_service.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'package:urban_echoes/services/storage&database/AzureStorageService.dart';
import 'ObservationService.dart';

class LocationService extends ChangeNotifier {
  // Services
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();
  final AzureStorageService _storageService = AzureStorageService();
  final BackgroundAudioService _backgroundAudioService =
      BackgroundAudioService();

  // State
  bool _isInitialized = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _observations = [];
  final Map<String, Map<String, dynamic>> _activeObservations = {};

  // Throttling state
  DateTime _lastPositionUpdate = DateTime.now();
  Position? _lastProcessedPosition;
  Timer? _batchUpdateTimer;
  Timer? _serviceWatchdog;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Emergency fallback
  Timer? _locationFallbackTimer;
  int _positionUpdateFailures = 0;
  final int _maxFailuresBeforeFallback = 3;

  // Settings
  bool _isLocationTrackingEnabled = true;
  bool _isAudioEnabled = true;

  // Configuration - more conservative defaults
  final double _maxRange = 50; // Reduced from 200m
  final double _distanceFilter = 15.0; // Increased from 5m
  final int _updateIntervalSeconds =
      15; // Increased from 10s to 15s to reduce timeouts
  final int _batchUpdateMs = 500; // Batch UI updates

  // Debug
  final bool _debugMode = true;

  // Getters
  bool get isInitialized => _isInitialized;
  Position? get currentPosition => _currentPosition;
  bool get isLocationTrackingEnabled => _isLocationTrackingEnabled;
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

    // Initialize Azure Storage Service
    await _storageService.initialize();

    // Set up error handler for audio playback
    _soundPlayer.onBufferingTimeout = (String observationId) {
      _log('Audio buffering timeout for observation: $observationId');
    };

    // Get API URL from context
    bool debugMode = false;
    try {
      debugMode = Provider.of<bool>(context, listen: false);
    } catch (e) {
      _log('Error getting debug mode: $e');
    }

    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    // Cache the scaffold messenger - Fixed type issue
    ScaffoldMessengerState? scaffoldMessenger;
    try {
      if (context.mounted) {
        scaffoldMessenger = ScaffoldMessenger.of(context);
      }
    } catch (e) {
      _log('Error getting ScaffoldMessenger: $e');
    }

    try {
      // 1. Request location permission
      bool permissionGranted = await _requestLocationPermission();
      if (!permissionGranted) {
        throw Exception('Location permission denied');
      }

      // 2. Fetch observations
      _log('Fetching observations from $apiUrl');
      _observations =
          await ObservationService(apiUrl: apiUrl).fetchObservations();

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
      await _startLocationTracking();

      // 5. Start watchdog timer to recover from potential issues
      _startWatchdog();

      // 6. Start fallback timer for location updates
      _startLocationFallbackTimer();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _log('Error initializing LocationService: $e');
      if (scaffoldMessenger != null && context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to initialize location services. Please check your settings.')),
        );
      }

      // Even with an error, try to start location tracking
      _startLocationTracking();
    }
  }

  Future<bool> _requestLocationPermission() async {
    try {
      // First check the current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // If denied, request permission
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      // If denied forever, return false
      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      // Now try to request "always" permission if not already granted
      if (permission == LocationPermission.whileInUse) {
        _log('We have foreground permission, but not background');
        // You could show a dialog here explaining why you need background
        // and then request the permission again

        // Try requesting again (might show system dialog for background)
        permission = await Geolocator.requestPermission();
      }

      // Return true even if we only have whileInUse permission
      // The background audio service will help keep things running
      return true;
    } catch (e) {
      _log('Error requesting location permission: $e');
      // Return true to allow the app to continue
      return true;
    }
  }

  // Fallback timer for location updates
  void _startLocationFallbackTimer() {
    _locationFallbackTimer?.cancel();
    _locationFallbackTimer = Timer.periodic(Duration(seconds: 10), (_) {
      // Check if we need fallback position data
      if (_positionUpdateFailures >= _maxFailuresBeforeFallback ||
          _currentPosition == null ||
          DateTime.now().difference(_lastPositionUpdate).inSeconds > 45) {
        _log('⚠️ Using fallback location update mechanism');

        // Try to get a current position directly
        _geolocatorPlatform
            .getCurrentPosition(
                locationSettings: LocationSettings(
              accuracy:
                  LocationAccuracy.reduced, // Use reduced accuracy for fallback
              timeLimit: Duration(seconds: 5),
            ))
            .timeout(Duration(seconds: 5))
            .then((position) {
          _positionUpdateFailures = 0; // Reset failure counter on success
          _handlePositionUpdate(position);
        }).catchError((e) {
          _log('⚠️ Fallback location update failed: $e');

          // Try last known position
          _geolocatorPlatform.getLastKnownPosition().then((position) {
            if (position != null) {
              _handlePositionUpdate(position);
            } else if (_currentPosition == null) {
              // If all else fails, use a hardcoded position for testing
              _log('⚠️ Using hardcoded position as last resort');
              final fallbackPosition = Position(
                latitude: 56.1701317,
                longitude: 10.1864594,
                timestamp: DateTime.now(),
                accuracy: 10,
                altitude: 0,
                heading: 0,
                headingAccuracy: 1,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
              );
              _handlePositionUpdate(fallbackPosition);
            }
          }).catchError((e) {
            _log('⚠️ Could not get last known position: $e');
          });
        });

        // Also restart the location tracking if it seems stuck
        if (DateTime.now().difference(_lastPositionUpdate).inSeconds > 60) {
          _restartLocationTracking();
        }
      }
    });
  }

  // In your LocationService class, update _startLocationTracking

Future<void> _startLocationTracking() async {
  // First, make sure we're not already tracking
  await _cleanupLocationResources();

  if (!_isLocationTrackingEnabled) {
    return;
  }

  // Wait a moment to ensure clean state
  await Future.delayed(Duration(milliseconds: 100));

  // Use settings optimized for background operation
  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium, 
    distanceFilter: _distanceFilter.toInt(),
    // Remove timeLimit to prevent cancellation in background
    // timeLimit: Duration(seconds: _updateIntervalSeconds),
  );

  try {
    // Listen for position updates with error handling
    _positionStreamSubscription = _geolocatorPlatform
        .getPositionStream(locationSettings: locationSettings)
        .handleError((error) {
      _log('! Position stream error: $error');
      _positionUpdateFailures++;
      _restartLocationTracking();
      return;
    }).listen(
      (position) {
        _positionUpdateFailures = 0; // Reset on successful update
        _handlePositionUpdate(position);
      },
      onError: (e) {
        _log('! Position update error: $e');
        _positionUpdateFailures++;
        _restartLocationTracking();
      },
      cancelOnError: false,
    );

    // Get initial position with timeout
    _geolocatorPlatform
        .getCurrentPosition(
            locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ))
        .timeout(Duration(seconds: 8))
        .then((position) {
      _positionUpdateFailures = 0; // Reset on success
      _handlePositionUpdate(position);
    }).catchError((e) {
      _log('! Initial position error: $e');
      _positionUpdateFailures++;
      // We'll rely on the fallback mechanism to provide a position
    });

    _log('Started location tracking with distanceFilter=${_distanceFilter}m');
  } catch (e) {
    _log('! Error setting up location tracking: $e');
    _positionUpdateFailures++;
  }
}

  // Clean up location resources before restarting
  Future<void> _cleanupLocationResources() async {
    try {
      // Cancel existing subscription if any
      if (_positionStreamSubscription != null) {
        await _positionStreamSubscription!.cancel();
        _positionStreamSubscription = null;
      }
    } catch (e) {
      _log('! Error cleaning up location resources: $e');
    }
  }

  // Restart location tracking if it fails
  void _restartLocationTracking() {
    _log('🔄 Restarting location tracking after error');
    Future.delayed(Duration(seconds: 3), () {
      _startLocationTracking();
    });
  }

  // Start a watchdog timer to ensure the service keeps working
  void _startWatchdog() {
    _serviceWatchdog?.cancel();
    _serviceWatchdog = Timer.periodic(Duration(minutes: 2), (_) {
      _log('Watchdog check');

      // Check if location updates have stalled
      if (_currentPosition != null &&
          DateTime.now().difference(_lastPositionUpdate).inMinutes >= 3) {
        _log('⚠️ Location updates have stalled, restarting tracking');
        _restartLocationTracking();
      }

      // Force update active observations if we haven't in a while
      if (_currentPosition != null &&
          _activeObservations.isNotEmpty &&
          DateTime.now().difference(_lastPositionUpdate).inMinutes >= 1) {
        _updateActiveObservations(_currentPosition!);
      }
    });
  }

  // Handle position updates with throttling
  void _handlePositionUpdate(Position position) {
    _currentPosition = position;

    // Skip processing if not enough time has elapsed
    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate).inMilliseconds < 500) {
      return;
    }
    _lastPositionUpdate = now;

    _log('Position update: ${position.latitude}, ${position.longitude}');

    // Skip if position hasn't changed significantly and we've processed before
    if (_lastProcessedPosition != null) {
      final distance = Geolocator.distanceBetween(
          _lastProcessedPosition!.latitude,
          _lastProcessedPosition!.longitude,
          position.latitude,
          position.longitude);

      if (distance < _distanceFilter / 2) {
        _log(
            'Skipping position update (moved only ${distance.toStringAsFixed(1)}m)');
        return;
      }
    }

    _lastProcessedPosition = position;

    if (_isLocationTrackingEnabled) {
      // Cancel any pending updates
      _batchUpdateTimer?.cancel();

      // Schedule a batch update
      _batchUpdateTimer = Timer(Duration(milliseconds: _batchUpdateMs), () {
        _updateActiveObservations(position);
        notifyListeners();
      });
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
      final double distance = Geolocator.distanceBetween(position.latitude,
          position.longitude, obs["latitude"], obs["longitude"]);

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

// Add this new method to start sounds with natural delays
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
          var id = obsData['id'];
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
    double distance =
        Geolocator.distanceBetween(userLat, userLng, soundLat, soundLng);

    // Calculate bearing to sound
    double bearing = _calculateBearing(userLat, userLng, soundLat, soundLng);

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

  // In your LocationService
void toggleLocationTracking(bool enabled) async {
  if (_isLocationTrackingEnabled == enabled) {
    return;
  }

  _isLocationTrackingEnabled = enabled;

  if (enabled) {
    // Start background service first and ensure it's fully initialized
    await _backgroundAudioService.startService();
    await Future.delayed(Duration(milliseconds: 500)); // Give audio service time to initialize

    // Then start location tracking
    _startLocationTracking();
  } else {
    // Stop all sounds
    for (var id in _activeObservations.keys) {
      _soundPlayer.stopSounds(id);
    }
    _activeObservations.clear();

    // First stop location tracking
    await _cleanupLocationResources();
    
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
    } else if (_currentPosition != null) {
      // Re-add sound for active observations (with throttling)
      int delay = 0;
      for (var obs in _activeObservations.values) {
        final String id = '${obs["id"]}';
        final double distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            obs["latitude"],
            obs["longitude"]);

        final double volume = _calculateVolume(distance);
        final double pan = _calculatePan(_currentPosition!.latitude,
            _currentPosition!.longitude, obs["latitude"], obs["longitude"]);

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
    _serviceWatchdog?.cancel();
    _locationFallbackTimer?.cancel();
    _cleanupLocationResources();
    _soundPlayer.dispose();
    _activeObservations.clear();
    super.dispose();
  }
}
