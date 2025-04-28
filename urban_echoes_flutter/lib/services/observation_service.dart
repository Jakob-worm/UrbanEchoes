import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ObservationService {
  final String apiUrl;
  
  // Track the last fetch time
  DateTime _lastFetchTime = DateTime(2000); // Start with old date to fetch everything first time
  
  ObservationService({required this.apiUrl});
  
  /// Process observation data (convert strings to numbers)
  Map<String, dynamic> _processObservation(Map<String, dynamic> observation) {
    final Map<String, dynamic> processed = {...observation};
    
    // Handle latitude and longitude
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
    
    // Process other numeric fields
    ['quantity', 'id'].forEach((field) {
      if (processed.containsKey(field) && processed[field] is String) {
        try {
          processed[field] = double.parse(processed[field]);
        } catch (e) {
          debugPrint("Error parsing $field: ${processed[field]}");
        }
      }
    });
    
    return processed;
  }

  /// Fetch all observations (used on initial load)
  Future<List<Map<String, dynamic>>> fetchObservations() async {
    try {
      debugPrint('Fetching all observations from $apiUrl/observations');
      final response = await http.get(Uri.parse('$apiUrl/observations'));
      
      if (response.statusCode == 200) {
        // Update last fetch time 
        _lastFetchTime = DateTime.now();
        
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        
        List<dynamic> rawObservations = data["observations"];
        debugPrint('Received ${rawObservations.length} observations');
        
        return rawObservations.map((obs) => 
          _processObservation(Map<String, dynamic>.from(obs))
        ).toList();
      } else {
        throw Exception("Failed to load observations (Status ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error fetching observations: $e");
      return [];
    }
  }
  
  /// Fetch only new observations since last fetch
  Future<List<Map<String, dynamic>>> fetchNewObservations() async {
    try {
      // Format timestamp for API query (ISO format)
      final timestamp = _lastFetchTime.toIso8601String();
      debugPrint('Fetching observations added after $timestamp');
      
      final response = await http.get(
        Uri.parse('$apiUrl/observations?after_timestamp=$timestamp')
      );
      
      if (response.statusCode == 200) {
        // Update last fetch time
        _lastFetchTime = DateTime.now();
        
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        
        List<dynamic> rawObservations = data["observations"];
        debugPrint('Received ${rawObservations.length} new observations');
        
        return rawObservations.map((obs) => 
          _processObservation(Map<String, dynamic>.from(obs))
        ).toList();
      } else {
        throw Exception("Failed to fetch new observations (Status ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error fetching new observations: $e");
      return [];
    }
  }
}