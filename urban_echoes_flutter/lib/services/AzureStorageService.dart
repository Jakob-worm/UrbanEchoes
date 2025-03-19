import 'dart:io';
import 'dart:typed_data';
import 'package:azblob/azblob.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart' as xml;

class AzureStorageService {
  String? _storageAccountName;
  String? _containerName;
  AzureStorage? _storage;

  bool _initialized = false;
  
  // Cache settings
  static const int CACHE_EXPIRATION_MINUTES = 30;
  
  // Response caching
  final Map<String, _CachedResponse> _responseCache = {};
  
  // File listing cache
  final Map<String, _CachedFileList> _fileListCache = {};

  // Singleton pattern
  static final AzureStorageService _instance = AzureStorageService._internal();

  factory AzureStorageService() {
    return _instance;
  }

  AzureStorageService._internal();

  Future<bool> initialize() async {
    try {
      if (_initialized && _storage != null) return true;

      _storageAccountName = dotenv.env['AZURE_STORAGE_ACCOUNT_NAME'] ?? '';
      final connectionString =
          dotenv.env['AZURE_STORAGE_CONNECTION_STRING'] ?? '';

      if (_storageAccountName!.isEmpty || connectionString.isEmpty) {
        debugPrint('Azure Storage credentials are missing');
        return false;
      }

      _storage = AzureStorage.parse(connectionString);

      _initialized = true;
      debugPrint('Azure Storage Service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing Azure Storage Service: $e');
      _initialized = false;
      return false;
    }
  }

  Future<List<String>> listFiles(String folderPath) async {
    try {
      // Check cache first
      if (_fileListCache.containsKey(folderPath)) {
        final cachedData = _fileListCache[folderPath]!;
        if (!cachedData.isExpired()) {
          debugPrint('Using cached file list for $folderPath (${cachedData.files.length} files)');
          return cachedData.files;
        } else {
          // Remove expired cache entry
          _fileListCache.remove(folderPath);
        }
      }
      
      // Ensure the service is initialized
      if (!_initialized || _storage == null) {
        if (!await initialize()) {
          debugPrint('Cannot list files: Azure Storage Service initialization failed');
          return [];
        }
      }

      // Extract the container name and path
      final uri = Uri.parse(folderPath);
      final segments = uri.pathSegments;
      if (segments.isEmpty) {
        debugPrint('Invalid folderPath: $folderPath');
        return [];
      }

      final containerName = segments.first; // e.g., "bird-sounds-test"
      final prefix = segments.length > 1 ? segments.sublist(1).join('/') : '';

      // Azure List Blobs API URL with required parameters
      final listUrl = Uri.parse(
          'https://$_storageAccountName.blob.core.windows.net/$containerName?restype=container&comp=list&prefix=$prefix');

      debugPrint('Listing files from: $listUrl');

      // Check response cache
      final cacheKey = listUrl.toString();
      if (_responseCache.containsKey(cacheKey)) {
        final cachedResponse = _responseCache[cacheKey]!;
        if (!cachedResponse.isExpired()) {
          debugPrint('Using cached HTTP response for $cacheKey');
          return _parseFileListResponse(cachedResponse.data, containerName);
        } else {
          _responseCache.remove(cacheKey);
        }
      }

      // Make the HTTP request with timeout
      final response = await http.get(listUrl)
          .timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out');
      });

      if (response.statusCode != 200) {
        debugPrint('Failed to list blobs: HTTP ${response.statusCode}');
        return [];
      }

      // Cache the response
      _responseCache[cacheKey] = _CachedResponse(
        data: response.body,
        timestamp: DateTime.now(),
      );

      // Parse and cache the file list
      final fileUrls = _parseFileListResponse(response.body, containerName);
      _fileListCache[folderPath] = _CachedFileList(
        files: fileUrls,
        timestamp: DateTime.now(),
      );

      debugPrint('Found ${fileUrls.length} files in $folderPath');
      return fileUrls;
    } catch (e) {
      debugPrint('Error listing files in $folderPath: $e');
      return [];
    }
  }

  // Extract file parsing into a separate method
  List<String> _parseFileListResponse(String responseBody, String containerName) {
    try {
      final document = xml.XmlDocument.parse(responseBody);
      final blobs = document.findAllElements('Blob');

      List<String> fileUrls = [];
      
      // Keep track of directories we've seen to remove duplicates
      final Set<String> processedDirectories = {};
      
      for (final blob in blobs) {
        final blobName = blob.findElements('Name').first.innerText;

        // Skip directories and files we've already processed
        if (blobName.endsWith('/')) {
          continue;
        }
        
        // Skip if we've already processed this directory
        final directory = path.dirname(blobName);
        if (processedDirectories.contains(directory)) {
          continue;
        }
        
        // Add URL and mark directory as processed
        fileUrls.add(
            'https://$_storageAccountName.blob.core.windows.net/$containerName/$blobName');
      }

      return fileUrls;
    } catch (xmlError) {
      debugPrint('Error parsing XML response: $xmlError');
      return [];
    }
  }

  // Upload a file to Azure Storage with consistent folder naming
  Future<String> uploadFile(File file,
      {String? customFileName, String? folder}) async {
    try {
      // Ensure the service is initialized
      if (!_initialized || _storage == null) {
        bool success = await initialize();
        if (!success || _storage == null) {
          throw Exception('Azure Storage Service initialization failed');
        }
      }

      final fileName = customFileName ?? path.basename(file.path);

      // Format folder name - convert spaces to underscores
      String? formattedFolder = folder;
      if (folder != null) {
        formattedFolder = folder.replaceAll(' ', '_');
      }

      // Create blob name with folder if provided
      final String blobName = formattedFolder != null
          ? '$formattedFolder/${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      debugPrint('Uploading file to $blobName');

      // Read file as bytes before uploading to avoid file access issues
      final bytes = await file.readAsBytes();

      await _storage!.putBlob(
        '/$_containerName/$blobName',
        bodyBytes: bytes,
        contentType: _getContentType(fileName),
      );

      final url =
          'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName';
      debugPrint('File uploaded: $url');
      
      // Clear caches for the affected folder path
      _clearCacheForFolder(formattedFolder);
      
      return url;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // Clear cache for a specific folder
  void _clearCacheForFolder(String? folder) {
    if (folder == null) return;
    
    // Clear file list cache for this folder
    _fileListCache.removeWhere((key, _) => key.contains(folder));
    
    // Clear response cache for this folder
    _responseCache.removeWhere((key, _) => key.contains(folder));
  }

  // Helper methods
  String _getContentType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/m4a';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'application/octet-stream';
    }
  }
}

// Helper class for caching HTTP responses
class _CachedResponse {
  final String data;
  final DateTime timestamp;
  
  _CachedResponse({
    required this.data,
    required this.timestamp,
  });
  
  bool isExpired() {
    return DateTime.now().difference(timestamp).inMinutes > 
      AzureStorageService.CACHE_EXPIRATION_MINUTES;
  }
}

// Helper class for caching file listings
class _CachedFileList {
  final List<String> files;
  final DateTime timestamp;
  
  _CachedFileList({
    required this.files,
    required this.timestamp,
  });
  
  bool isExpired() {
    return DateTime.now().difference(timestamp).inMinutes > 
      AzureStorageService.CACHE_EXPIRATION_MINUTES;
  }
}