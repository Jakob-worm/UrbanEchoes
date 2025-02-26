import 'dart:io';
import 'dart:typed_data';
import 'package:azblob/azblob.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class AzureStorageService {
  late String _storageAccountName;
  late String _containerName;
  late String _sasToken;
  late AzureStorage _storage;

  // Singleton pattern
  static final AzureStorageService _instance = AzureStorageService._internal();

  factory AzureStorageService() {
    return _instance;
  }

  AzureStorageService._internal();

  Future<void> initialize() async {
    _storageAccountName = dotenv.env['AZURE_STORAGE_ACCOUNT'] ?? '';
    _containerName = dotenv.env['AZURE_STORAGE_CONTAINER'] ?? 'bird-sounds';
    _sasToken = dotenv.env['AZURE_STORAGE_SAS_TOKEN'] ?? '';

    if (_storageAccountName.isEmpty || _sasToken.isEmpty) {
      throw Exception('Azure Storage credentials are missing');
    }

    _storage = AzureStorage.parse(
        "https://$_storageAccountName.blob.core.windows.net$_sasToken");
  }

  // Upload a file to Azure Storage
  Future<String> uploadFile(File file, {String? customFileName}) async {
    try {
      final fileName = customFileName ?? path.basename(file.path);
      final blobName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final stream = file.openRead();

      await _storage.putBlob(
        '/$_containerName/$blobName',
        bodyBytes: await file.readAsBytes(),
        contentType: _getContentType(fileName),
      );

      final url =
          'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName$_sasToken';
      print('File uploaded: $url');
      return url;
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload audio data directly from memory
  Future<String> uploadAudioData(Uint8List audioData, String fileName) async {
    try {
      final blobName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _storage.putBlob(
        '/$_containerName/$blobName',
        bodyBytes: audioData,
        contentType: _getContentType(fileName),
      );

      final url =
          'https://$_storageAccountName.blob.core.windows.net/$_containerName/$blobName$_sasToken';
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
}
