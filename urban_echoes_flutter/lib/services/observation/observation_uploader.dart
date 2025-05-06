import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:urban_echoes/models/bird_observation.dart';
import 'package:urban_echoes/services/observation/observation_service.dart';
import 'package:urban_echoes/services/observation/upload_notification_service.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/storage&database/database_service.dart';

class ObservationUploader extends ChangeNotifier {
  // Constructor
  ObservationUploader({
    required DatabaseService databaseService,
    required ObservationService observationService,
    UploadNotificationService? notificationService,
  }) : _databaseService = databaseService,
       _observationService = observationService,
       _notificationService = notificationService;

  final DatabaseService _databaseService;
  final bool _debugMode = ServiceConfig().debugMode;
  String? _errorMessage;
  bool _isUploading = false;
  final UploadNotificationService? _notificationService;
  final ObservationService _observationService;
  
  // Add tracking variables for duplicate detection
  String? _lastUploadBirdName;
  DateTime? _lastUploadTime;
  bool _processingUpload = false;
  
  // Track active state - always start as active
  bool _isActive = true;

  // Getters
  bool get isUploading => _isUploading;
  String? get errorMessage => _errorMessage;
  
  // For compatibility with existing code checking isDisposed
  bool get isDisposed => !_isActive;

  @override
  void dispose() {
    _logDebug('ObservationUploader dispose called - marking as inactive');
    // We don't call super.dispose() here - this is intentional to keep listeners active
    
    // Mark as inactive, but don't fully dispose
    _isActive = false;
    
    // We still need to notify listeners of the state change
    notifyListeners();
  }

  // Override notifyListeners to check for active state
  @override
  void notifyListeners() {
    // Always notify listeners, even if inactive
    // This ensures that components depending on this uploader still get updates
    super.notifyListeners();
  }

  // Save and upload a bird observation
  Future<BirdObservation?> saveAndUploadObservation(
    String birdName, {
    String? scientificName,
    String? soundDirectory,
    int quantity = 1,
    int observerId = 1,
    DateTime? observationDate,
    String? observationTime,
    int testBatchId = 0,
    bool isTestData = false,
    String? sourceId,
  }) async {
    // If marked inactive, reactivate
    if (!_isActive) {
      _logDebug('Reactivating inactive uploader for new observation');
      _isActive = true;
    }
    
    // Check if this is a duplicate of a very recent upload
    if (_processingUpload) {
      _logDebug('Upload already in progress, ignoring duplicate request');
      return null;
    }
    
    if (_lastUploadBirdName != null && 
        _lastUploadTime != null &&
        DateTime.now().difference(_lastUploadTime!).inSeconds < 5 &&
        _lastUploadBirdName == birdName) {
      _logDebug('Ignoring potential duplicate upload for $birdName (less than 5 seconds since last upload)');
      return null;
    }
    
    // Set tracking variables
    _lastUploadBirdName = birdName;
    _lastUploadTime = DateTime.now();
    _processingUpload = true;
    
    try {
      _isUploading = true;
      _errorMessage = null;
      notifyListeners();
      
      _logDebug('Saving and uploading observation for bird: $birdName');
      
      // If scientific name is not provided, look it up from the birds database
      String finalScientificName = scientificName ?? '';
      if (finalScientificName.isEmpty) {
        final bird = await _databaseService.getBirdByCommonName(birdName);
        if (bird != null) {
          finalScientificName = bird.scientificName;
          _logDebug('Found scientific name: $finalScientificName for $birdName');
        } else {
          _logDebug('No scientific name found for $birdName');
        }
      }
      
      // Generate sound directory if not provided
      String finalSoundDirectory = soundDirectory ?? '';
      if (finalSoundDirectory.isEmpty && finalScientificName.isNotEmpty) {
        finalSoundDirectory = _generateSoundDirectory(finalScientificName);
        _logDebug('Generated sound directory: $finalSoundDirectory');
      }
      
      // 1. Get current location
      Position position = await _getCurrentLocation();
      
      // 2. Create BirdObservation object
      BirdObservation observation = await _createBirdObservation(
        birdName: birdName,
        scientificName: finalScientificName,
        soundDirectory: finalSoundDirectory,
        latitude: position.latitude,
        longitude: position.longitude,
        quantity: quantity,
        observerId: observerId,
        observationDate: observationDate,
        observationTime: observationTime,
        isTestData: isTestData,
        testBatchId: testBatchId,
        sourceId: sourceId,
      );
      
      // 3. Save to local database
      int observationId = await _databaseService.addBirdObservation(observation);
      _logDebug('Saved observation to local database with ID: $observationId');
      
      // Create a copy with the database ID
      observation = observation.copyWith(id: observationId);
      
      // 4. Upload to remote API
      await _uploadObservationToApi(observation);
      _logDebug('Uploaded observation to remote API');
      
      // 5. Show success notification
      if (_notificationService != null) {
        _notificationService!.showSuccessNotification(observation);
      }
      
      return observation;
    } catch (e) {
      _logDebug('Error saving/uploading observation: $e');
      _errorMessage = 'Failed to save observation: $e';
      
      // Show error notification
      if (_notificationService != null) {
        _notificationService!.showErrorNotification(_errorMessage!);
      }
      
      return null;
    } finally {
      // Always reset the flags when done, regardless of success or failure
      _isUploading = false;
      _processingUpload = false;
      notifyListeners();
    }
  }

  // Generate the sound directory path based on scientific name
  String _generateSoundDirectory(String scientificName) {
    if (scientificName.isEmpty) {
      return "";
    }
    
    // Format the scientific name to lowercase and remove any unwanted characters
    String formattedName = scientificName.trim().toLowerCase().replaceAll(' ', '_');
    
    // Return the complete URL pattern
    return "https://urbanechostorage.blob.core.windows.net/bird-sounds/$formattedName";
  }

  // Get the current location
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Get the current position
    return await Geolocator.getCurrentPosition();
  }

  // Create a BirdObservation object
  Future<BirdObservation> _createBirdObservation({
    required String birdName,
    required double latitude,
    required double longitude,
    String scientificName = "",
    String soundDirectory = "",
    int quantity = 1,
    int observerId = 1,
    DateTime? observationDate,
    String? observationTime,
    bool isTestData = false,
    int testBatchId = 0,
    String? sourceId,
  }) async {
    // Get current date and time if not provided
    final now = DateTime.now();
    final date = observationDate ?? now;
    final time = observationTime ?? DateFormat('HH:mm:ss').format(now);
    final source = sourceId ?? "speech_recognition_${now.millisecondsSinceEpoch}";
    
    return BirdObservation(
      birdName: birdName,
      scientificName: scientificName,
      soundDirectory: soundDirectory,
      latitude: latitude,
      longitude: longitude,
      observationDate: date,
      observationTime: time,
      observerId: observerId,
      quantity: quantity,
      isTestData: isTestData,
      testBatchId: testBatchId,
      sourceId: source,
    );
  }

  // Upload observation to remote API
  Future<void> _uploadObservationToApi(BirdObservation observation) async {
    try {
      _logDebug('Uploading observation for ${observation.birdName} (${observation.scientificName}) to API');
      
      // Convert observation to the format expected by your API
      Map<String, dynamic> apiData = {
        'latitude': observation.latitude,
        'longitude': observation.longitude,
        'bird_name': observation.birdName,
        'scientific_name': observation.scientificName,
        'sound_directory': observation.soundDirectory,
        'observation_date': DateFormat('yyyy-MM-dd').format(observation.observationDate),
        'observation_time': observation.observationTime,
        'observer_id': observation.observerId,
        'quantity': observation.quantity,
        'is_test_data': observation.isTestData,
        'test_batch_id': observation.testBatchId,
        'source': 'mobile_app',
        'source_id': observation.sourceId,
      };
      
      // Use the ObservationService to upload the data
      bool success = await _observationService.uploadObservation(apiData);
      
      if (!success) {
        _logDebug('API rejected the upload');
        throw Exception('API rejected the upload');
      }
      
      _logDebug('Successfully uploaded observation to remote API');
    } catch (e) {
      _logDebug('Error uploading to API: $e');
      // We don't rethrow here because we want local storage to succeed even if API upload fails
      // The observation is safely stored in local database already
    }
  }

  // Debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      debugPrint('ObservationUploader: $message');
    }
  }
}