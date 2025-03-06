import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';

import '../services/ObservationService .dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Map<String, dynamic>> observations = [];
  List<CircleMarker> circles = [];
  late BirdSoundPlayer _birdSoundPlayer;
  double _noiseGateThreshold = 0.1;

  @override
  void initState() {
    super.initState();
    
    // Initialize BirdSoundPlayer with default noise gate settings
    _birdSoundPlayer = BirdSoundPlayer(
    );

    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';
    
    ObservationService(apiUrl: apiUrl).fetchObservations().then((data) {
      setState(() {
        observations = data.map((obs) {
          return {
            "id": obs["id"],
            "bird_name": obs["bird_name"],
            "scientific_name": obs["scientific_name"],
            "sound_url": obs["sound_url"],
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
        
        circles = observations.map((obs) {
          return CircleMarker(
            point: LatLng(obs["latitude"], obs["longitude"]),
            radius: 100,
            useRadiusInMeter: true,
            color: getObservationColor(obs).withOpacity(0.3),
            borderColor: getObservationColor(obs).withOpacity(0.7),
            borderStrokeWidth: 2,
          );
        }).toList();
      });
    });
  }

  Color getObservationColor(Map<String, dynamic> obs) {
    bool isTestData = obs["is_test_data"];
    return isTestData ? Colors.red : Colors.blue;
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
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Scientific Name: ${observation["scientific_name"]}"),
                  Text("Date: ${observation["observation_date"]}"),
                  Text("Time: ${observation["observation_time"]}"),
                  const SizedBox(height: 10),
                  // Noise Gate Threshold Slider
                  Slider(
                    value: _noiseGateThreshold,
                    min: 0.01,
                    max: 1.0,
                    divisions: 100,
                    label: 'Noise Gate Threshold: ${(_noiseGateThreshold * 100).toStringAsFixed(2)}%',
                    onChanged: (value) {
                      setState(() {
                        _noiseGateThreshold = value;
                      });
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => _playSound(observation["sound_url"]),
                    child: const Text("Play Bird Sound"),
                  ),
                ],
              );
            },
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

  void _playSound(String soundUrl) {
    try {
      _birdSoundPlayer.playSound(
        soundUrl
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing sound: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(56.177839, 10.216839),
              initialZoom: 12.0,
              onTap: (_, tappedPoint) => _onMapTap(tappedPoint),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              CircleLayer(circles: circles),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _birdSoundPlayer.dispose();
    super.dispose();
  }
}