import 'dart:io';
import 'dart:math';
import 'package:azblob/azblob.dart';
import 'package:urban_echoes/models/bird_observation.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/sound/bird_sound_player.dart';
import 'package:urban_echoes/services/storage&database/database_service.dart';
import 'package:xml/xml.dart';

class BirdObservationController {
  // Constants
  static const String _containerName = 'bird-sounds';

  // Aarhus city center coordinates (for emulator)
  static const double _aarhusLatitude = 56.1629;
  static const double _aarhusLongitude = 10.2039;
  static const double _maxRandomDistance = 0.05; // ~5km radius

  // Required environment variables
  static const List<String> _requiredEnvVars = [
    'AZURE_STORAGE_CONNECTION_STRING',
    'DB_HOST',
    'DB_USER',
    'DB_PASSWORD'
  ];

  // Services
  final DatabaseService _databaseService = DatabaseService();
  final Location _location = Location();
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();

  // State
  bool _initialized = false;

  // Initialization
  Future<bool> initialize() async {
    if (_initialized) return true;

    debugPrint('Validating environment variables...');
    if (!_validateEnvironmentVariables()) return false;

    debugPrint('Initializing database service...');
    if (!await _databaseService.initialize()) return false;

    _initialized = true;
    debugPrint('BirdObservationController initialized successfully.');
    return true;
  }

  // Resource cleanup
  void dispose() {
    try {
      _databaseService.closeConnection();
      _soundPlayer.dispose();
      debugPrint('BirdObservationController disposed');
    } catch (e) {
      debugPrint('Error disposing BirdObservationController: $e');
    }
  }

  // Media playback
  Future<void> playBirdSound(String soundUrl) async {
    try {
      //await _soundPlayer.playRandomSoundFromFolder(soundUrl,100);
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Main functionality
  Future<bool> submitObservation(
      String birdName, String scientificName, int quantity,
      {File? soundFile}) async {
    if (!await initialize()) return false;

    debugPrint('Submitting observation for $birdName ($scientificName)');

    final locationData = await _getCurrentLocation();
    final soundUrl = await _handleSoundFile(scientificName, soundFile);

    final observation = BirdObservation(
      birdName: birdName,
      scientificName: scientificName,
      soundDirectory: soundUrl ?? '',
      latitude: locationData.latitude ?? 0.0,
      longitude: locationData.longitude ?? 0.0,
      observationDate: DateTime.now(),
      observationTime: DateFormat('HH:mm:ss').format(DateTime.now()),
      observerId: 2, // One observerID for now
      quantity: quantity,
      isTestData: false,
      testBatchId: 1, // Example test batch ID
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

  // Helper Methods
  bool _validateEnvironmentVariables() {
    final missingVars = <String>[];

    for (var key in _requiredEnvVars) {
      if (dotenv.env[key]?.isEmpty ?? true) missingVars.add(key);
    }

    if (missingVars.isNotEmpty) {
      debugPrint(
          'Missing required environment variables: ${missingVars.join(', ')}');
      return false;
    }
    return true;
  }

  Future<LocationData> _getCurrentLocation() async {
    // Try to get actual location first, regardless of debug mode
    try {
      if (!await _location.serviceEnabled() &&
          !await _location.requestService()) {
        throw Exception('Location service disabled');
      }

      if (await _location.hasPermission() == PermissionStatus.denied &&
          await _location.requestPermission() != PermissionStatus.granted) {
        throw Exception('Location permission denied');
      }

      // Try to get the actual location first
      final actualLocation = await _location.getLocation();
      if (actualLocation.latitude != null && actualLocation.longitude != null) {
        debugPrint(
            'Using actual location: ${actualLocation.latitude}, ${actualLocation.longitude}');
        return actualLocation;
      }
      throw Exception('Invalid location data received');
    } catch (e) {
      debugPrint(
          'Error getting location: $e, falling back to emulator location');
      // Only use emulator location as a fallback
      return _getEmulatorLocation();
    }
  }

  LocationData _getEmulatorLocation() {
    // Generate random coordinates around Aarhus
    final random = Random();
    final latOffset = (random.nextDouble() * 2 - 1) * _maxRandomDistance;
    final longOffset = (random.nextDouble() * 2 - 1) * _maxRandomDistance;

    final latitude = _aarhusLatitude + latOffset;
    final longitude = _aarhusLongitude + longOffset;

    debugPrint('Using random location around Aarhus: $latitude, $longitude');
    return LocationData.fromMap({'latitude': latitude, 'longitude': longitude});
  }

  Future<String?> _handleSoundFile(
      String scientificName, File? soundFile) async {
    if (scientificName.isEmpty) return null;

    final String folderPath = _formatFolderPath(scientificName);
    debugPrint('Checking for existing sound files in $folderPath');

    try {
      final connectionString =
          dotenv.env['AZURE_STORAGE_CONNECTION_STRING'] ?? '';
      final storage = AzureStorage.parse(connectionString);
      final storageInfo = _extractAzureStorageInfo(connectionString);

      return await _findExistingSoundFile(storage, folderPath, storageInfo);
    } catch (e) {
      debugPrint('Error handling sound files: $e');
      return null;
    }
  }

  String _formatFolderPath(String scientificName) {
    return '$_containerName/${scientificName.toLowerCase().replaceAll(' ', '_')}';
  }

  Map<String, String> _extractAzureStorageInfo(String connectionString) {
    final accountName =
        RegExp(r'AccountName=([^;]+)').firstMatch(connectionString)?.group(1) ??
            '';
    final baseUrl =
        'https://$accountName.blob.core.windows.net/$_containerName';

    return {
      'accountName': accountName,
      'containerName': _containerName,
      'baseUrl': baseUrl,
    };
  }

  Future<String?> _findExistingSoundFile(AzureStorage storage,
      String folderPath, Map<String, String> storageInfo) async {
    try {
      // Fetch the raw blob list from Azure
      final response = await storage.listBlobsRaw(folderPath);
      final responseBody = await response.stream.bytesToString();

      // Parse XML response
      final document = XmlDocument.parse(responseBody);
      final blobs = document.findAllElements('Blob');

      // Filter for MP3 files
      final mp3Files = blobs
          .map((blob) => blob.findElements('Name').first.innerText)
          .where((name) => name.toLowerCase().endsWith('.mp3'))
          .toList();

      if (mp3Files.isNotEmpty) {
        final selectedFile = mp3Files[Random().nextInt(mp3Files.length)];
        final blobUrl = '${storageInfo['baseUrl']}/$selectedFile';

        debugPrint('Selected sound file: $blobUrl');
        return blobUrl;
      }

      debugPrint('No existing MP3 files found for the species');
      return null;
    } catch (e) {
      debugPrint('Error finding existing sound files: $e');
      return null;
    }
  }
}
