import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urban_echoes/services/service_config.dart';

// Interface for location services
abstract class LocationRepositoryInterface {
  Future<bool> requestLocationPermission();
  Future<Position?> getCurrentPosition();
  Future<Position?> getLastKnownPosition();
  Stream<Position> getPositionStream({required double distanceFilter});
  double distanceBetween(double startLat, double startLng, double endLat, double endLng);
  double bearingBetween(double startLat, double startLng, double endLat, double endLng);
}

class LocationRepository implements LocationRepositoryInterface {
  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final ServiceConfig _config = ServiceConfig();

  @override
  Future<bool> requestLocationPermission() async {
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

      // Try requesting "always" permission if not already granted
      if (permission == LocationPermission.whileInUse) {
        if (_config.debugMode) {
          debugPrint('[LocationRepository] We have foreground permission, but not background');
        }
        
        // Try requesting again (might show system dialog for background)
        permission = await Geolocator.requestPermission();
      }

      // Return true even if we only have whileInUse permission
      return true;
    } catch (e) {
      if (_config.debugMode) {
        debugPrint('[LocationRepository] Error requesting location permission: $e');
      }
      // Return true to allow the app to continue
      return true;
    }
  }

  @override
  Future<Position?> getCurrentPosition() async {
    try {
      return await _geolocatorPlatform.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(Duration(seconds: 8));
    } catch (e) {
      if (_config.debugMode) {
        debugPrint('[LocationRepository] Error getting current position: $e');
      }
      return null;
    }
  }

  @override
  Future<Position?> getLastKnownPosition() async {
    try {
      return await _geolocatorPlatform.getLastKnownPosition();
    } catch (e) {
      if (_config.debugMode) {
        debugPrint('[LocationRepository] Error getting last known position: $e');
      }
      return null;
    }
  }

  @override
  Stream<Position> getPositionStream({required double distanceFilter}) {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: distanceFilter.toInt(),
    );

    return _geolocatorPlatform.getPositionStream(
      locationSettings: locationSettings,
    );
  }

  @override
  double distanceBetween(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  @override
  double bearingBetween(double startLat, double startLng, double endLat, double endLng) {
    // Convert to radians
    const double pi = 3.1415926535897932;
    double lat1 = startLat * pi / 180;
    double lng1 = startLng * pi / 180;
    double lat2 = endLat * pi / 180;
    double lng2 = endLng * pi / 180;

    // Calculate bearing
    double y = sin(lng2 - lng1) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lng2 - lng1);
    double bearingRad = atan2(y, x);

    // Convert to degrees
    double bearingDeg = bearingRad * 180 / pi;
    return (bearingDeg + 360) % 360;
  }

  // Convenience method to get fallback position
  Position getFallbackPosition() {
    return Position(
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
  }
}