import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ObservationService {
  final String apiUrl;
  
  ObservationService({required this.apiUrl});
  
  /// Convert string number values to actual numbers
  Map<String, dynamic> _processObservation(Map<String, dynamic> observation) {
    final Map<String, dynamic> processed = {...observation};
    
    // Handle latitude and longitude - the likely source of the error
    if (processed.containsKey('latitude') && processed['latitude'] is String) {
      try {
        processed['latitude'] = double.parse(processed['latitude']);
      } catch (e) {
        debugPrint("Error parsing latitude: ${processed['latitude']}");
      }
    }
    
    if (processed.containsKey('longitude') && processed['longitude'] is String) {
      try {
        processed['longitude'] = double.parse(processed['longitude']);
      } catch (e) {
        debugPrint("Error parsing longitude: ${processed['longitude']}");
      }
    }
    
    // Process other potentially numeric fields that might be strings
    ['distance', 'elevation', 'accuracy'].forEach((field) {
      if (processed.containsKey(field) && processed[field] is String) {
        try {
          processed[field] = double.parse(processed[field]);
        } catch (e) {
          // If parsing fails, keep as string
          debugPrint("Error parsing $field: ${processed[field]}");
        }
      }
    });
    
    return processed;
  }

  Future<List<Map<String, dynamic>>> fetchObservations() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        
        // Extract the observations list and process each one
        List<dynamic> rawObservations = data["observations"];
        return rawObservations.map((obs) => 
          _processObservation(Map<String, dynamic>.from(obs))
        ).toList();
      } else {
        throw Exception("Failed to load observations");
      }
    } catch (e) {
      debugPrint("Error fetching observations: $e");
      return [];
    }
  }
}