import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/consants.dart';
import 'package:urban_echoes/services/ObservationService.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urban_echoes/services/LocationService.dart';
import 'package:urban_echoes/state%20manegers/MapStateManager.dart';

// Improved location marker that shows direction
class DirectionalLocationMarker extends StatelessWidget {
  final double heading; // In degrees, 0 = North, 90 = East, etc.
  
  const DirectionalLocationMarker({
    Key? key, 
    required this.heading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer blue circle
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
        // Inner blue circle
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        // Direction indicator
        Transform.rotate(
          angle: heading * (math.pi / 180),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: Container(
              width: 10,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  // Map state
  final List<Map<String, dynamic>> _observations = [];
  final List<CircleMarker> _circles = [];
  double _zoomLevel = AppConstants.defaultZoom;
  LatLng _userLocation = LatLng(56.171812, 10.187769);
  double _userHeading = 0.0; // Default heading (North)
  MapController? _mapController;
  
  // Throttling state
  DateTime _lastMapUpdate = DateTime.now();
  Timer? _mapUpdateTimer;
  
  // Services
  LocationService? _locationService;
  
  // State manager
  late MapStateManager _stateManager;
  
  // Loading timeout
  Timer? _loadingTimeoutTimer;
  Timer? _periodicStateCheck;

  // Observation display
  List<Map<String, dynamic>> _lastActiveObservations = [];
  
  // Follow user flag
  bool _followUser = true;
  
  // Keep track of previous position for heading calculation
  Position? _lastUserLocation;

  // Added to track the latest position and update outside of build
  Position? _pendingPositionUpdate;
  Timer? _positionUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Create map controller once
    _mapController = MapController();
    
    // Initialize state manager
    _stateManager = MapStateManager();
    _stateManager.initialize();
    
    // Set a timeout for loading
    _loadingTimeoutTimer = Timer(Duration(seconds: 15), () {
      if (mounted) {
        _stateManager.forceReady();
      }
    });
    
    // Add periodic check to ensure UI components stay visible
    _periodicStateCheck = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted && _stateManager.state != MapState.ready && _locationService?.currentPosition != null) {
        _stateManager.forceReady();
      }
    });
    
    // Start position update timer
    _positionUpdateTimer = Timer.periodic(Duration(milliseconds: 500), (_) {
      _processPendingPositionUpdate();
    });
    
    // Defer initialization until after the widget is properly built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeAfterBuild();
      }
    });
  }
  
  void _processPendingPositionUpdate() {
  if (_pendingPositionUpdate != null && mounted) {
    try {
      _safelyUpdatePosition(_pendingPositionUpdate!);
    } catch (e) {
      debugPrint('Error processing position update: $e');
    } finally {
      _pendingPositionUpdate = null;
    }
  }
}
  
  // Safely update position outside of build method
  void _safelyUpdatePosition(Position position) {
    // Skip frequent updates
    final now = DateTime.now();
    if (now.difference(_lastMapUpdate).inMilliseconds < 300) {
      return;
    }
    _lastMapUpdate = now;
    
    // Calculate heading if we have previous position
    if (_lastUserLocation != null) {
      if (position.speed > 0.5) { // Only update heading if moving
        _userHeading = position.heading;
      }
    }
    _lastUserLocation = position;
    
    // Update state
    if (mounted) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _stateManager.setLocationLoaded(true);
        
        // Only move map if following user and it's ready
        if (_followUser && _stateManager.isMapFullyLoaded && _mapController != null) {
          try {
            _mapController!.move(_userLocation, _zoomLevel);
          } catch (e) {
            debugPrint('Error moving map: $e');
          }
        }
      });
    }
  }
  
  void _initializeAfterBuild() {
    // Transition to loading data state
    _stateManager.startLoadingData();
    
    // Initialize LocationService with proper error handling
    _initializeLocationService();
    
    // Load observations and get user location in parallel
    Future.wait([
      _loadObservations(),
      _getUserLocation(),
    ]).then((_) {
      // Force map ready if it hasn't happened in a reasonable time
      if (mounted && !_stateManager.isMapFullyLoaded) {
        _stateManager.setMapReady(true);
      }
    });
  }

  void _initializeLocationService() {
  try {
    if (!mounted) return;
    
    final locationService = Provider.of<LocationService>(context, listen: false);
    _locationService = locationService;
    
    // Use a more robust initialization check
    if (!locationService.isInitialized) {
      locationService.initialize(context).then((_) {
        // Force another UI update when service is initialized
        if (mounted) {
          setState(() {
            // Trigger position update if available
            if (locationService.currentPosition != null) {
              _pendingPositionUpdate = locationService.currentPosition;
            }
          });
        }
      }).catchError((error) {
        debugPrint('❌ Error initializing LocationService: $error');
        _stateManager.setError('Could not access location services. Please restart the app.');
      });
    } else {
      // If already initialized, check for current position
      if (locationService.currentPosition != null) {
        _pendingPositionUpdate = locationService.currentPosition;
      }
    }
  } catch (e) {
    debugPrint('❌ Unexpected error in location service initialization: $e');
    _stateManager.setError('Unexpected location service error');
  }
}
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _locationService == null) return;
    
    try {
      if (state == AppLifecycleState.resumed) {
        if (!_locationService!.isLocationTrackingEnabled) {
          _locationService!.toggleLocationTracking(true);
        }
        // Force UI refresh when app is resumed
        if (mounted) {
          setState(() {});
        }
      } else if (state == AppLifecycleState.paused) {
        if (_locationService!.isLocationTrackingEnabled) {
          _locationService!.toggleLocationTracking(false);
        }
      }
    } catch (e) {
      debugPrint('Error in lifecycle: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingTimeoutTimer?.cancel();
    _mapUpdateTimer?.cancel();
    _periodicStateCheck?.cancel();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    debugPrint('Getting user location');
    _stateManager.waitForLocation();
    
    try {
      // Check if we already have location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        if (!mounted) return;
        
        if (permission == LocationPermission.denied) {
          _stateManager.setError('Location permission denied');
          _stateManager.setLocationLoaded(true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        
        _stateManager.setError('Location permission permanently denied. Please enable in settings.');
        _stateManager.setLocationLoaded(true);
        return;
      }

      // Add timeout to getCurrentPosition
      try {
        // Use last known position first for immediate response
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null && mounted) {
          _pendingPositionUpdate = lastPosition;
        }
        
        // Then get accurate position with timeout
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // Reduced from high
          timeLimit: Duration(seconds: 8),
        );
        
        if (!mounted) return;
        
        _pendingPositionUpdate = position;
      } catch (timeoutError) {
        debugPrint('❌ Timeout getting location: $timeoutError');
        
        if (!mounted) return;
        
        // We already tried last known position above, so just show error
        _stateManager.setError('Could not get your precise location. Using last known position.');
        _stateManager.setLocationLoaded(true);
      }
    } catch (e) {
      debugPrint('❌ General error getting location: $e');
      if (!mounted) return;
      
      _stateManager.setError('Error accessing location: $e');
      _stateManager.setLocationLoaded(true);
    }
  }

  Future<void> _loadObservations() async {
    if (!mounted) return;
    
    debugPrint('Loading observations');
    
    bool debugMode = false;
    try {
      debugMode = Provider.of<bool>(context, listen: false);
    } catch (e) {
      debugPrint('Error accessing debug mode: $e');
    }
    
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    try {
      final data = await ObservationService(apiUrl: apiUrl).fetchObservations();
      
      if (!mounted) return;
      
      debugPrint('Received ${data.length} observations');
      
      // Process data in chunks to avoid UI blocking
      _processObservationsInChunks(data);
      
      _stateManager.setDataLoaded(true);
    } catch (error) {
      debugPrint('❌ Error loading observations: $error');
      if (!mounted) return;
      
      _stateManager.setError('Failed to load observations: $error');
      _stateManager.setDataLoaded(true);
    }
  }

  // Process observations in chunks to avoid UI freezing
  void _processObservationsInChunks(List<Map<String, dynamic>> data) {
    const int chunkSize = 50;
    int processedCount = 0;
    
    Future<void> processChunk() async {
      if (processedCount >= data.length || !mounted) return;
      
      int endIdx = (processedCount + chunkSize) < data.length 
          ? processedCount + chunkSize 
          : data.length;
      
      List<Map<String, dynamic>> chunk = data.sublist(processedCount, endIdx);
      List<CircleMarker> newCircles = [];
      
      for (var obs in chunk) {
        if (obs["latitude"] == null || obs["longitude"] == null) continue;
        
        // Add to observations list
        _observations.add({
          "id": obs["id"],
          "bird_name": obs["bird_name"],
          "scientific_name": obs["scientific_name"],
          "sound_directory": obs["sound_directory"],
          "latitude": obs["latitude"],
          "longitude": obs["longitude"],
          "observation_date": obs["observation_date"],
          "observation_time": obs["observation_time"],
          "observer_id": obs["observer_id"],
          "is_test_data": obs["is_test_data"],
        });
        
        // Create circle marker
        newCircles.add(CircleMarker(
          point: LatLng(obs["latitude"], obs["longitude"]),
          radius: AppConstants.defaultPointRadius,
          useRadiusInMeter: true,
          color: getObservationColor(obs).withOpacity(0.3),
          borderColor: getObservationColor(obs).withOpacity(0.7),
          borderStrokeWidth: 2,
        ));
      }
      
      if (mounted) {
        setState(() {
          _circles.addAll(newCircles);
        });
      }
      
      processedCount = endIdx;
      
      if (processedCount < data.length) {
        // Schedule next chunk with small delay
        await Future.delayed(Duration(milliseconds: 10));
        processChunk();
      }
    }
    
    // Start processing
    processChunk();
  }

  Color getObservationColor(Map<String, dynamic> obs) {
    bool isTestData = obs["is_test_data"] ?? false;
    int observerId = obs["observer_id"] ?? -1;

    if (observerId == 0) {
      return Colors.green;
    } else if (isTestData) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  void _onMapTap(LatLng tappedPoint) {
    if (_stateManager.isLoading || _observations.isEmpty) return;
    
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestObservation;

    for (var obs in _observations) {
      final distance = Distance().as(
        LengthUnit.Meter,
        tappedPoint,
        LatLng(obs["latitude"], obs["longitude"]),
      );

      if (distance < minDistance && distance <= 100) {
        minDistance = distance;
        nearestObservation = obs;
      }
    }

    if (nearestObservation != null) {
      _showObservationDetails(nearestObservation);
    }
  }

  void _showObservationDetails(Map<String, dynamic> observation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(observation["bird_name"] ?? "Unknown Bird"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Scientific Name: ${observation["scientific_name"] ?? "Unknown"}"),
              Text("Date: ${observation["observation_date"] ?? "Unknown"}"),
              Text("Time: ${observation["observation_time"] ?? "Unknown"}"),
              const SizedBox(height: 10),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
  
  // Called when the map is ready to be used
  void _onMapCreated(MapController controller) {
    debugPrint('Map is now ready!');
    _stateManager.setMapReady(true);
    
    // If we already have user location, center the map on it
    if (_stateManager.state == MapState.ready && _mapController != null) {
      try {
        _mapController!.move(_userLocation, _zoomLevel);
      } catch (e) {
        debugPrint('Error moving map on creation: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make sure LocationService is available
    if (_locationService == null) {
      _initializeLocationService();
    }
    
    // Listen to state changes
    return ChangeNotifierProvider.value(
      value: _stateManager,
      child: Consumer<MapStateManager>(
        builder: (context, stateManager, _) {
          // First check if we're loading
          if (stateManager.isLoading) {
            return _buildLoadingScreen(stateManager);
          }

          // Build the main map
          return Consumer<LocationService>(
            builder: (context, locationService, child) {
              // FIXED: Store position update for later processing instead of updating here
              if (locationService.currentPosition != null) {
                _pendingPositionUpdate = locationService.currentPosition;
              }
              
              // Get active observations from the LocationService
              final activeObservations = locationService.activeObservations;
              
              // Cache the active observations to prevent UI flicker
              if (activeObservations.isNotEmpty) {
                _lastActiveObservations = List.from(activeObservations);
              }
              
              // Use cached observations if current is empty (prevents flicker)
              final observationsToShow = activeObservations.isNotEmpty ? 
                  activeObservations : _lastActiveObservations;
              
              return _buildMapContent(observationsToShow);
            },
          );
        },
      ),
    );
  }
  
  // Build loading screen
  Widget _buildLoadingScreen(MapStateManager stateManager) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(_getLoadingMessage(stateManager.state)),
            if (stateManager.errorMessage != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stateManager.errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Force display the map even if not all conditions are met
                _stateManager.forceReady();
              },
              child: Text("Show Map Anyway"),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getLoadingMessage(MapState state) {
    switch (state) {
      case MapState.initializing:
        return "Initializing...";
      case MapState.loadingData:
        return "Loading bird observations...";
      case MapState.waitingForLocation:
        return "Waiting for location...";
      default:
        return "Loading map data...";
    }
  }
  
  // Extract the map building logic to a separate method
  Widget _buildMapContent(List<Map<String, dynamic>> activeObservations) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              minZoom: AppConstants.minZoom,
              initialZoom: _zoomLevel,
              maxZoom: AppConstants.maxZoom,
              onTap: (_, tappedPoint) => _onMapTap(tappedPoint),
              onMapReady: () {
                if (_mapController != null) {
                  _onMapCreated(_mapController!);
                }
              },
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (position, bool hasGesture) {
                if (hasGesture && mounted) {
                  setState(() {
                    _zoomLevel = position.zoom;
                    _followUser = false; // Stop following user when manually panning
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'urban_echoes_app/1.0',
                  },
                ),
              ),
              CircleLayer(circles: _circles),
              // User location marker with direction
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation,
                    width: 40,
                    height: 40,
                    child: DirectionalLocationMarker(heading: _userHeading),
                  ),
                ],
              ),
            ],
          ),
          // Location recenter button
          Positioned(
            right: 16,
            bottom: 50, // Moved lower on screen
            child: FloatingActionButton(
              heroTag: "locationButton",
              mini: true, // Smaller button
              onPressed: () {
                if (_locationService != null) {
                  setState(() {
                    _followUser = true;
                  });
                  
                  if (_locationService!.currentPosition != null) {
                    _pendingPositionUpdate = _locationService!.currentPosition;
                  } else {
                    // Try to get location again
                    _getUserLocation();
                  }
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          // Active bird sound information with all observations
          if (activeObservations.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4.0,
                      spreadRadius: 2.0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.volume_up, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Listening to:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                          ),
                        ),
                        Spacer(),
                        // Add audio toggle here
                        GestureDetector(
                          onTap: () {
                            if (_locationService != null) {
                              _locationService!.toggleAudio(!_locationService!.isAudioEnabled);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              _locationService?.isAudioEnabled ?? false 
                                  ? Icons.volume_up 
                                  : Icons.volume_off,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Show ALL active observations - wrapped in SingleChildScrollView for long lists
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var obs in activeObservations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  '${obs["bird_name"]} (${obs["scientific_name"]})',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Show error message if exists
          if (_stateManager.errorMessage != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  _stateManager.errorMessage!,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}