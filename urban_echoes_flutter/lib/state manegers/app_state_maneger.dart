import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MyAppState extends ChangeNotifier {
  String backendMessage = "Fetching data...";

  MyAppState() {
    fetchBackendMessage();
  }

  Future<void> fetchBackendMessage() async {
    try {
      final response = await http.get(Uri.parse(
          "https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net"));
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

  String get message => backendMessage;
}
