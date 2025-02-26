import 'dart:io';
import 'dart:math';
import 'package:urban_echoes/models/BirdObservation.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';
import 'package:urban_echoes/services/DatabaseService.dart';
import 'package:urban_echoes/services/bird_sound_player.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';

class BirdObservationController {
  final DatabaseService _databaseService = DatabaseService();
  final AzureStorageService _storageService = AzureStorageService();
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();
  final Location _location = Location();

  bool _initialized = false;

  // Initialize all required services
  Future<void> initialize() async {
    try {
      if (!_initialized) {
        await _databaseService.initialize();
        await _storageService.initialize();
        _initialized = true;
        print('BirdObservationController initialized successfully');
      }
    } catch (e) {
      print('Error initializing BirdObservationController: $e');
      // Don't rethrow - we want to fail gracefully
    }
  }

  void dispose() {
    try {
      _databaseService.closeConnection();
      _soundPlayer.dispose();
      print('BirdObservationController disposed');
    } catch (e) {
      print('Error disposing BirdObservationController: $e');
    }
  }

  // Play bird sound based on the scientific name
  Future<void> playBirdSound(String scientificName) async {
    try {
      await _soundPlayer.playSound(scientificName);
    } catch (e) {
      print('Error playing sound: $e');
      // Don't rethrow - non-critical error
    }
  }

  // Submit a bird observation with an optional sound file
  Future<bool> submitObservation(
      String birdName, String scientificName, int quantity,
      {File? soundFile}) async {
    try {
      print('Submitting observation for $birdName ($scientificName)');
      await initialize();

      // Get current location
      LocationData locationData;
      try {
        locationData = await _getCurrentLocation();
        print(
            'Location obtained: ${locationData.latitude}, ${locationData.longitude}');
      } catch (e) {
        print('Error getting location: $e');
        // Use default location if failed
        locationData = LocationData.fromMap({
          'latitude': 0.0,
          'longitude': 0.0,
          'accuracy': 0.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0
        });
      }

      // Check if sound files exist for this bird species and either upload or select existing
      String? soundUrl;
      if (scientificName.isNotEmpty) {
        try {
          final String folderPath = 'bird-sound/$scientificName';
          print('Checking for existing sound files in $folderPath');

          // First check if any sound files exist for this species
          final List<String> existingSoundUrls =
              await _storageService.listFiles(folderPath);

          if (existingSoundUrls.isNotEmpty) {
            // Randomly select one of the existing sound files
            final random = Random();
            soundUrl =
                existingSoundUrls[random.nextInt(existingSoundUrls.length)];
            print('Using existing sound file: $soundUrl');
          } else if (soundFile != null) {
            print('No existing sound files found. Uploading new file');
            // No existing sound files, upload the new one
            soundUrl =
                await _storageService.uploadFile(soundFile, folder: folderPath);
            print('Uploaded new sound file: $soundUrl');
          } else {
            print('No sound file provided and no existing files found');
          }
        } catch (e) {
          print('Error handling sound files: $e');
          // Continue without sound URL if there's an error
        }
      }

      // Create observation object
      final now = DateTime.now();
      final observation = BirdObservation(
        birdName: birdName,
        scientificName: scientificName,
        soundUrl: soundUrl,
        latitude: locationData.latitude ?? 0.0,
        longitude: locationData.longitude ?? 0.0,
        observationDate: now,
        observationTime: DateFormat('HH:mm:ss').format(now),
        observerId: null, // Update with authentication logic
        quantity: quantity,
      );

      print('Saving observation to database');
      // Save observation to database
      final id = await _databaseService.addBirdObservation(observation);

      if (id > 0) {
        print('$birdName ($quantity) recorded successfully with ID: $id');

        // Play the bird sound if available
        if (scientificName.isNotEmpty) {
          try {
            await playBirdSound(scientificName);
          } catch (e) {
            print('Non-critical error playing sound: $e');
          }
        } else {
          print('Warning: No scientific name found for $birdName');
        }

        return true;
      } else {
        print('Failed to record observation - database returned ID $id');
        return false;
      }
    } catch (e) {
      print('Critical error submitting observation: $e');
      return false;
    }
  }

  // Get current location
  Future<LocationData> _getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    try {
      serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        print('Location service not enabled, requesting...');
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          throw Exception('Location service disabled by user');
        }
      }

      permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        print('Location permission denied, requesting...');
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission not granted by user');
        }
      }

      print('Getting current location...');
      return await _location.getLocation();
    } catch (e) {
      print('Error in _getCurrentLocation: $e');
      rethrow;
    }
  }

  // Fetch all recorded observations
  Future<List<BirdObservation>> getAllObservations() async {
    try {
      await initialize();
      return await _databaseService.getAllBirdObservations();
    } catch (e) {
      print('Error getting all observations: $e');
      return []; // Return empty list on error
    }
  }
}
