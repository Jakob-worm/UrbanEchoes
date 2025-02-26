import 'dart:io';
import 'package:flutter/material.dart';
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
    if (!_initialized) {
      await _databaseService.initialize();
      await _storageService.initialize(); // Now uses azblob
      _initialized = true;
    }
  }

  void dispose() {
    _databaseService.closeConnection();
    _soundPlayer.dispose();
  }

  // Play bird sound based on the scientific name
  Future<void> playBirdSound(String scientificName) async {
    try {
      await _soundPlayer.playSound(scientificName);
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Submit a bird observation with an optional sound file
  Future<bool> submitObservation(
      String birdName, String scientificName, int quantity,
      {File? soundFile}) async {
    try {
      await initialize();

      // Get current location
      final locationData = await _getCurrentLocation();

      // Upload sound file if provided
      String? soundUrl;
      if (soundFile != null) {
        soundUrl = await _storageService.uploadFile(soundFile);
      }

      // Create observation object
      final now = DateTime.now();
      final observation = BirdObservation(
        birdName: birdName,
        scientificName: scientificName,
        soundUrl: soundUrl,
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        observationDate: now,
        observationTime: DateFormat('HH:mm:ss').format(now),
        observerId: null, // Update with authentication logic
        quantity: quantity,
      );

      // Save observation to database
      final id = await _databaseService.addBirdObservation(observation);

      if (id > 0) {
        print('$birdName ($quantity) recorded successfully.');

        // Play the bird sound if available
        if (scientificName.isNotEmpty) {
          await playBirdSound(scientificName);
        } else {
          print('Warning: No scientific name found for $birdName');
        }

        return true;
      } else {
        print('Failed to record observation.');
        return false;
      }
    } catch (e) {
      print('Error submitting observation: $e');
      return false;
    }
  }

  // Get current location
  Future<LocationData> _getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location service disabled');
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    }

    return await _location.getLocation();
  }

  // Fetch all recorded observations
  Future<List<BirdObservation>> getAllObservations() async {
    await initialize();
    return await _databaseService.getAllBirdObservations();
  }
}
