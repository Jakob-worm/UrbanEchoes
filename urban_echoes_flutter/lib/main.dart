import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:camera/camera.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Urban Echoes',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String backendMessage = "Fetching data...";

  MyAppState() {
    fetchBackendMessage();
  }

  Future<void> fetchBackendMessage() async {
    try {
      final response = await http.get(Uri.parse(
          "urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net"));
      if (response.statusCode == 200) {
        backendMessage = response.body;
      } else {
        backendMessage = "Error: ${response.statusCode}";
      }
    } catch (e) {
      backendMessage = "Failed to fetch data";
    }
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = HomePage();
        break;
      case 1:
        page = TakeImagePage();
        break;
      case 2:
        page = BackEndTest();
        break;
      default:
        throw UnimplementedError('No widget for $selectedIndex');
    }

    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.camera),
                        label: 'Take image page',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.abc),
                        label: 'Backend Test',
                      )
                    ],
                    currentIndex: selectedIndex,
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 600,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.camera),
                        label: Text('camera'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.abc),
                        label: Text('Backend Test'),
                      )
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

class TakeImagePage extends StatelessWidget {
  const TakeImagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text("Take Image Page"),
    );
  }
}

class BackEndTest extends StatelessWidget {
  const BackEndTest({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Backend Response:"),
          SizedBox(height: 10),
          Text(
            appState.backendMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
