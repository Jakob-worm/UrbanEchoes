import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/storage&database/azure_storage_service.dart';

class AudioFileService {
  final AzureStorageService _storageService = AzureStorageService();
  
  // Cache for sound directories
  final Map<String, List<String>> _audioFileCache = {};
  final Map<String, DateTime> _cacheTimes = {};
  final Duration _cacheExpiration = Duration(hours: 1);
  
  // Get audio files for a directory
  Future<List<String>> getAudioFiles(String directory) async {
    // If we have a valid cache, use it
    if (_audioFileCache.containsKey(directory)) {
      final cacheTime = _cacheTimes[directory];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime) < _cacheExpiration) {
        debugPrint('Using cached audio files for: $directory');
        return _audioFileCache[directory]!;
      }
    }
    
    try {
      debugPrint('Fetching audio files for: $directory');
      final files = await _storageService.listFiles(directory);
      
      // Cache the result
      _audioFileCache[directory] = files;
      _cacheTimes[directory] = DateTime.now();
      
      debugPrint('Found ${files.length} files in $directory');
      return files;
    } catch (e) {
      debugPrint('Error fetching audio files: $e');
      // Return empty list on error
      return [];
    }
  }
  
  // Clear cache
  void clearCache() {
    _audioFileCache.clear();
    _cacheTimes.clear();
    debugPrint('Audio file cache cleared');
  }
}