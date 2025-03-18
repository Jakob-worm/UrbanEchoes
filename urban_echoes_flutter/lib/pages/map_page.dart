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
  List<Map<String, dynamic>> observations = [];
  List<CircleMarker> circles = [];
  double _zoomLevel = AppConstants.defaultZoom;
  LatLng _userLocation = LatLng(56.171812, 10.187769);
  final MapController _mapController = MapController();
  bool _isLocationLoaded = false;
  bool _dataLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getUserLocation();
    _loadObservations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Access LocationService to ensure it's initialized
    final locationService = Provider.of<LocationService>(context, listen: false);
    if (!locationService.isInitialized) {
      locationService.initialize(context);
    }
    
    // If we already have a position from the service, use it
    if (locationService.lastKnownPosition != null && !_isLocationLoaded) {
      _updateUserLocation(locationService.lastKnownPosition!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't use context inside this method as it might cross async gaps
    if (!mounted) return;
    
    // Handle app lifecycle changes to manage location tracking
    final locationService = Provider.of<LocationService>(context, listen: false);
    
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      if (!locationService.isLocationTrackingEnabled) {
        locationService.toggleLocationTracking(true);
      }
    } else if (state == AppLifecycleState.paused) {
      // App is in the background
      if (locationService.isLocationTrackingEnabled) {
        locationService.toggleLocationTracking(false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Update user location and map position
  void _updateUserLocation(Position position) {
    if (!mounted) return;
    
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
      _isLocationLoaded = true;

      // Center map on user location if this is initial load
      if (_mapController.camera.zoom != 0) {
        _mapController.move(_userLocation, _zoomLevel);
      }
    });
  }

  Future<void> _getUserLocation() async {
    try {
      // Store ScaffoldMessenger before async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      // Check for location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        
        // Check if still mounted after async operations
        if (!mounted) return;
        
        if (permission == LocationPermission.denied) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Check if still mounted after async operations
        if (!mounted) return;
        
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Location permissions are permanently denied')),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();
      
      // Check if still mounted after async operations
      if (!mounted) return;
      
      _updateUserLocation(position);
    } catch (e) {
      // Check if still mounted after async operations
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  void _loadObservations() {
    if (_dataLoaded || !mounted) return;
    
    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    // Store a reference to ScaffoldMessenger before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    ObservationService(apiUrl: apiUrl).fetchObservations().then((data) {
      // Check if widget is still mounted before updating state
      if (!mounted) return;
      
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
      });
    }).catchError((error) {
      // Check if widget is still mounted before showing error
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Failed to load observations: $error';
      });
      
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    });
  }

  void _updateCircles() {
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

  @override
  Widget build(BuildContext context) {
    // Use Consumer to rebuild when LocationService updates
    return Consumer<LocationService>(
      builder: (context, locationService, child) {
        // Update position from service if available
        if (locationService.lastKnownPosition != null && !_isLocationLoaded) {
          _updateUserLocation(locationService.lastKnownPosition!);
        }
        
        final activeBirdSounds = locationService.getActiveBirdSounds();
        
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
                  onPositionChanged: (position, bool hasGesture) {
                    if (hasGesture) {
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
      },
    );
  }
}