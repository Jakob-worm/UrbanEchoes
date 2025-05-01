import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ObservationService {
  final String apiUrl;
  
  // Store observations we've already seen (by ID)
  final Set<int> _knownObservationIds = {};
  
  ObservationService({required this.apiUrl});
  
  /// Process observation data (handle type conversions safely)
  Map<String, dynamic> _processObservation(Map<String, dynamic> observation) {
    final Map<String, dynamic> processed = {...observation};
    
    // Safely convert to double
    void safeConvertToDouble(String key) {
      if (processed.containsKey(key)) {
        try {
          if (processed[key] is String) {
            processed[key] = double.parse(processed[key]);
          }
        } catch (e) {
          debugPrint("Error parsing $key: ${processed[key]} - ${e.toString()}");
        }
      }
    }
    
    // Safely convert to int
    void safeConvertToInt(String key) {
      if (processed.containsKey(key)) {
        try {
          if (processed[key] is String) {
            processed[key] = int.parse(processed[key]);
          } else if (processed[key] is double) {
            processed[key] = processed[key].toInt();
          }
        } catch (e) {
          debugPrint("Error parsing $key to int: ${processed[key]} - ${e.toString()}");
        }
      }
    }
    
    // Convert location coordinates to double
    safeConvertToDouble('latitude');
    safeConvertToDouble('longitude');
    
    // Convert id and quantity to int
    safeConvertToInt('id');
    safeConvertToInt('quantity');
    safeConvertToInt('observer_id');
    
    return processed;
  }

  /// Construct proper endpoint URL
  String _getEndpointUrl(String endpoint) {
    // Handle trailing slashes in base URL
    final baseUrl = apiUrl.endsWith('/') ? apiUrl.substring(0, apiUrl.length - 1) : apiUrl;
    
    // Handle leading slashes in endpoint
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    
    return '$baseUrl/$cleanEndpoint';
  }

  /// Fetch all observations
  Future<List<Map<String, dynamic>>> fetchObservations() async {
    try {
      // Construct the proper URL with the observations endpoint
      final url = _getEndpointUrl('observations');
      debugPrint('Fetching all observations from $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        
        List<dynamic> rawObservations = data["observations"] ?? [];
        debugPrint('Received ${rawObservations.length} observations');
        
        final processedObservations = rawObservations.map((obs) => 
          _processObservation(Map<String, dynamic>.from(obs))
        ).toList();
        
        // Update our known observation IDs
        for (var obs in processedObservations) {
          if (obs.containsKey('id') && obs['id'] is int) {
            _knownObservationIds.add(obs['id']);
          }
        }
        
        return processedObservations;
      } else {
        throw Exception("Failed to load observations (Status ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("Error fetching observations: $e");
      return [];
    }
  }
  
  /// Fetch only new observations (by comparing with previously seen IDs)
  Future<List<Map<String, dynamic>>> fetchNewObservations() async {
    try {
      // Until your API supports after_timestamp, we'll fetch all and filter
      final allObservations = await fetchObservations();
      
      // Filter out observations we've already seen
      final newObservations = allObservations.where((obs) {
        if (!obs.containsKey('id') || obs['id'] is! int) return false;
        
        // Check if this is a new observation
        final isNew = !_knownObservationIds.contains(obs['id']);
        
        // Add to known IDs
        if (isNew) {
          _knownObservationIds.add(obs['id']);
        }
        
        return isNew;
      }).toList();
      
      debugPrint('Found ${newObservations.length} new observations out of ${allObservations.length} total');
      return newObservations;
    } catch (e) {
      debugPrint("Error fetching new observations: $e");
      return [];
    }
  }
  
  /// Upload an observation to the API
  Future<bool> uploadObservation(Map<String, dynamic> observationData) async {
    try {
      // Construct the proper URL with the observations endpoint
      final url = _getEndpointUrl('observations');
      debugPrint('Uploading observation to $url');
      debugPrint('Observation data: $observationData');
      
      // Send the POST request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(observationData),
      );
      
      // Check if the request was successful
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Observation uploaded successfully');
        
        // Parse the response
        final decodedBody = utf8.decode(response.bodyBytes);
        final responseData = json.decode(decodedBody);
        debugPrint('API response: $responseData');
        
        // Add the new observation ID to known IDs if it's returned
        if (responseData.containsKey('id') && responseData['id'] is int) {
          _knownObservationIds.add(responseData['id']);
        }
        
        return true;
      } else {
        debugPrint('Failed to upload observation: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading observation: $e');
      return false;
    }
  }
}