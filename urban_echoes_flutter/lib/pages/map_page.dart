import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Define a list of CircleMarker objects
    final List<CircleMarker> circles = [
      CircleMarker(
        point: LatLng(56.177839, 10.216839), // First circle center
        radius: 50,
        useRadiusInMeter: true,
        color: Colors.red
            .withAlpha((0.3 * 255).toInt()), // Convert opacity to 0-255 scale
        borderColor: Colors.red.withAlpha((0.7 * 255).toInt()),
        borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: LatLng(56.179839, 10.218839), // Second circle center
        radius: 100,
        useRadiusInMeter: true,
        color: Colors.blue.withAlpha((0.3 * 255).toInt()),
        borderColor: Colors.blue.withAlpha((0.7 * 255).toInt()),
        borderStrokeWidth: 2,
      ),
      CircleMarker(
        point: LatLng(56.180839, 10.220839), // Third circle center
        radius: 150,
        useRadiusInMeter: true,
        color: Colors.green.withAlpha((0.3 * 255).toInt()),
        borderColor: Colors.green.withAlpha((0.7 * 255).toInt()),
        borderStrokeWidth: 2,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: LatLng(56.177839, 10.216839)),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              CircleLayer(
                circles: circles, // Pass the list of circles here
              ),
            ],
          ),
        ],
      ),
    );
  }
}
