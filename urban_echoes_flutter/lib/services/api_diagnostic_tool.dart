import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/service_config.dart';

class ApiDiagnosticTool {
  final ServiceConfig _config = ServiceConfig();
  
  Future<void> runDiagnostic({bool debugMode = false}) async {
    final baseUrl = _config.getApiUrl(debugMode);
    
    debugPrint('');
    debugPrint('=== API DIAGNOSTIC REPORT ===');
    debugPrint('Testing base URL: $baseUrl');
    
    // Test health endpoint
    await _testEndpoint(baseUrl, 'health');
    
    // Test observations endpoint
    await _testEndpoint(baseUrl, 'observations');
    
    // Test birds endpoint
    await _testEndpoint(baseUrl, 'birds');
    
    // Test search birds endpoint
    await _testEndpoint(baseUrl, 'search_birds?query=eagle');
    
    debugPrint('=== END DIAGNOSTIC REPORT ===');
    debugPrint('');
  }
  
  Future<void> _testEndpoint(String baseUrl, String endpoint) async {
    try {
      // Handle trailing slashes in base URL
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      
      // Handle leading slashes in endpoint
      final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      
      final url = '$cleanBaseUrl/$cleanEndpoint';
      debugPrint('\nTesting endpoint: $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"error": "Timeout"}', 408),
      );
      
      debugPrint('Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // For successful responses, show a sample of the data
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        
        // If data is too large, just show a summary
        if (decodedBody.length > 1000) {
          if (data is Map) {
            debugPrint('Response keys: ${data.keys.join(', ')}');
            for (var key in data.keys) {
              if (data[key] is List) {
                debugPrint('  $key: ${data[key].length} items');
              } else {
                debugPrint('  $key: ${data[key]}');
              }
            }
          } else if (data is List) {
            debugPrint('Response is a list with ${data.length} items');
          } else {
            debugPrint('Response is a ${data.runtimeType}');
          }
        } else {
          // For small responses, show everything
          debugPrint('Response: $decodedBody');
        }
      } else {
        // For errors, show the status and message
        debugPrint('Error response: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error testing endpoint: $e');
    }
  }
  
  // Add this to your MapPage for easy access
  Widget buildDiagnosticButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: "diagnosticButton",
      mini: true,
      onPressed: () async {
        bool debugMode = false;
        try {
          debugMode = Provider.of<bool>(context, listen: false);
        } catch (e) {
          debugPrint('Error accessing debug mode: $e');
        }
        
        await runDiagnostic(debugMode: debugMode);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('API diagnostic completed - check logs'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      backgroundColor: Colors.purple,
      child: const Icon(Icons.bug_report, color: Colors.white),
    );
  }
}