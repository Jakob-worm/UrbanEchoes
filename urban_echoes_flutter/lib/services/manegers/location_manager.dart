import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urban_echoes/services/repo/location_repository.dart';
import 'package:urban_echoes/services/service_config.dart';


class LocationManager {
  // Dependencies
  final LocationRepositoryInterface _locationRepository;
  final ServiceConfig _config = ServiceConfig();
  
  // State
  bool _isInitialized = false;
  bool _isLocationTrackingEnabled = true;
  Position? _currentPosition;
  Position? _lastProcessedPosition;
  DateTime _lastPositionUpdate = DateTime.now();
  int _positionUpdateFailures = 0;
  
  // Subscriptions and timers
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationFallbackTimer;
  Timer? _serviceWatchdog;
  
  // Callback for position updates
  late final void Function(Position)? onPositionUpdate;
  
  // Constructor
  LocationManager({
    LocationRepositoryInterface? locationRepository,
    this.onPositionUpdate,
  }) : _locationRepository = locationRepository ?? LocationRepository();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLocationTrackingEnabled => _isLocationTrackingEnabled;
  Position? get currentPosition => _currentPosition;
  
  // Initialize the manager
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      // Request location permission
      bool permissionGranted = await _locationRepository.requestLocationPermission();
      if (!permissionGranted) {
        if (_config.debugMode) {
          debugPrint('[LocationManager] Location permission denied');
        }
        return false;
      }
      
      // Start location tracking
      await startLocationTracking();
      
      // Start watchdog timer
      _startWatchdog();
      
      // Start fallback timer
      _startLocationFallbackTimer();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      if (_config.debugMode) {
        debugPrint('[LocationManager] Error initializing: $e');
      }
      
      // Try to start location tracking even with error
      startLocationTracking();
      return false;
    }
  }
  
  // Start location tracking
  Future<void> startLocationTracking() async {
    // Clean up existing resources
    await _cleanupLocationResources();
    
    if (!_isLocationTrackingEnabled) {
      return;
    }
    
    // Wait a moment to ensure clean state
    await Future.delayed(Duration(milliseconds: 100));
    
    try {
      // Set up position stream
      _positionStreamSubscription = _locationRepository
          .getPositionStream(distanceFilter: _config.distanceFilter)
          .handleError((error) {
            if (_config.debugMode) {
              debugPrint('[LocationManager] Position stream error: $error');
            }
            _positionUpdateFailures++;
            _restartLocationTracking();
            return;
          })
          .listen(
            (position) {
              _positionUpdateFailures = 0; // Reset on success
              _handlePositionUpdate(position);
            },
            onError: (e) {
              if (_config.debugMode) {
                debugPrint('[LocationManager] Position update error: $e');
              }
              _positionUpdateFailures++;
              _restartLocationTracking();
            },
            cancelOnError: false,
          );
      
      // Get initial position
      _locationRepository
          .getCurrentPosition()
          .then((position) {
            if (position != null) {
              _positionUpdateFailures = 0;
              _handlePositionUpdate(position);
            }
          })
          .catchError((e) {
            if (_config.debugMode) {
              debugPrint('[LocationManager] Initial position error: $e');
            }
            _positionUpdateFailures++;
          });
      
      if (_config.debugMode) {
        debugPrint('[LocationManager] Started location tracking with distanceFilter=${_config.distanceFilter}m');
      }
    } catch (e) {
      if (_config.debugMode) {
        debugPrint('[LocationManager] Error setting up location tracking: $e');
      }
      _positionUpdateFailures++;
    }
  }
  
  // Handle position updates
  void _handlePositionUpdate(Position position) {
    _currentPosition = position;
    
    // Skip processing if not enough time has elapsed
    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate).inMilliseconds < 500) {
      return;
    }
    _lastPositionUpdate = now;
    
    if (_config.debugMode) {
      debugPrint('[LocationManager] Position update: ${position.latitude}, ${position.longitude}');
    }
    
    // Skip if position hasn't changed significantly
    if (_lastProcessedPosition != null) {
      final distance = _locationRepository.distanceBetween(
        _lastProcessedPosition!.latitude,
        _lastProcessedPosition!.longitude,
        position.latitude,
        position.longitude
      );
      
      if (distance < _config.distanceFilter / 2) {
        if (_config.debugMode) {
          debugPrint('[LocationManager] Skipping position update (moved only ${distance.toStringAsFixed(1)}m)');
        }
        return;
      }
    }
    
    _lastProcessedPosition = position;
    
    // Call the callback
    if (onPositionUpdate != null) {
      onPositionUpdate!(position);
    }
  }
  
  // Clean up resources
  Future<void> _cleanupLocationResources() async {
    try {
      if (_positionStreamSubscription != null) {
        await _positionStreamSubscription!.cancel();
        _positionStreamSubscription = null;
      }
    } catch (e) {
      if (_config.debugMode) {
        debugPrint('[LocationManager] Error cleaning up location resources: $e');
      }
    }
  }
  
  // Restart location tracking
  void _restartLocationTracking() {
    if (_config.debugMode) {
      debugPrint('[LocationManager] Restarting location tracking after error');
    }
    
    Future.delayed(Duration(seconds: 3), () {
      startLocationTracking();
    });
  }
  
  // Start a watchdog timer
  void _startWatchdog() {
    _serviceWatchdog?.cancel();
    _serviceWatchdog = Timer.periodic(
      Duration(minutes: _config.watchdogIntervalMinutes), 
      (_) {
        if (_config.debugMode) {
          debugPrint('[LocationManager] Watchdog check');
        }
        
        // Check if location updates have stalled
        if (_currentPosition != null &&
            DateTime.now().difference(_lastPositionUpdate).inMinutes >= 
            _config.locationStallThresholdMinutes) {
          if (_config.debugMode) {
            debugPrint('[LocationManager] Location updates have stalled, restarting tracking');
          }
          _restartLocationTracking();
        }
        
        // Force callback if we haven't in a while
        if (_currentPosition != null &&
            DateTime.now().difference(_lastPositionUpdate).inMinutes >= 1 &&
            onPositionUpdate != null) {
          onPositionUpdate!(_currentPosition!);
        }
      }
    );
  }
  
  // Start fallback timer for location updates
  void _startLocationFallbackTimer() {
    _locationFallbackTimer?.cancel();
    _locationFallbackTimer = Timer.periodic(
      Duration(seconds: _config.fallbackTimerSeconds),
      (_) {
        // Check if we need fallback position data
        if (_positionUpdateFailures >= _config.maxFailuresBeforeFallback ||
            _currentPosition == null ||
            DateTime.now().difference(_lastPositionUpdate).inSeconds > 45) {
          if (_config.debugMode) {
            debugPrint('[LocationManager] Using fallback location update mechanism');
          }
          
          // Try to get current position
          _locationRepository.getCurrentPosition()
            .then((position) {
              if (position != null) {
                _positionUpdateFailures = 0;
                _handlePositionUpdate(position);
              } else {
                _tryFallbackOptions();
              }
            })
            .catchError((e) {
              if (_config.debugMode) {
                debugPrint('[LocationManager] Fallback location update failed: $e');
              }
              _tryFallbackOptions();
            });
          
          // Restart tracking if it seems stuck
          if (DateTime.now().difference(_lastPositionUpdate).inSeconds > 60) {
            _restartLocationTracking();
          }
        }
      }
    );
  }
  
  // Try fallback options for position
  void _tryFallbackOptions() {
    // Try last known position
    _locationRepository.getLastKnownPosition().then((position) {
      if (position != null) {
        _handlePositionUpdate(position);
      } else if (_currentPosition == null) {
        // If all else fails, use a hardcoded position
        if (_config.debugMode) {
          debugPrint('[LocationManager] Using hardcoded position as last resort');
        }
        
        // Get fallback position from repository
        final fallbackPosition = (_locationRepository as LocationRepository).getFallbackPosition();
        _handlePositionUpdate(fallbackPosition);
      }
    }).catchError((e) {
      if (_config.debugMode) {
        debugPrint('[LocationManager] Could not get last known position: $e');
      }
    });
  }
  
  // Enable or disable location tracking
  Future<void> setLocationTrackingEnabled(bool enabled) async {
    if (_isLocationTrackingEnabled == enabled) {
      return;
    }
    
    _isLocationTrackingEnabled = enabled;
    
    if (enabled) {
      await startLocationTracking();
    } else {
      await _cleanupLocationResources();
    }
  }
  
  // Calculate distance between two points
  double calculateDistance(
    double lat1, double lng1, double lat2, double lng2
  ) {
    return _locationRepository.distanceBetween(lat1, lng1, lat2, lng2);
  }
  
  // Calculate bearing between two points
  double calculateBearing(
    double lat1, double lng1, double lat2, double lng2
  ) {
    return _locationRepository.bearingBetween(lat1, lng1, lat2, lng2);
  }
  
  // Dispose resources
  void dispose() {
    _cleanupLocationResources();
    _serviceWatchdog?.cancel();
    _locationFallbackTimer?.cancel();
  }
}