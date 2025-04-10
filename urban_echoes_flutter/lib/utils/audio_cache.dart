import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AudioCache {
  final Directory appDir;
  final Map<String, String> _cachedFiles = {};
  
  AudioCache(this.appDir);
  
  Future<String> getLocalPath(String url) async {
    // Already cached?
    if (_cachedFiles.containsKey(url)) {
      return _cachedFiles[url]!;
    }
    
    // Create a filename based on URL hash
    final String filename = 'audio_${url.hashCode}.${_getExtension(url)}';
    final String localPath = '${appDir.path}/$filename';
    final File localFile = File(localPath);
    
    // Check if already downloaded
    if (await localFile.exists()) {
      _cachedFiles[url] = localPath;
      return localPath;
    }
    
    // Download the file
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await localFile.writeAsBytes(response.bodyBytes);
        _cachedFiles[url] = localPath;
        return localPath;
      } else {
        throw Exception('Failed to download audio file');
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      rethrow;
    }
  }
  
  String _getExtension(String url) {
    return url.toLowerCase().endsWith('.wav') ? 'wav' : 'mp3';
  }
}