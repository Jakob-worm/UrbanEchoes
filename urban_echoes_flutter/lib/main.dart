import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String> fetchBackendMessage() async {
    final response = await http.get(Uri.parse(
        "urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net"));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      return "Error: ${response.statusCode}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Urban Echoes")),
        body: Center(
          child: FutureBuilder<String>(
            future: fetchBackendMessage(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text("Error: ${snapshot.error}");
              } else {
                return Text(snapshot.data ?? "No data");
              }
            },
          ),
        ),
      ),
    );
  }
}
