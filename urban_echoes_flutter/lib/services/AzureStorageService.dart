import 'dart:io';
import 'dart:typed_data';
import 'package:azblob/azblob.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart' as xml;

class AzureStorageService {
  late String _storageAccountName;
  late String _containerName;
  late String _sasToken;
  late AzureStorage _storage;

  bool _initialized = false;

  // Singleton pattern
  static final AzureStorageService _instance = AzureStorageService._internal();

  factory AzureStorageService() {
    return _instance;
  }

  AzureStorageService._internal();

  Future<void> initialize() async {
    try {
      if (_initialized) return;

      _storageAccountName = dotenv.env['AZURE_STORAGE_ACCOUNT'] ?? '';
      _containerName = dotenv.env['AZURE_STORAGE_CONTAINER'] ?? 'bird-sounds';
      _sasToken = dotenv.env['AZURE_STORAGE_SAS_TOKEN'] ?? '';

      if (_storageAccountName.isEmpty || _sasToken.isEmpty) {
        throw Exception('Azure Storage credentials are missing');
      }

      _storage = AzureStorage.parse(
          "https://$_storageAccountName.blob.core.windows.net$_sasToken");

      _initialized = true;
      print('Azure Storage Service initialized successfully');
    } catch (e) {
      print('Error initializing Azure Storage Service: $e');
      // Don't rethrow - we want to fail gracefully
      _initialized = false;
    }
  }

  // Modified listFiles method to be more robust
  Future<List<String>> listFiles(String folderPath) async {
    try {
      // Ensure the service is initialized
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          print(
              'Cannot list files: Azure Storage Service initialization failed');
          return [];
        }
      }

      // Use a safer approach - download blob directly with folder prefix
      List<String> fileUrls = [];

      // Try to get some blobs using a direct HTTP request approach
      try {
        // Make sure SAS token is formatted correctly
        String sasPart = _sasToken;
        if (_sasToken.startsWith('?')) {
          sasPart = _sasToken.substring(1);
        }

        // Create the URL with both restype=container and comp=list
        final listUrl = Uri.parse(
            'https://$_storageAccountName.blob.core.windows.net/$_containerName?restype=container&comp=list&prefix=$folderPath&$sasPart');

        print(
            'Requesting blob list from: ${listUrl.toString().replaceAll(_sasToken, "REDACTED")}');

        final response = await http.get(listUrl);

        if (response.statusCode == 200) {
          // Use the xml package for safer parsing
          try {
            final document = xml.XmlDocument.parse(response.body);
            final blobs = document.findAllElements('Blob');

            for (final blob in blobs) {
              final nameElement = blob.findElements('Name').first;
              final blobName = nameElement.innerText;

              // Skip folders and any blob not in the specified folder
              if (!blobName.endsWith('/') && blobName.startsWith(folderPath)) {
                final blobUrl =
                    'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName';
                fileUrls.add(blobUrl);
              }
            }
          } catch (xmlError) {
            print('Error parsing XML response: $xmlError');
            print(
                'Response body: ${response.body.substring(0, min(100, response.body.length))}...');
          }
        } else {
          print('Failed to list blobs: HTTP ${response.statusCode}');
          print('Response: ${response.body}');
        }
      } catch (httpError) {
        print('HTTP error while listing blobs: $httpError');
      }

      print('Found ${fileUrls.length} files in $folderPath');
      return fileUrls;
    } catch (e) {
      print('Error listing files in $folderPath: $e');
      return [];
    }
  }

  // Upload a file to Azure Storage with optional folder path
  Future<String> uploadFile(File file,
      {String? customFileName, String? folder}) async {
    try {
      // Ensure the service is initialized
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          throw Exception('Azure Storage Service initialization failed');
        }
      }

      final fileName = customFileName ?? path.basename(file.path);

      // Create blob name with folder if provided
      final String blobName = folder != null
          ? '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      print('Uploading file to $blobName');

      // Read file as bytes before uploading to avoid file access issues
      final bytes = await file.readAsBytes();

      await _storage.putBlob(
        '/$_containerName/$blobName',
        bodyBytes: bytes,
        contentType: _getContentType(fileName),
      );

      final url =
          'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName';
      print('File uploaded: $url');
      return url;
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload audio data directly from memory
  Future<String> uploadAudioData(Uint8List audioData, String fileName,
      {String? folder}) async {
    try {
      // Ensure the service is initialized
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          throw Exception('Azure Storage Service initialization failed');
        }
      }

      // Create blob name with folder if provided
      final String blobName = folder != null
          ? '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName'
          : '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _storage.putBlob(
        '/$_containerName/$blobName',
        bodyBytes: audioData,
        contentType: _getContentType(fileName),
      );

      final url =
          'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName';
      print('Audio data uploaded: $url');
      return url;
    } catch (e) {
      print('Error uploading audio data: $e');
      throw Exception('Failed to upload audio data: $e');
    }
  }

  // Download a file from Azure Storage
  Future<File> downloadFile(String blobUrl, String localPath) async {
    try {
      // Ensure the service is initialized
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          throw Exception('Azure Storage Service initialization failed');
        }
      }

      final uri = Uri.parse(blobUrl);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading file: $e');
      throw Exception('Failed to download file: $e');
    }
  }

  // Delete a file from Azure Storage
  Future<void> deleteFile(String blobUrl) async {
    try {
      // Ensure the service is initialized
      if (!_initialized) {
        await initialize();
        if (!_initialized) {
          throw Exception('Azure Storage Service initialization failed');
        }
      }

      final uri = Uri.parse(blobUrl);
      final blobName = uri.pathSegments.last;

      await _storage.deleteBlob('/$_containerName/$blobName');
      print('File deleted: $blobName');
    } catch (e) {
      print('Error deleting file: $e');
      throw Exception('Failed to delete file: $e');
    }
  }

  // Helper method to determine content type
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

  // Utility method for min value
  int min(int a, int b) => a < b ? a : b;
}
