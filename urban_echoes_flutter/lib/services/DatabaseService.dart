import 'package:flutter/cupertino.dart';
import 'package:postgres/postgres.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:urban_echoes/models/bird_observation.dart';

class DatabaseService {
  PostgreSQLConnection? _connection; // Changed from late to nullable
  bool _isConnected = false;

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<bool> initialize() async {
    try {
      if (_isConnected && _connection != null) return true;

      return await _createConnection();
    } catch (e) {
      debugPrint('Database initialization failed: $e');
      return false;
    }
  }

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

      await _connection!.open();
      debugPrint('Database connection established successfully');
      _isConnected = true;
      return true;
    } catch (e, stackTrace) {
      debugPrint('Database connection failed: $e');
      print(stackTrace);
      _isConnected = false;
      return false;
    }
  }

  Future<void> closeConnection() async {
    if (_isConnected && _connection != null) {
      await _connection!.close();
      _isConnected = false;
      debugPrint('Database connection closed');
    }
  }

  // Method to handle reconnection if needed
  Future<bool> _ensureConnection() async {
    if (_connection == null || !_isConnected) {
      try {
        return await _createConnection();
      } catch (e) {
        debugPrint('Failed to reconnect to database: $e');
        return false;
      }
    }

    // Check if connection is still valid
    try {
      // Simple query to test connection
      await _connection!.query('SELECT 1');
      return true;
    } catch (e) {
      debugPrint('Connection test failed, reconnecting: $e');
      _isConnected = false;
      return await _createConnection();
    }
  }

  // Method to add a bird observation to the database
  Future<int> addBirdObservation(BirdObservation observation) async {
    bool connected = await _ensureConnection();
    if (!connected || _connection == null) {
      throw Exception('Database connection not available');
    }

    try {
      final results = await _connection!.query(
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
          test_batch_id
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
          @testBatchId
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
        },
      );

      if (results.isNotEmpty) {
        return results.first[0] as int; // Return the ID of the inserted record
      } else {
        throw Exception('Failed to insert bird observation');
      }
    } catch (e) {
      debugPrint('Error adding bird observation: $e');
      throw Exception('Error adding bird observation: $e');
    }
  }

  // Method to get all bird observations
  Future<List<BirdObservation>> getAllBirdObservations() async {
    bool connected = await _ensureConnection();
    if (!connected || _connection == null) {
      return []; // Return empty list if connection fails
    }

    try {
      final results = await _connection!.query('''
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
          test_batch_id
        FROM bird_observations 
        ORDER BY created_at DESC
        ''');

      return results
          .map((row) => BirdObservation(
                birdName: row[1] as String,
                scientificName: row[2] as String,
                soundDirectory: row[3] as String,
                latitude: (row[4] as num).toDouble(),
                longitude: (row[5] as num).toDouble(),
                observationDate: row[6] as DateTime,
                observationTime: row[7].toString(), // Convert TIME to String
                observerId: row[8] as int,
                quantity: row[9] as int,
                isTestData: row[10] as bool,
                testBatchId: row[11] as int,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching bird observations: $e');
      return []; // Return empty list on error
    }
  }
}
