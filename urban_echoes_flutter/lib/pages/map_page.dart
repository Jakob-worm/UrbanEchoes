import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/consants.dart';
import 'package:urban_echoes/services/ObservationService.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urban_echoes/services/LocationService.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  // Map state
  List<Map<String, dynamic>> observations = [];
  List<CircleMarker> circles = [];
  double _zoomLevel = AppConstants.defaultZoom;
  LatLng _userLocation = LatLng(56.171812, 10.187769);
  MapController? _mapController;
  
  // Loading state
  bool _isLocationLoaded = false;
  bool _dataLoaded = false;
  bool _isLoading = true;
  bool _mapReady = false;
  String? _errorMessage;
  
  // Services
  LocationService? _locationService;
  bool _isInitialized = false;
  bool _locationServiceInitialized = false;
  
  // Loading timeout
  Timer? _loadingTimeoutTimer;
  bool _forcedLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Create map controller but don't use it until the map is ready
    _mapController = MapController();
    
    // Set a timeout for loading to prevent infinite loading
    _loadingTimeoutTimer = Timer(Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        print('⚠️ Loading timeout reached, forcing map display');
        setState(() {
          _forcedLoad = true;
          _isLoading = false;
          if (_errorMessage == null) {
            _errorMessage = 'Some resources are still loading. The map may have limited functionality.';
          }
        });
      }
    });
    
    // Defer initialization until after the widget is properly built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeAfterBuild();
      }
    });
  }
  
  void _initializeAfterBuild() {
    print('Initializing map after build');
    
    // Initialize LocationService with proper error handling
    _initializeLocationService();
    
    // Load observations
    _loadObservations();
    
    // Get user location (with proper permission handling)
    _getUserLocation();
    
    // Force map ready if it hasn't happened in a reasonable time
    Timer(Duration(seconds: 5), () {
      if (mounted && !_mapReady) {
        print('⚠️ Map ready timeout reached, forcing map ready state');
        setState(() {
          _mapReady = true;
          _checkIfFullyLoaded();
        });
      }
    });
  }

  void _initializeLocationService() {
    if (_locationServiceInitialized) return;
    
    print('Initializing location service');
    
    try {
      if (!mounted) return;
      
      final locationService = Provider.of<LocationService>(context, listen: false);
      _locationService = locationService;
      
      if (!locationService.isInitialized) {
        locationService.initialize(context);
      }
      
      _locationServiceInitialized = true;
      print('Location service initialized successfully');
      
      if (locationService.lastKnownPosition != null && !_isLocationLoaded) {
        print('Using position from LocationService: ${locationService.lastKnownPosition!.latitude}, ${locationService.lastKnownPosition!.longitude}');
        _updateUserLocation(locationService.lastKnownPosition!);
      }
    } catch (e) {
      print('❌ Error initializing LocationService: $e');
      setState(() {
        _errorMessage = 'Could not access location services. Please restart the app.';
        _isLocationLoaded = true; // Mark as loaded so we can continue
        _checkIfFullyLoaded();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only initialize once to avoid multiple initializations
    if (!_isInitialized) {
      _isInitialized = true;
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    
    try {
      if (_locationService != null) {
        if (state == AppLifecycleState.resumed) {
          if (!_locationService!.isLocationTrackingEnabled) {
            _locationService!.toggleLocationTracking(true);
          }
        } else if (state == AppLifecycleState.paused) {
          if (_locationService!.isLocationTrackingEnabled) {
            _locationService!.toggleLocationTracking(false);
          }
        }
      }
    } catch (e) {
      print('Error in lifecycle: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingTimeoutTimer?.cancel();
    _mapController = null;
    super.dispose();
  }

  // Update user location and map position
  void _updateUserLocation(Position position) {
    if (!mounted) return;
    
    print('Updating user location: ${position.latitude}, ${position.longitude}');
    
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
      _isLocationLoaded = true;

      // Only move map if it's ready and initialized
      if (_mapReady && _mapController != null) {
        try {
          _mapController!.move(_userLocation, _zoomLevel);
        } catch (e) {
          print('Error moving map to user location: $e');
        }
      }
      
      // Check if we're fully loaded
      _checkIfFullyLoaded();
    });
  }

  // Check if all necessary data is loaded
  void _checkIfFullyLoaded() {
    print('Checking if fully loaded: locationLoaded=$_isLocationLoaded, dataLoaded=$_dataLoaded, mapReady=$_mapReady, forcedLoad=$_forcedLoad');
    
    if (_forcedLoad || (_isLocationLoaded && _dataLoaded && _mapReady)) {
      print('All conditions satisfied (or forced load), map should now be displayed');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Safe method to show a snackbar
  void _showSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _getUserLocation() async {
    print('Getting user location');
    try {
      // Check if we already have location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        
        if (!mounted) return;
        
        if (permission == LocationPermission.denied) {
          print('Location permission still denied after request');
          setState(() {
            _errorMessage = 'Location permission denied';
            _isLocationLoaded = true; // Mark as loaded so we can continue
            _checkIfFullyLoaded();
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        if (!mounted) return;
        
        setState(() {
          _errorMessage = 'Location permission permanently denied. Please enable in settings.';
          _isLocationLoaded = true; // Mark as loaded so we can continue
          _checkIfFullyLoaded();
        });
        return;
      }

      print('Getting current position with timeout of 10 seconds');
      try {
        // Add timeout to getCurrentPosition
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // Add a reasonable timeout
        );
        
        print('Got current position: ${position.latitude}, ${position.longitude}');
        
        if (!mounted) return;
        
        _updateUserLocation(position);
      } catch (timeoutError) {
        print('❌ Timeout getting location: $timeoutError');
        
        if (!mounted) return;
        
        // Try with last known position as fallback
        print('Trying to get last known position as fallback');
        try {
          Position? lastPosition = await Geolocator.getLastKnownPosition();
          if (lastPosition != null) {
            print('Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
            _updateUserLocation(lastPosition);
          } else {
            print('No last known position available');
            setState(() {
              _errorMessage = 'Could not get your location. Please try again.';
              _isLocationLoaded = true; // Mark as loaded so we can continue
              _checkIfFullyLoaded();
            });
          }
        } catch (e) {
          print('❌ Error getting last known position: $e');
          setState(() {
            _errorMessage = 'Could not access location services. Please restart the app.';
            _isLocationLoaded = true; // Mark as loaded so we can continue
            _checkIfFullyLoaded();
          });
        }
      }
    } catch (e) {
      print('❌ General error getting location: $e');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error accessing location: $e';
        _isLocationLoaded = true; // Mark as loaded so we can continue
        _checkIfFullyLoaded();
      });
    }
  }

  void _loadObservations() {
    if (_dataLoaded || !mounted) return;
    
    print('Loading observations');
    
    bool debugMode = false;
    try {
      debugMode = Provider.of<bool>(context, listen: false);
    } catch (e) {
      print('Error accessing debug mode: $e');
    }
    
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    print('Fetching observations from: $apiUrl');
    ObservationService(apiUrl: apiUrl).fetchObservations().then((data) {
      if (!mounted) return;
      
      print('Received ${data.length} observations');
      setState(() {
        observations = data.map((obs) {
          return {
            "id": obs["id"],
            "bird_name": obs["bird_name"],
            "scientific_name": obs["scientific_name"],
            "sound_directory": obs["sound_directory"],
            "latitude": obs["latitude"],
            "longitude": obs["longitude"],
            "observation_date": obs["observation_date"],
            "observation_time": obs["observation_time"],
            "observer_id": obs["observer_id"],
            "created_at": obs["created_at"],
            "quantity": obs["quantity"],
            "is_test_data": obs["is_test_data"],
            "test_batch_id": obs["test_batch_id"],
          };
        }).toList();

        _updateCircles();
        _dataLoaded = true;
        _checkIfFullyLoaded();
      });
    }).catchError((error) {
      print('❌ Error loading observations: $error');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Failed to load observations: $error';
        _dataLoaded = true; // Mark as loaded so we can continue
        _checkIfFullyLoaded();
      });
    });
  }

  void _updateCircles() {
    print('Updating observation circles on map');
    circles = observations.map((obs) {
      return CircleMarker(
        point: LatLng(obs["latitude"], obs["longitude"]),
        radius: AppConstants.defaultPointRadius,
        useRadiusInMeter: true,
        color: getObservationColor(obs).withOpacity(0.3),
        borderColor: getObservationColor(obs).withOpacity(0.7),
        borderStrokeWidth: 2,
      );
    }).toList();
    print('Created ${circles.length} circle markers');
  }

  Color getObservationColor(Map<String, dynamic> obs) {
    bool isTestData = obs["is_test_data"];
    int observerId = obs["observer_id"] ?? -1; // Default to -1 if null

    if (observerId == 0) {
      return Colors.green;
    } else if (isTestData) {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  void _onMapTap(LatLng tappedPoint) {
    if (_isLoading || observations.isEmpty) return;
    
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestObservation;

    for (var obs in observations) {
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
          title: Text(observation["bird_name"]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Scientific Name: ${observation["scientific_name"]}"),
              Text("Date: ${observation["observation_date"]}"),
              Text("Time: ${observation["observation_time"]}"),
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
    print('Map is now ready!');
    setState(() {
      _mapReady = true;
      
      // If we already have user location, center the map on it
      if (_isLocationLoaded && _mapController != null) {
        try {
          print('Centering map on user location: $_userLocation');
          _mapController!.move(_userLocation, _zoomLevel);
        } catch (e) {
          print('Error moving map on creation: $e');
        }
      }
      
      _checkIfFullyLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    // First check if we're loading
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading map data..."),
              if (_errorMessage != null) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Force display the map even if not all conditions are met
                  setState(() {
                    _forcedLoad = true;
                    _isLoading = false;
                  });
                },
                child: Text("Show Map Anyway"),
              ),
            ],
          ),
        ),
      );
    }
    
    // Now try to get the LocationService if we don't have it yet
    if (_locationService == null && !_locationServiceInitialized) {
      _initializeLocationService();
    }
    
    // Build the map content
    Widget content;
    
    try {
      // Only use Consumer if we have a valid LocationService
      if (_locationService != null) {
        content = Consumer<LocationService>(
          builder: (context, locationService, child) {
            // Update position from service if available
            if (locationService.lastKnownPosition != null && !_isLocationLoaded) {
              _updateUserLocation(locationService.lastKnownPosition!);
            }
            
            final activeBirdSounds = locationService.getActiveBirdSounds();
            
            return _buildMapContent(activeBirdSounds);
          },
        );
      } else {
        // Fallback if no LocationService is available
        content = _buildMapContent([]);
      }
    } catch (e) {
      print('Error with Consumer in build: $e');
      // Fallback UI if the Consumer fails
      content = _buildMapContent([]);
    }
    
    return content;
  }
  
  // Extract the map building logic to a separate method
  Widget _buildMapContent(List<Map<String, dynamic>> activeBirdSounds) {
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
                print('FlutterMap.onMapReady called!');
                if (_mapController != null) {
                  _onMapCreated(_mapController!);
                }
              },
              onPositionChanged: (position, bool hasGesture) {
                if (hasGesture && mounted) {
                  setState(() {
                    _zoomLevel = position.zoom;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              CircleLayer(circles: circles),
              // User location marker
              MarkerLayer(
                markers: [
                  if (_isLocationLoaded)
                    Marker(
                      point: _userLocation,
                      width: 30,
                      height: 30,
                      child: Stack(
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
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Location recenter button
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              heroTag: "locationButton",
              onPressed: () {
                _getUserLocation(); // Update and recenter to user location
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          // Active bird sound information - will update when activeBirdSounds changes
          if (activeBirdSounds.isNotEmpty)
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
                    Text(
                      'Listening to:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                    for (var birdSound in activeBirdSounds)
                      Text(
                        '${birdSound["bird_name"]} (${birdSound["scientific_name"]})',
                        style: TextStyle(
                          fontSize: 14.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Show error message if exists
          if (_errorMessage != null)
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
                  _errorMessage!,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}