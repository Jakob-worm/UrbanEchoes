import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urban_echoes/services/manegers/location_manager.dart';
import 'package:urban_echoes/services/observation/observation_service.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/sound/background_audio_service.dart';
import 'package:urban_echoes/services/sound/bird_sound_player.dart';
import 'package:urban_echoes/services/storage&database/azure_storage_service.dart';
import 'package:urban_echoes/services/season_service.dart';
import 'package:urban_echoes/models/season.dart';

/// A service that manages location-based bird sound observations.
///
/// This service handles:
/// - Location tracking
/// - Fetching and filtering observations based on season and location
/// - Playing bird sounds based on proximity to observation points
/// - Managing audio settings and playback
class LocationService extends ChangeNotifier {
  /// Constructor with optional dependency injection for testing
  LocationService({
    BirdSoundPlayer? soundPlayer,
    AzureStorageService? storageService,
    BackgroundAudioService? backgroundAudioService,
    SeasonService? seasonService,
    LocationManager? locationManager,
  })  : _soundPlayer = soundPlayer ?? BirdSoundPlayer(),
        _storageService = storageService ?? AzureStorageService(),
        _backgroundAudioService =
            backgroundAudioService ?? BackgroundAudioService(),
        _seasonService = seasonService ?? SeasonService() {
    // Initialize location manager with position update callback
    _locationManager = locationManager ??
        LocationManager(onPositionUpdate: _handlePositionUpdate);

    // Set up listener for season changes
    _seasonService.addListener(_onSeasonChanged);
  }

  static final int batchUpdateMs = ServiceConfig().batchUpdateMs;
  static final double closeProximityBoost = ServiceConfig().closeProximityBoost; // Volume boost for very close sounds
  static final double closeProximityThreashold = ServiceConfig().closeProximityThreshold; // Meters
  static final bool debugMode = ServiceConfig().debugMode; // Enable debug logging
  // Constants
  static final double maxRange = ServiceConfig().maxRange; // 50.0; // Maximum range in meters for observation detection

  static final double maxVolume = ServiceConfig().maxVolume; // Maximum volume for nearby sounds
  // Audio settings
  static final double minVolume = ServiceConfig().minVolume; // Minimum volume for distant sounds

  final Map<String, Map<String, dynamic>> _activeObservations = {};
  final BackgroundAudioService _backgroundAudioService;
  Timer? _batchUpdateTimer;
  bool _isAudioEnabled = true;
  // State
  bool _isInitialized = false;

  late final LocationManager _locationManager;
  List<Map<String, dynamic>> _observations = [];
  final SeasonService _seasonService;
  // Services
  final BirdSoundPlayer _soundPlayer;

  final AzureStorageService _storageService;

  @override
  void dispose() {
    _batchUpdateTimer?.cancel();
    _seasonService.removeListener(_onSeasonChanged);
    _locationManager.dispose();
    _soundPlayer.dispose();
    _activeObservations.clear();
    super.dispose();
  }

  // Public getters
  bool get isInitialized => _isInitialized;

  Position? get currentPosition => _locationManager.currentPosition;

  bool get isLocationTrackingEnabled =>
      _locationManager.isLocationTrackingEnabled;

  bool get isAudioEnabled => _isAudioEnabled;

  List<Map<String, dynamic>> get activeObservations =>
      _activeObservations.values.toList();

  /// Initialize the service
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      return;
    }

    // Get API URL and debug mode from context
    final apiUrl = _getApiUrl(context);
    final scaffoldMessenger = _getScaffoldMessenger(context);

    try {
      await _initializeServices();
      await _fetchAndFilterObservations(apiUrl);

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _log('Error initializing LocationService: $e');
      _showInitializationError(scaffoldMessenger);
    }
  }

  /// Toggle location tracking
  Future<void> toggleLocationTracking(bool enabled) async {
    if (_locationManager.isLocationTrackingEnabled == enabled) {
      return;
    }

    if (enabled) {
      await _startLocationTracking();
    } else {
      await _stopLocationTracking();
    }

    notifyListeners();
  }

/// Toggle audio playback with improved service initialization
Future<void> toggleAudio(bool enabled) async {
  // Add extra logging
  debugPrint('🔊 toggleAudio called with enabled=$enabled, current state=$_isAudioEnabled');
  
  // If state isn't changing, do nothing
  if (_isAudioEnabled == enabled) {
    debugPrint('🔊 Audio state already matches requested state, no change needed');
    return;
  }

  debugPrint('🔊 Audio playback toggling to: $enabled');

  if (!enabled) {
    // Just stop sounds if disabling
    _stopAllSounds();
    _isAudioEnabled = false;
    notifyListeners();
    return;
  }

  // For enabling audio, we need to ensure all services are properly initialized
  try {
    // 1. First ensure background audio service is running
    await _backgroundAudioService.startService();
    debugPrint('🔊 Background audio service started successfully');
    
    // 2. Give audio service time to initialize
    await Future.delayed(Duration(milliseconds: 500));
    
    // 3. Make sure location tracking is enabled
    if (!_locationManager.isLocationTrackingEnabled) {
      debugPrint('🔊 Enabling location tracking as part of audio activation');
      await _locationManager.setLocationTrackingEnabled(true);
      
      // Allow a moment for the location manager to update
      await Future.delayed(Duration(milliseconds: 300));
    }
    
    // 4. Now set audio enabled state
    _isAudioEnabled = true;
    
    // 5. Start sounds if we have a position
    if (_locationManager.currentPosition != null) {
      debugPrint('🔊 Restarting sounds with position data: ${_locationManager.currentPosition}');
      _updateActiveObservations(_locationManager.currentPosition!);
      _restartSoundsWithDelays();
    } else {
      debugPrint('⚠️ No position available yet, sounds will start when position is available');
    }
    
    notifyListeners();
  } catch (e) {
    debugPrint('❌ Error enabling audio: $e');
    // Try to recover
    _isAudioEnabled = true; // Still mark as enabled despite error
    notifyListeners();
  }
}

  /// Handles position updates from location manager
  void _handlePositionUpdate(Position position) {
    // Schedule a batch update
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(Duration(milliseconds: batchUpdateMs), () {
      _updateActiveObservations(position);
      notifyListeners();
    });
  }

  /// Debug logging
  void _log(String message) {
    if (debugMode) {
      debugPrint('[LocationService] $message');
    }
  }

  /// Called when season changes
  void _onSeasonChanged() {
    _log('Season changed to: ${_seasonService.currentSeason}');

    // Stop all sounds since we'll be filtering observations differently
    if (_isAudioEnabled) {
      _stopAllSounds();
    }

    // Clear active observations
    _activeObservations.clear();

    // Force update if we have a position
    if (_locationManager.currentPosition != null) {
      _updateActiveObservations(_locationManager.currentPosition!);
      notifyListeners();
    }
  }

  /// Stops all currently playing sounds
  void _stopAllSounds() {
    for (var id in _activeObservations.keys) {
      _soundPlayer.stopSounds(id);
    }
  }

  /// Get API URL based on debug mode
  String _getApiUrl(BuildContext context) {
    bool debugMode = false;
    try {
      debugMode = Provider.of<bool>(context, listen: false);
    } catch (e) {
      _log('Error getting debug mode: $e');
    }

    return debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net';
  }

  /// Get scaffold messenger for showing error messages
  ScaffoldMessengerState? _getScaffoldMessenger(BuildContext context) {
    ScaffoldMessengerState? scaffoldMessenger;
    try {
      scaffoldMessenger = ScaffoldMessenger.of(context);
    } catch (e) {
      _log('Error getting ScaffoldMessenger: $e');
    }
    return scaffoldMessenger;
  }

  /// Initialize all required services
  Future<void> _initializeServices() async {
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
  }

  /// Fetch and filter observations from API
  Future<void> _fetchAndFilterObservations(String apiUrl) async {
    _log('Fetching observations from $apiUrl');
    _observations =
        await ObservationService(apiUrl: apiUrl).fetchObservations();

    // Filter valid observations (with sound directories)
    _observations = _observations.where((obs) {
      if (obs["sound_directory"] == null) {
        _log('Skipping observation with null sound directory: ${obs["id"]}');
        return false;
      }
      return true;
    }).toList();

    _log('Loaded ${_observations.length} valid observations');
  }

  /// Show initialization error message
  void _showInitializationError(ScaffoldMessengerState? scaffoldMessenger) {
    if (scaffoldMessenger != null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to initialize location services. Please check your settings.'),
        ),
      );
    }
  }

  /// Check if observation is in the current season
  bool _isObservationInCurrentSeason(Map<String, dynamic> observation) {
    // If using "all seasons", accept all observations
    if (_seasonService.currentSeason == Season.all) {
      return true;
    }

    // Check observation date
    if (observation["observation_date"] == null) {
      return false;
    }

    // Parse the date
    DateTime obsDate;
    try {
      if (observation["observation_date"] is String) {
        obsDate = DateTime.parse(observation["observation_date"]);
      } else if (observation["observation_date"] is DateTime) {
        obsDate = observation["observation_date"];
      } else {
        return false;
      }
    } catch (e) {
      _log('Error parsing observation date: $e');
      return false;
    }

    // Check if date matches current season
    return _seasonService.isDateInSelectedSeason(obsDate);
  }

  /// Update active observations based on user position
  void _updateActiveObservations(Position position) {
    final Set<String> observationsInRange = {};
    bool activeObservationsChanged = false;
    final List<Map<String, dynamic>> newObservations = [];

    // Calculate which observations are in range
    for (var obs in _observations) {
      // Skip invalid observations
      if (!_isValidObservation(obs) || !_isObservationInCurrentSeason(obs)) {
        continue;
      }

      final String id = '${obs["id"]}';
      final double distance = _calculateDistanceToObservation(position, obs);

      // Calculate audio settings based on distance
      final double volume = _calculateVolume(distance);
      final double pan = _calculatePan(position, obs);

      // Check if in range
      if (distance <= maxRange) {
        observationsInRange.add(id);
        activeObservationsChanged = _processInRangeObservation(
            id, obs, pan, volume, newObservations, activeObservationsChanged);
      }
    }

    // Remove observations that are no longer in range
    activeObservationsChanged = _removeOutOfRangeObservations(
        observationsInRange, activeObservationsChanged);

    // Start new sounds with randomized delays
    if (newObservations.isNotEmpty) {
      _startSoundsWithNaturalDelays(newObservations);
    }

    if (activeObservationsChanged) {
      _logActiveObservations();
      notifyListeners();
    }
  }

  /// Check if observation has required fields
  bool _isValidObservation(Map<String, dynamic> obs) {
    return obs["latitude"] != null &&
        obs["longitude"] != null &&
        obs["sound_directory"] != null;
  }

  /// Calculate distance from user to observation
  double _calculateDistanceToObservation(
      Position position, Map<String, dynamic> obs) {
    return _locationManager.calculateDistance(position.latitude,
        position.longitude, obs["latitude"], obs["longitude"]);
  }

  /// Process an observation that is in range
  bool _processInRangeObservation(
      String id,
      Map<String, dynamic> obs,
      double pan,
      double volume,
      List<Map<String, dynamic>> newObservations,
      bool activeObservationsChanged) {
    // Add to active observations if not already active
    if (!_activeObservations.containsKey(id)) {
      _log('Adding observation to active list: ${obs["bird_name"]} (ID: $id)');
      _activeObservations[id] = Map<String, dynamic>.from(obs);
      _activeObservations[id]!["pan"] = pan;
      _activeObservations[id]!["volume"] = volume;

      // Collect new observations to start sounds with delay
      if (_isAudioEnabled) {
        newObservations
            .add({'observation': obs, 'id': id, 'pan': pan, 'volume': volume});
      }

      return true; // Changed
    } else if (_isAudioEnabled) {
      // Only update sound if significant change
      return _updateSoundIfNeeded(id, pan, volume);
    }

    return activeObservationsChanged;
  }

  /// Update sound panning and volume if there's a significant change
  bool _updateSoundIfNeeded(String id, double pan, double volume) {
    final currentPan = _activeObservations[id]!["pan"] ?? 0.0;
    final currentVolume = _activeObservations[id]!["volume"] ?? 0.5;

    if ((pan - currentPan).abs() > 0.1 ||
        (volume - currentVolume).abs() > 0.1) {
      _soundPlayer.updatePanningAndVolume(id, pan, volume);

      // Update stored values
      _activeObservations[id]!["pan"] = pan;
      _activeObservations[id]!["volume"] = volume;
      return true;
    }

    return false;
  }

  /// Remove observations that are no longer in range
  bool _removeOutOfRangeObservations(
      Set<String> observationsInRange, bool activeObservationsChanged) {
    final List<String> toRemove = [];

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

    return activeObservationsChanged;
  }

  /// Log active observations (in debug mode)
  void _logActiveObservations() {
    _log('Active observations updated: ${_activeObservations.length} active');

    if (debugMode) {
      _activeObservations.forEach((id, obs) {
        _log('Active: ${obs["bird_name"]} (ID: $id)');
      });
    }
  }

  /// Start sounds with natural delays
  void _startSoundsWithNaturalDelays(List<Map<String, dynamic>> observations) {
    // Shuffle the observations for more randomness
    observations.shuffle();

    // Add a base delay to avoid all sounds starting immediately
    int baseDelay = 300 + Random().nextInt(700); // 300-1000ms base delay
    int currentDelay = baseDelay;

    for (var obsData in observations) {
      // Apply some randomness to each increment
      int increment =
          500 + Random().nextInt(20000); // 500-20000ms between sounds

      // Start this sound after delay
      Future.delayed(Duration(milliseconds: currentDelay), () {
        _startDelayedSound(obsData);
      });

      // Increase delay for next sound
      currentDelay += increment;
    }
  }

  /// Start a sound after a delay
  void _startDelayedSound(Map<String, dynamic> obsData) {
    // Check if observation is still active before starting
    if (_activeObservations.containsKey(obsData['id'])) {
      var obs = obsData['observation'];
      var pan = obsData['pan'];
      var volume = obsData['volume'];

      // Start with additional random volume variation (80-100% of calculated volume)
      double naturalVolume = volume * (0.8 + Random().nextDouble() * 0.2);
      _startSound(obs, pan, naturalVolume);

      // Log with delay info
      _log('🎵 Started sound for ${obs["bird_name"]}');
    }
  }

  /// Calculate volume based on distance
  double _calculateVolume(double distance) {
    // Normalized distance (0-1)
    final normalizedDistance = (distance / maxRange).clamp(0.0, 1.0);

    // Cubic falloff (steeper than quadratic)
    final falloff =
        1.0 - (normalizedDistance * normalizedDistance * normalizedDistance);

    // Add a "close proximity boost" for very nearby sounds
    double volumeBoost = 0.0;
    if (distance < closeProximityThreashold) {
      // Extra boost when very close
      volumeBoost = closeProximityBoost *
          (1.0 - (distance / closeProximityThreashold));
    }

    final volume =
        minVolume + falloff * (maxVolume - minVolume) + volumeBoost;
    return volume.clamp(minVolume, maxVolume);
  }

  /// Calculate stereo panning based on position
  double _calculatePan(
      Position userPosition, Map<String, dynamic> observation) {
    // Calculate distance
    double distance = _locationManager.calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        observation["latitude"],
        observation["longitude"]);

    // Calculate bearing to sound
    double bearing = _locationManager.calculateBearing(
        userPosition.latitude,
        userPosition.longitude,
        observation["latitude"],
        observation["longitude"]);

    // Normalize bearing to -180 to 180
    if (bearing > 180) bearing -= 360;
    if (bearing < -180) bearing += 360;

    // Calculate base pan value
    double basePan = bearing / 90.0;

    // Distance factor (closer = more pronounced panning)
    double distanceFactor = 1.0 - (distance / maxRange).clamp(0.0, 0.8);

    // Apply distance factor to make nearby sounds have stronger panning
    double pan = basePan * (0.7 + (distanceFactor * 0.3));

    // Allow full stereo range
    return pan.clamp(-1.0, 1.0);
  }

  /// Start sound for an observation
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

  /// Start location tracking and background audio service
  Future<void> _startLocationTracking() async {
  try {
    _log('Starting location tracking and audio services');
    
    // First initialize the background audio service
    await _backgroundAudioService.startService();
    
    // Give audio service time to initialize
    await Future.delayed(Duration(milliseconds: 500));
    
    // Then start location tracking
    await _locationManager.setLocationTrackingEnabled(true);
    
    // If audio was enabled, make sure sounds are playing
    if (_isAudioEnabled && _locationManager.currentPosition != null) {
      _log('Restarting sounds after tracking enabled');
      // Update active observations with the current position
      _updateActiveObservations(_locationManager.currentPosition!);
      // Then restart sounds with delays
      _restartSoundsWithDelays();
    }
    
    _log('Location tracking successfully started');
  } catch (e) {
    _log('Error starting location tracking: $e');
    // Try to recover by at least enabling location tracking
    try {
      await _locationManager.setLocationTrackingEnabled(true);
    } catch (e2) {
      _log('Recovery attempt also failed: $e2');
    }
  }
}
  /// Stop location tracking and background audio service
  Future<void> _stopLocationTracking() async {
    // Stop all sounds
    _stopAllSounds();
    _activeObservations.clear();

    // First stop location tracking
    await _locationManager.setLocationTrackingEnabled(false);

    // Then stop background service
    await _backgroundAudioService.stopService();

    // Cancel any pending updates
    _batchUpdateTimer?.cancel();
  }

  /// Restart sounds with staggered delays
  void _restartSoundsWithDelays() {
    int delay = 0;

    for (var obs in _activeObservations.values) {
      final String id = '${obs["id"]}';

      final Position position = _locationManager.currentPosition!;

      final double distance = _locationManager.calculateDistance(
          position.latitude,
          position.longitude,
          obs["latitude"],
          obs["longitude"]);

      final double volume = _calculateVolume(distance);
      final double pan = _calculatePan(position, obs);

      // Stagger sound starts to avoid audio overload
      delay += 500; // Increased from 300ms
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isAudioEnabled && _activeObservations.containsKey(id)) {
          _startSound(obs, pan, volume);
        }
      });
    }
  }
}
