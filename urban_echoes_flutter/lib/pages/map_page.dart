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

  // Quantity-based color mapping
  final Map<int, Color> quantityColorMap = {
    1: Colors.blue,
    2: Colors.green,
    3: Colors.yellow,
    4: Colors.orange,
    5: Colors.red,
    6: Colors.purple,
    7: Colors.brown,
    8: Colors.pink,
    9: Colors.teal,
    10: Colors.black,
  };

  Color getQuantityColor(int quantity) {
    return quantityColorMap[quantity] ??
        Colors.grey; // Default if quantity > 10
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
        final decodedBody =
            utf8.decode(response.bodyBytes); // Ensure UTF-8 decoding
        final data = json.decode(decodedBody);

        final List<dynamic> fetchedObservations = data["observations"];

        setState(() {
          observations = fetchedObservations.map((obs) {
            return {
              "latitude": obs["latitude"],
              "longitude": obs["longitude"],
              "bird_name": obs["bird_name"],
              "scientific_name": obs["scientific_name"],
              "observation_date": obs["observation_date"],
              "observation_time": obs["observation_time"],
              "sound_url": obs["sound_url"],
              "quantity": obs["quantity"], // Add quantity field
            };
          }).toList();

          circles = observations.map((obs) {
            return CircleMarker(
              point: LatLng(obs["latitude"], obs["longitude"]),
              radius: 100,
              useRadiusInMeter: true,
              color: getQuantityColor(obs["quantity"]).withOpacity(0.3),
              borderColor: getQuantityColor(obs["quantity"]).withOpacity(0.7),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(56.177839, 10.216839),
              initialZoom: 12.0,
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
