import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:azblob/azblob.dart';
import 'package:urban_echoes/models/BirdObservation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';
import 'package:urban_echoes/services/DatabaseService.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

class BirdObservationController {
  final DatabaseService _databaseService = DatabaseService();
  bool _initialized = false;
  final Location _location = Location();
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();

  Future<bool> initialize() async {
    if (_initialized) return true;

    debugPrint('Validating environment variables...');
    if (!await _validateEnvironmentVariables()) return false;

    debugPrint('Initializing database service...');
    if (!await _databaseService.initialize()) return false;

    _initialized = true;
    debugPrint('BirdObservationController initialized successfully.');
    return true;
  }

  void dispose() {
    try {
      _databaseService.closeConnection();
      _soundPlayer.dispose();
      debugPrint('BirdObservationController disposed');
    } catch (e) {
      debugPrint('Error disposing BirdObservationController: $e');
    }
  }

  Future<void> playBirdSound(String soundUrl) async {
    try {
      await _soundPlayer.playSound(soundUrl);
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<bool> submitObservation(
      String birdName, String scientificName, int quantity,
      {File? soundFile}) async {
    if (!await initialize()) return false;

    debugPrint('Submitting observation for $birdName ($scientificName)');

    final locationData = await _getCurrentLocationOrDefault();
    final soundUrl = await _handleSoundFile(scientificName, soundFile);

    final observation = BirdObservation(
      birdName: birdName,
      scientificName: scientificName,
      soundUrl: soundUrl,
      latitude: locationData.latitude ?? 0.0,
      longitude: locationData.longitude ?? 0.0,
      observationDate: DateTime.now(),
      observationTime: DateFormat('HH:mm:ss').format(DateTime.now()),
      observerId: 1, //One observerID for now
      quantity: quantity,
    );

    final id = await _databaseService.addBirdObservation(observation);
    if (id > 0) {
      debugPrint('$birdName ($quantity) recorded successfully with ID: $id');
      if (soundUrl != null) await playBirdSound(soundUrl);
      return true;
    }

    debugPrint('Failed to record observation');
    return false;
  }

  Future<List<BirdObservation>> getAllObservations() async {
    return (await initialize())
        ? await _databaseService.getAllBirdObservations()
        : [];
  }

  Future<bool> _validateEnvironmentVariables() async {
    final missingVars = <String>[];

    for (var key in [
      'AZURE_STORAGE_CONNECTION_STRING',
      'DB_HOST',
      'DB_USER',
      'DB_PASSWORD'
    ]) {
      if (dotenv.env[key]?.isEmpty ?? true) missingVars.add(key);
    }

    if (missingVars.isNotEmpty) {
      debugPrint(
          'Missing required environment variables: ${missingVars.join(', ')}');
      return false;
    }
    return true;
  }

  Future<LocationData> _getCurrentLocationOrDefault() async {
    try {
      if (!await _location.serviceEnabled() &&
          !await _location.requestService()) {
        throw Exception('Location service disabled');
      }

      if (await _location.hasPermission() == PermissionStatus.denied &&
          await _location.requestPermission() != PermissionStatus.granted) {
        throw Exception('Location permission denied');
      }

      return await _location.getLocation();
    } catch (e) {
      debugPrint('Error getting location: $e');
      return LocationData.fromMap({'latitude': 0.0, 'longitude': 0.0});
    }
  }

// First, let's create helper functions for each major operation

// Helper function to extract Azure storage information from connection string
Map<String, String> _extractAzureStorageInfo(String connectionString) {
  final accountName = RegExp(r'AccountName=([^;]+)').firstMatch(connectionString)?.group(1) ?? '';
  const containerName = 'bird-sounds'; // Replace with your actual container name or make it configurable
  final baseUrl = 'https://$accountName.blob.core.windows.net/$containerName';
  
  return {
    'accountName': accountName,
    'containerName': containerName,
    'baseUrl': baseUrl,
  };
}

// Helper function to find existing sound files
Future<String?> _findExistingSoundFile(AzureStorage storage, String folderPath, String baseUrl) async {
  try {
    final response = await storage.getBlob(folderPath);
    final responseBody = await response.stream.bytesToString();

    // Check if we have valid blobs
    if (!responseBody.contains('<Code>BlobNotFound</Code>')) {
      // Parse the XML response
      final document = XmlDocument.parse(responseBody);
      final blobs = document.findAllElements('Blob').toList();

      if (blobs.isNotEmpty) {
        debugPrint('Found ${blobs.length} existing sound files');
        // Pick a random file from the list
        final selectedBlob = blobs[Random().nextInt(blobs.length)];
        final blobName = selectedBlob.findElements('Name').firstOrNull?.innerText;
        
        if (blobName != null) {
          // Get the full URL for the blob
          final blobUrl = "$baseUrl/$blobName";
          debugPrint('Selected sound file: $blobUrl');
          return blobUrl;
        }
      }
    }
  } catch (e) {
    debugPrint('Error checking for existing sound files: $e');
  }
  
  return null;
}

Future<String?> _handleSoundFile(String scientificName, File? soundFile) async {
  if (scientificName.isEmpty) return null;

  final folderPath = 'bird-sounds/${scientificName.toLowerCase().replaceAll(' ', '_')}'; // No trailing slash
  debugPrint('Checking for existing sound files in $folderPath');

  try {
    final connectionString = dotenv.env['AZURE_STORAGE_CONNECTION_STRING'] ?? '';
    final storage = AzureStorage.parse(connectionString);

    // Extract storage info
    final storageInfo = _extractAzureStorageInfo(connectionString);
    final baseUrl = storageInfo['baseUrl'] ?? '';
    final containerName = storageInfo['containerName'] ?? '';

    // Fetch the raw blob list from Azure
    final response = await storage.listBlobsRaw(folderPath);
    final responseBody = await response.stream.bytesToString();

    // Parse XML response
    final document = XmlDocument.parse(responseBody);
    final blobs = document.findAllElements('Blob');

    // Debug: Print all retrieved blob names
    blobs.forEach((blob) {
      final name = blob.findElements('Name').first.innerText;
      debugPrint('Found Blob: $name');
    });

    final mp3Files = blobs
    .map((blob) => blob.findElements('Name').first.innerText)
    .where((name) => name.toLowerCase().endsWith('.mp3')) // Only check for ".mp3"
    .toList();

  if (mp3Files.isNotEmpty) {
    final selectedFile = mp3Files[Random().nextInt(mp3Files.length)];
    final blobUrl = '$baseUrl/$containerName/$selectedFile'; // Ensure correct URL format

    debugPrint('Selected sound file: $blobUrl');
    return blobUrl;
  }


    debugPrint('No existing MP3 files found for $scientificName');
  } catch (e) {
    debugPrint('Error handling sound files: $e');
  }

  return null;
}
}
