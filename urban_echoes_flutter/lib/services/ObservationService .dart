import 'dart:convert';
import 'package:http/http.dart' as http;

class ObservationService {
  final String apiUrl;
  ObservationService({required this.apiUrl});

  Future<List<Map<String, dynamic>>> fetchObservations() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        return List<Map<String, dynamic>>.from(data["observations"]);
      } else {
        throw Exception("Failed to load observations");
      }
    } catch (e) {
      print("Error fetching observations: $e");
      return [];
    }
  }
}
