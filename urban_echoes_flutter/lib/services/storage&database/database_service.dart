import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:urban_echoes/models/bird.dart';
import 'package:urban_echoes/models/bird_observation.dart';
import 'package:urban_echoes/models/season.dart';
import 'package:urban_echoes/services/season_service.dart';

class DatabaseService {
  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  late final PostgreSQLConnection _connection;
  bool _isConnected = false;
  final SeasonService _seasonService = SeasonService();

  // Initialize connection (unchanged)
  Future<bool> initialize() async {
    try {
      if (_isConnected) return true;

      return await _createConnection();
    } catch (e) {
      debugPrint('Database initialization failed: $e');
      return false;
    }
  }

  Future<Bird?> getBirdByCommonName(String commonName) async {
  if (commonName.isEmpty) return null;
  
  // Ensure database connection
  bool connected = await _ensureConnection();
  if (!connected) {
    debugPrint('Database connection not available for bird lookup');
    return null;
  }
  
  try {
    // Try exact match first
    final results = await _connection.query(
      '''
      SELECT common_name, scientific_name
      FROM birds
      WHERE common_name = @commonName
      LIMIT 1
      ''',
      substitutionValues: {'commonName': commonName},
    );
    
    if (results.isNotEmpty) {
      return Bird(
        commonName: results.first[0] as String,
        scientificName: results.first[1] as String,
      );
    }
    
    // Try case-insensitive match as fallback
    final fuzzyResults = await _connection.query(
      '''
      SELECT common_name, scientific_name
      FROM birds
      WHERE LOWER(common_name) = LOWER(@commonName)
      LIMIT 1
      ''',
      substitutionValues: {'commonName': commonName},
    );
    
    if (fuzzyResults.isNotEmpty) {
      return Bird(
        commonName: fuzzyResults.first[0] as String,
        scientificName: fuzzyResults.first[1] as String,
      );
    }
    
    debugPrint('No bird found with common name: $commonName');
    return null;
  } catch (e) {
    debugPrint('Error looking up bird by common name: $e');
    return null;
  }
}

  // Connection methods (unchanged)
  Future<void> closeConnection() async {
    if (_isConnected) {
      await _connection.close();
      _isConnected = false;
      debugPrint('Database connection closed');
    }
  }

  // Updated method to add bird observation with sourceId
  Future<int> addBirdObservation(BirdObservation observation) async {
    bool connected = await _ensureConnection();
    if (!connected) {
      throw Exception('Database connection not available');
    }

    try {
      // First check if sourceId exists (for eBird observations)
      if (observation.sourceId != null && observation.sourceId!.isNotEmpty) {
        final existingRecords = await _connection.query(
          'SELECT id FROM bird_observations WHERE source_id = @sourceId',
          substitutionValues: {'sourceId': observation.sourceId},
        );
        
        if (existingRecords.isNotEmpty) {
          debugPrint('Observation with sourceId ${observation.sourceId} already exists, skipping');
          return existingRecords.first[0] as int; // Return existing ID
        }
      }

      final results = await _connection.query(
        '''
        INSERT INTO bird_observations (
          bird_name, 
          scientific_name, 
          sound_directory, 
          latitude, 
          longitude, 
          observation_date, 
          observation_time, 
          observer_id, 
          quantity, 
          is_test_data, 
          test_batch_id,
          source_id
        ) VALUES (
          @birdName, 
          @scientificName, 
          @soundDirectory, 
          @latitude, 
          @longitude, 
          @observationDate, 
          @observationTime, 
          @observerId, 
          @quantity, 
          @isTestData, 
          @testBatchId,
          @sourceId
        ) RETURNING id
        ''',
        substitutionValues: {
          'birdName': observation.birdName,
          'scientificName': observation.scientificName,
          'soundDirectory': observation.soundDirectory,
          'latitude': observation.latitude,
          'longitude': observation.longitude,
          'observationDate': observation.observationDate,
          'observationTime': observation.observationTime,
          'observerId': observation.observerId,
          'quantity': observation.quantity,
          'isTestData': observation.isTestData,
          'testBatchId': observation.testBatchId,
          'sourceId': observation.sourceId,
        },
      );

      if (results.isNotEmpty) {
        return results.first[0] as int;
      } else {
        throw Exception('Failed to insert bird observation');
      }
    } catch (e) {
      debugPrint('Error adding bird observation: $e');
      throw Exception('Error adding bird observation: $e');
    }
  }

  // Updated method to get observations including sourceId
  Future<List<BirdObservation>> getAllBirdObservations({Season? seasonFilter}) async {
    bool connected = await _ensureConnection();
    if (!connected) {
      return [];
    }

    try {
      final results = await _connection.query('''
        SELECT 
          id, 
          bird_name, 
          scientific_name, 
          sound_directory, 
          latitude, 
          longitude, 
          observation_date, 
          observation_time, 
          observer_id, 
          quantity, 
          is_test_data, 
          test_batch_id,
          source_id
        FROM bird_observations 
        ORDER BY created_at DESC
        ''');

      final observations = results
          .map((row) => BirdObservation(
                id: row[0] as int,
                birdName: row[1] as String,
                scientificName: row[2] as String,
                soundDirectory: row[3] as String,
                latitude: (row[4] as num).toDouble(),
                longitude: (row[5] as num).toDouble(),
                observationDate: row[6] as DateTime,
                observationTime: row[7].toString(),
                observerId: row[8] as int,
                quantity: row[9] as int,
                isTestData: row[10] as bool,
                testBatchId: row[11] as int,
                sourceId: row[12] as String?,
              ))
          .toList();

      if (seasonFilter != null && seasonFilter != Season.all) {
        return observations.where((obs) {
          final obsSeason = _seasonService.getCurrentSeasonForDate(obs.observationDate);
          return obsSeason == seasonFilter;
        }).toList();
      } else {
        return observations;
      }
    } catch (e) {
      debugPrint('Error fetching bird observations: $e');
      return [];
    }
  }

  // Other methods (unchanged)
  Future<List<BirdObservation>> getBirdObservationsForCurrentSeason() async {
    final currentSeason = _seasonService.currentSeason;
    return getAllBirdObservations(seasonFilter: currentSeason);
  }

  Future<List<BirdObservation>> getBirdObservationsForSeason(Season season) async {
    return getAllBirdObservations(seasonFilter: season);
  }

  Future<BirdObservation?> getBirdObservationById(int id) async {
  bool connected = await _ensureConnection();
  if (!connected) {
    return null;
  }

  try {
    final results = await _connection.query('''
      SELECT 
        id, 
        bird_name, 
        scientific_name, 
        sound_directory, 
        latitude, 
        longitude, 
        observation_date, 
        observation_time, 
        observer_id, 
        quantity, 
        is_test_data, 
        test_batch_id,
        source_id
      FROM bird_observations 
      WHERE id = @id
      ''',
      substitutionValues: {'id': id},
    );

    if (results.isEmpty) {
      return null;
    }

    final row = results.first;
    return BirdObservation(
      id: row[0] as int,
      birdName: row[1] as String,
      scientificName: row[2] as String,
      soundDirectory: row[3] as String,
      latitude: (row[4] as num).toDouble(),
      longitude: (row[5] as num).toDouble(),
      observationDate: row[6] as DateTime,
      observationTime: row[7].toString(),
      observerId: row[8] as int,
      quantity: row[9] as int,
      isTestData: row[10] as bool,
      testBatchId: row[11] as int,
      sourceId: row[12] as String?,
    );
  } catch (e) {
    debugPrint('Error fetching bird observation by ID: $e');
    return null;
  }
}

  // New method to clean up duplicate observations in database
  Future<int> cleanupDuplicateObservations() async {
    bool connected = await _ensureConnection();
    if (!connected) {
      return 0;
    }
    
    try {
      // First handle observations with source_id (keep only one record for each source_id)
      await _connection.query('''
        WITH duplicates AS (
          SELECT id, source_id, 
            ROW_NUMBER() OVER (PARTITION BY source_id ORDER BY created_at) as row_num
          FROM bird_observations
          WHERE source_id IS NOT NULL AND source_id != ''
        )
        DELETE FROM bird_observations
        WHERE id IN (
          SELECT id FROM duplicates WHERE row_num > 1
        )
      ''');
      
      // Then handle observations without source_id based on composite key
      final results = await _connection.query('''
        WITH duplicates AS (
          SELECT id,
            ROW_NUMBER() OVER (
              PARTITION BY scientific_name, latitude, longitude, 
                          DATE(observation_date)
              ORDER BY created_at
            ) as row_num
          FROM bird_observations
          WHERE source_id IS NULL OR source_id = ''
        )
        DELETE FROM bird_observations
        WHERE id IN (
          SELECT id FROM duplicates WHERE row_num > 1
        )
        RETURNING id
      ''');
      
      final deletedCount = results.affectedRowCount;
      debugPrint('Cleaned up $deletedCount duplicate observations');
      return deletedCount;
    } catch (e) {
      debugPrint('Error cleaning up duplicate observations: $e');
      return 0;
    }
  }

  // Add this method to migrate existing database structure if needed
  Future<bool> migrateDatabase() async {
    bool connected = await _ensureConnection();
    if (!connected) {
      return false;
    }
    
    try {
      // Check if source_id column exists
      final columnCheck = await _connection.query('''
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'bird_observations'
        AND column_name = 'source_id'
      ''');
      
      // If column doesn't exist, add it
      if (columnCheck.isEmpty) {
        debugPrint('Adding source_id column to bird_observations table');
        await _connection.query('''
          ALTER TABLE bird_observations
          ADD COLUMN source_id TEXT
        ''');
        
        // Add index for faster lookups
        await _connection.query('''
          CREATE INDEX idx_bird_observations_source_id
          ON bird_observations(source_id)
        ''');
      }
      
      return true;
    } catch (e) {
      debugPrint('Database migration failed: $e');
      return false;
    }
  }

  // Create connection (unchanged)
  Future<bool> _createConnection() async {
    try {
      debugPrint('Reading environment variables...');
      final dbHost = dotenv.env['DB_HOST'] ?? '';
      final dbUser = dotenv.env['DB_USER'] ?? '';
      final dbPassword = dotenv.env['DB_PASSWORD'] ?? '';

      if (dbHost.isEmpty || dbUser.isEmpty || dbPassword.isEmpty) {
        debugPrint('Missing database credentials: host=$dbHost, user=$dbUser');
        return false;
      }

      debugPrint('Creating database connection...');
      _connection = PostgreSQLConnection(dbHost, 5432, 'urban_echoes_db ',
          username: dbUser, password: dbPassword, useSSL: true);

      await _connection.open();
      debugPrint('Database connection established successfully');
      _isConnected = true;
      return true;
    } catch (e, stackTrace) {
      debugPrint('Database connection failed: $e');
      debugPrint(stackTrace as String?);
      _isConnected = false;
      return false;
    }
  }

  Future<bool> _ensureConnection() async {
    if (!_isConnected) {
      try {
        return await _createConnection();
      } catch (e) {
        debugPrint('Failed to reconnect to database: $e');
        return false;
      }
    }

    try {
      await _connection.query('SELECT 1');
      return true;
    } catch (e) {
      debugPrint('Connection test failed, reconnecting: $e');
      _isConnected = false;
      return await _createConnection();
    }
  }
}