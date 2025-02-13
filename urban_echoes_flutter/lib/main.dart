import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:urban_echoes/page_state_maneger.dart';

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
  State<MyHomePage> createState() => PageStateManager();
}
