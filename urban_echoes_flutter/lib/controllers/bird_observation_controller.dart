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
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();
  final Location _location = Location();

  bool _initialized = false;

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
      observerId: null,
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

  Future<String?> _handleSoundFile(
      String scientificName, File? soundFile) async {
    if (scientificName.isEmpty) return null;

    final folderPath =
        'bird-sounds/${scientificName.toLowerCase().replaceAll(' ', '_')}';
    debugPrint('Checking for existing sound files in $folderPath');

    try {
      final connectionString =
          dotenv.env['AZURE_STORAGE_CONNECTION_STRING'] ?? '';
      final storage = AzureStorage.parse(connectionString);

      // List blobs with the folder path prefix
      final response = await storage.getBlob(folderPath);

      // Wait for the response to complete and parse the blob information
      final responseBody = await response.stream.bytesToString();

      // Check if the response is an error (e.g., BlobNotFound)
      if (responseBody.contains('<Code>BlobNotFound</Code>')) {
        debugPrint('BlobNotFound: No blobs found in the folder.');
        return null;
      }

      // Parse the XML response (if it's not an error)
      final document = XmlDocument.parse(responseBody);

      // Extract blob names from XML response (adjust based on actual XML structure)
      final blobs = document.findAllElements('Blob').toList();

      if (blobs.isNotEmpty) {
        debugPrint('Found existing sound files: $blobs');
        // Pick a random file from the list
        return blobs[Random().nextInt(blobs.length)]
            .getElement('Name')
            ?.innerText;
      }

      // If no files are found and a new sound file is provided, upload it
      if (soundFile != null) {
        print('Does not work yet');
        debugPrint('Uploaded new sound file:');
      }
    } catch (e) {
      debugPrint('Error handling sound files: $e');
    }

    return null;
  }

  Future<List<BirdObservation>> getAllObservations() async {
    return (await initialize())
        ? await _databaseService.getAllBirdObservations()
        : [];
  }
}
