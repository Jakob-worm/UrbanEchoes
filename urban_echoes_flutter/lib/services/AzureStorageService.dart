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
      // Ensure the service is initialized
      if (!_initialized || _storage == null) {
        if (!await initialize()) {
          debugPrint(
              'Cannot list files: Azure Storage Service initialization failed');
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

      // Make the HTTP request
      final response = await http.get(listUrl);

      if (response.statusCode != 200) {
        debugPrint('Failed to list blobs: HTTP ${response.statusCode}');
        return [];
      }

      // Parse XML response
      try {
        final document = xml.XmlDocument.parse(response.body);
        final blobs = document.findAllElements('Blob');

        List<String> fileUrls = [];
        for (final blob in blobs) {
          final blobName = blob.findElements('Name').first.innerText;

          if (!blobName.endsWith('/')) {
            fileUrls.add(
                'https://$_storageAccountName.blob.core.windows.net/$containerName/$blobName');
          }
        }

        debugPrint('Found ${fileUrls.length} files in $folderPath');
        debugPrint('Found $fileUrls in $folderPath');
        return fileUrls;
      } catch (xmlError) {
        debugPrint('Error parsing XML response: $xmlError');
        return [];
      }
    } catch (e) {
      debugPrint('Error listing files in $folderPath: $e');
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
      return url;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload audio data directly from memory
  Future<String> uploadAudioData(Uint8List audioData, String fileName,
      {String? folder}) async {
    try {
      // Ensure the service is initialized
      if (!_initialized || _storage == null) {
        bool success = await initialize();
        if (!success || _storage == null) {
          throw Exception('Azure Storage Service initialization failed');
        }
      }

      // Format folder name - convert spaces to underscores
      String? formattedFolder = folder;
      if (folder != null) {
        formattedFolder = folder.replaceAll(' ', '_');
      }

      // Create blob name with folder if provided
      final String blobName = formattedFolder != null
          ? '$formattedFolder/${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _storage!.putBlob(
        '/$_containerName/$blobName',
        bodyBytes: audioData,
        contentType: _getContentType(fileName),
      );

      final url =
          'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName';
      debugPrint('Audio data uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('Error uploading audio data: $e');
      throw Exception('Failed to upload audio data: $e');
    }
  }

  // Helper methods remain the same
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

  int min(int a, int b) => a < b ? a : b;
}
