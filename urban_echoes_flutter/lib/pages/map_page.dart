import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Map<String, dynamic>> observations = [];
  List<CircleMarker> circles = [];
  final AudioPlayer _audioPlayer = AudioPlayer();

  Color getObservationColor(Map<String, dynamic> obs) {
    bool isTestData = obs["is_test_data"];
    return isTestData ? Colors.red : Colors.blue;
  }

  @override
  void initState() {
    final bool debugMode = Provider.of<bool>(context, listen: false);
    super.initState();
    fetchObservations(debugMode);
  }

  Future<void> fetchObservations(bool debugMode) async {
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        final List<dynamic> fetchedObservations = data["observations"];

        setState(() {
          observations = fetchedObservations.map((obs) {
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
              color: getObservationColor(obs).withValues(
                alpha: 30,
              ),
              borderColor: getObservationColor(obs).withValues(alpha: 70),
              borderStrokeWidth: 2,
            );
          }).toList();
        });
      } else {
        throw Exception("Failed to load observations");
      }
    } catch (e) {
      print("Error fetching observations: $e");
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
            children: [
              Text("Scientific Name: ${observation["scientific_name"]}"),
              Text("Date: ${observation["observation_date"]}"),
              Text("Time: ${observation["observation_time"]}"),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _playSound(observation["sound_url"]),
                child: const Text("Play Bird Sound"),
              ),
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

  void _playSound(String soundUrl) async {
    try {
      await _audioPlayer.play(UrlSource(soundUrl));
    } catch (e) {
      print("Error playing sound: $e");
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
}
