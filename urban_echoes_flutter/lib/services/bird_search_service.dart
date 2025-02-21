import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:urban_echoes/exceptions/api_exceptions.dart';
import 'package:urban_echoes/models/bird.dart';

// BirdSearch Service
class BirdSearchService {
  static Future<List<Bird>> searchBirds(String query, bool debugMode) async {
    if (query.isEmpty) return [];

    final String baseUrl = debugMode
        ? 'http://10.0.2.2:8000'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net';

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/search_birds?query=$query'))
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw BirdSearchException('Request timed out after 10 seconds');
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic>? data = json
            .decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
        if (data != null && data.containsKey('birds')) {
          final List<dynamic> birds = data['birds'];
          return birds.map((json) => Bird.fromJson(json)).toList();
        } else {
          throw BirdSearchException('Invalid data format received from server');
        }
      } else if (response.statusCode >= 500) {
        throw BirdSearchException('Server error occurred',
            statusCode: response.statusCode);
      } else if (response.statusCode == 404) {
        throw BirdSearchException('Bird data endpoint not found',
            statusCode: response.statusCode);
      } else {
        throw BirdSearchException('Failed to fetch bird data',
            statusCode: response.statusCode);
      }
    } on FormatException {
      throw BirdSearchException('Invalid response format from server');
    } catch (e) {
      if (e is BirdSearchException) rethrow;
      throw BirdSearchException('Unexpected error: ${e.toString()}');
    }
  }
}
