import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/models/bird_observation.dart';
import 'package:urban_echoes/models/season.dart';
import 'package:urban_echoes/services/season_service.dart';
import 'package:urban_echoes/services/storage&database/database_service.dart';

class EBirdService {
  final String _baseUrl = 'https://api.ebird.org/v2';
  String? _apiKey;
  final DatabaseService _databaseService = DatabaseService();
  final SeasonService _seasonService = SeasonService();

  // Denmark's approximate bounding box
  static const double _denmarkMinLat = 54.5;
  static const double _denmarkMaxLat = 57.8;
  static const double _denmarkMinLng = 8.0;
  static const double _denmarkMaxLng = 13.0;

  // Center points for Denmark regional coverage
  static const List<Map<String, double>> _denmarkRegions = [
    {'lat': 55.676098, 'lng': 12.568337}, // Copenhagen
    {'lat': 56.156361, 'lng': 10.213500}, // Aarhus
    {'lat': 55.403756, 'lng': 10.402370}, // Odense
    {'lat': 57.048820, 'lng': 9.921747}, // Aalborg
    {'lat': 55.708870, 'lng': 9.536310}, // Vejle
    {'lat': 54.910646, 'lng': 9.792154}, // Sønderborg
    {'lat': 55.230833, 'lng': 11.767500}, // Næstved
    {'lat': 55.640000, 'lng': 8.473000} // Esbjerg
  ];

  // Maximum number of days in the past to fetch observations
  static const int _maxDaysBack = 360;

  // Keys for SharedPreferences
  static const String _lastSyncTimeKey = 'ebird_last_sync_time';

  // Singleton pattern
  static final EBirdService _instance = EBirdService._internal();

  factory EBirdService() {
    return _instance;
  }

  EBirdService._internal();

  Future<bool> initialize() async {
    try {
      _apiKey = dotenv.env['EBIRD_API_KEY'];

      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint(
            'eBird API key is missing. Add EBIRD_API_KEY to your .env file');
        return false;
      }

      // Initialize database service
      final dbInitialized = await _databaseService.initialize();
      if (!dbInitialized) {
        debugPrint(
            'Database initialization failed when setting up eBird service');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing eBird service: $e');
      return false;
    }
  }

  // Check and import new observations on app start
  Future<int> syncNewObservationsOnStartup() async {
    try {
      // Initialize the service
      if (!await initialize()) {
        debugPrint('Failed to initialize eBird service');
        return 0;
      }

      // Get last sync time
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTime = prefs.getString(_lastSyncTimeKey);

      // Calculate days back based on last sync time
      int daysBack = 1; // Default to 1 day if synced recently

      if (lastSyncTime != null) {
        final lastSync = DateTime.parse(lastSyncTime);
        final now = DateTime.now();
        final difference = now.difference(lastSync).inDays;

        // Get data for at least the number of days since last sync
        daysBack = difference + 1;

        // Cap at maximum days back
        if (daysBack > _maxDaysBack) {
          daysBack = _maxDaysBack;
        }
      } else {
        // First time syncing, use max days
        daysBack = _maxDaysBack;
      }

      debugPrint('Syncing eBird observations for the last $daysBack days');

      // Use multiple region points to cover all of Denmark
      int totalImported = 0;

      // Import for each region with enough radius to cover Denmark
      for (final region in _denmarkRegions) {
        final count = await importObservationsToDatabase(
          latitude: region['lat']!,
          longitude: region['lng']!,
          radiusKm: 50, // Large enough radius to overlap between regions
          daysBack: daysBack,
          maxResults: 200, // Increased result limit
        );

        totalImported += count;

        // Add a small delay between API calls to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Save the current time as last sync time
      await prefs.setString(_lastSyncTimeKey, DateTime.now().toIso8601String());

      debugPrint('eBird sync complete. Imported $totalImported observations.');
      return totalImported;
    } catch (e) {
      debugPrint('Error syncing eBird observations: $e');
      return 0;
    }
  }

  /// Filters a list of observations by the current season setting
  List<BirdObservation> filterObservationsBySeason(
      List<BirdObservation> observations,
      {Season? overrideSeason}) {
    final seasonToUse = overrideSeason ?? _seasonService.currentSeason;

    // If no filtering needed, return all observations
    if (seasonToUse == Season.all) {
      return observations;
    }

    // Filter observations by season
    return observations.where((observation) {
      final observationSeason =
          _seasonService.getCurrentSeasonForDate(observation.observationDate);
      return observationSeason == seasonToUse;
    }).toList();
  }

  // Add this method to get only the observations for the current season
  Future<List<BirdObservation>> fetchRecentObservationsForCurrentSeason({
    required double latitude,
    required double longitude,
    double radiusKm = 1500,
    int daysBack = 360,
    int maxResults = 3000,
    int observerId = 0,
  }) async {
    // Get all observations first
    final allObservations = await fetchRecentObservations(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      daysBack: daysBack,
      maxResults: maxResults,
      observerId: observerId,
    );

    // Then filter them by the current season
    return filterObservationsBySeason(allObservations);
  }

  // Fetch observations from a specific region using the eBird API
  Future<List<BirdObservation>> fetchRecentObservations({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    int daysBack = 5,
    int maxResults = 100,
    int observerId = 1, // Default observer ID for eBird imports
  }) async {
    try {
      if (_apiKey == null) {
        final initialized = await initialize();
        if (!initialized) {
          throw Exception('Failed to initialize eBird service');
        }
      }

      // Ensure daysBack is within limits
      if (daysBack > _maxDaysBack) {
        daysBack = _maxDaysBack;
      }

      final url = Uri.parse(
          '$_baseUrl/data/obs/geo/recent?lat=$latitude&lng=$longitude&dist=$radiusKm&back=$daysBack&maxResults=$maxResults');

      final response = await http.get(
        url,
        headers: {'X-eBirdApiToken': _apiKey!},
      ).timeout(
        Duration(seconds: 15),
        onTimeout: () => throw Exception('eBird API request timed out'),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch eBird data: ${response.statusCode} ${response.body}');
      }

      final List<dynamic> data = json.decode(response.body);
      final observations = <BirdObservation>[];

      // Track the observations we've already seen to avoid duplicates
      final seenObservations = <String>{};

      for (final obs in data) {
        try {
          // Skip observations outside Denmark
          final lat = obs['lat'] as double;
          final lng = obs['lng'] as double;

          if (!_isInDenmark(lat, lng)) {
            continue;
          }

          // Create a unique key for this observation to avoid duplicates
          final obsKey =
              '${obs['sciName']}_${obs['lat']}_${obs['lng']}_${obs['obsDt']}';
          if (seenObservations.contains(obsKey)) {
            continue;
          }
          seenObservations.add(obsKey);

          // Create bird observation from eBird data
          final observation = _mapEBirdObservation(
            eBirdObs: obs,
            observerId: observerId,
          );

          observations.add(observation);
        } catch (e) {
          debugPrint('Error processing eBird observation: $e');
          // Continue with next observation
        }
      }

      return observations;
    } catch (e) {
      debugPrint('Error fetching eBird observations: $e');
      return [];
    }
  }

  // Import observations to database
  Future<int> importObservationsToDatabase({
    required double latitude,
    required double longitude,
    double radiusKm = 25,
    int daysBack = 5,
    int maxResults = 100,
    int observerId = 0,
  }) async {
    try {
      final observations = await fetchRecentObservations(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        daysBack: daysBack,
        maxResults: maxResults,
        observerId: observerId,
      );

      if (observations.isEmpty) {
        debugPrint('No new observations found in this region');
        return 0;
      }

      int importedCount = 0;

      // Get existing observations from the database to avoid duplicates
      final existingObservations =
          await _databaseService.getAllBirdObservations();
      final existingKeys = existingObservations
          .map((obs) =>
              '${obs.scientificName}_${obs.latitude}_${obs.longitude}_${obs.observationDate.toIso8601String().split('T')[0]}')
          .toSet();

      for (final observation in observations) {
        try {
          // Check if this observation already exists
          final obsKey =
              '${observation.scientificName}_${observation.latitude}_${observation.longitude}_${observation.observationDate.toIso8601String().split('T')[0]}';
          if (existingKeys.contains(obsKey)) {
            // Skip duplicate observation
            continue;
          }

          await _databaseService.addBirdObservation(observation);
          importedCount++;
        } catch (e) {
          debugPrint('Error saving eBird observation to database: $e');
          // Continue with next observation
        }
      }

      return importedCount;
    } catch (e) {
      debugPrint('Error importing eBird observations: $e');
      return 0;
    }
  }

  // Check if coordinates are within Denmark
  bool _isInDenmark(double lat, double lng) {
    return lat >= _denmarkMinLat &&
        lat <= _denmarkMaxLat &&
        lng >= _denmarkMinLng &&
        lng <= _denmarkMaxLng;
  }

  // Map eBird observation to BirdObservation model
  BirdObservation _mapEBirdObservation({
    required Map<String, dynamic> eBirdObs,
    required int observerId,
  }) {
    // Extract date and time from eBird's obsDate (format: YYYY-MM-DD HH:MM)
    final obsDateString = eBirdObs['obsDt'] as String;
    DateTime observationDate;
    String observationTime = '00:00:00';

    if (obsDateString.contains(' ')) {
      final parts = obsDateString.split(' ');
      observationDate = DateTime.parse(parts[0]);

      // If time is provided, format it properly
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        if (timeParts.length == 2) {
          observationTime = '${parts[1]}:00';
        } else {
          observationTime = parts[1];
        }
      }
    } else {
      observationDate = DateTime.parse(obsDateString);
    }

    // Convert scientific name to directory format
    final scientificName = eBirdObs['sciName'] as String;
    final soundDirectory = _formatSoundDirectory(scientificName);

    return BirdObservation(
      birdName: eBirdObs['comName'] as String,
      scientificName: scientificName,
      soundDirectory: soundDirectory,
      latitude: eBirdObs['lat'] as double,
      longitude: eBirdObs['lng'] as double,
      observationDate: observationDate,
      observationTime: observationTime,
      observerId: observerId,
      quantity: eBirdObs['howMany'] as int? ?? 1,
      isTestData: false,
      testBatchId: 0,
    );
  }

  // Format scientific name to sound directory
  String _formatSoundDirectory(String scientificName) {
    // Convert "Turdus merula" to "turdus_merula"
    return 'https://urbanechostorage.blob.core.windows.net/bird-sounds/${scientificName.toLowerCase().replaceAll(' ', '_')}';
  }
}
