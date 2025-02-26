import 'package:postgres/postgres.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:urban_echoes/models/BirdObservation.dart';

class DatabaseService {
  late PostgreSQLConnection _connection;
  bool _isConnected = false;

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<void> initialize() async {
    await _createConnection();
  }

  Future<void> _createConnection() async {
    // Get database credentials from environment variables
    final dbHost = dotenv.env['DB_HOST'] ?? '';
    final dbName = dotenv.env['DB_NAME'] ?? 'urban_echoes_db';
    final dbPort = int.tryParse(dotenv.env['DB_PORT'] ?? '5432') ?? 5432;
    final dbUser = dotenv.env['DB_USER'] ?? '';
    final dbPassword = dotenv.env['DB_PASSWORD'] ?? '';

    if (dbHost.isEmpty || dbUser.isEmpty || dbPassword.isEmpty) {
      throw Exception('Database configuration is missing');
    }

    _connection = PostgreSQLConnection(
      dbHost,
      dbPort,
      dbName,
      username: dbUser,
      password: dbPassword,
      useSSL: true,
    );

    try {
      await _connection.open();
      _isConnected = true;
      print('Database connection established successfully');
    } catch (e) {
      _isConnected = false;
      print('Failed to connect to database: $e');
      throw Exception('Failed to connect to database: $e');
    }
  }

  Future<void> closeConnection() async {
    if (_isConnected) {
      await _connection.close();
      _isConnected = false;
      print('Database connection closed');
    }
  }

  // Method to handle reconnection if needed
  Future<void> _ensureConnection() async {
    if (!_isConnected) {
      try {
        await _createConnection();
      } catch (e) {
        throw Exception('Failed to reconnect to database: $e');
      }
    }
  }

  // Method to add a bird observation to the database
  Future<int> addBirdObservation(BirdObservation observation) async {
    await _ensureConnection();

    try {
      final results = await _connection.query(
        '''
        INSERT INTO bird_observations (
          bird_name, 
          scientific_name, 
          sound_url, 
          latitude, 
          longitude, 
          observation_date, 
          observation_time, 
          observer_id, 
          quantity
        ) VALUES (
          @birdName, 
          @scientificName, 
          @soundUrl, 
          @latitude, 
          @longitude, 
          @observationDate, 
          @observationTime, 
          @observerId, 
          @quantity
        ) RETURNING id
        ''',
        substitutionValues: {
          'birdName': observation.birdName,
          'scientificName': observation.scientificName,
          'soundUrl': observation.soundUrl,
          'latitude': observation.latitude,
          'longitude': observation.longitude,
          'observationDate': observation.observationDate,
          'observationTime': observation.observationTime,
          'observerId': observation.observerId,
          'quantity': observation.quantity,
        },
      );

      if (results.isNotEmpty) {
        return results.first[0] as int; // Return the ID of the inserted record
      } else {
        throw Exception('Failed to insert bird observation');
      }
    } catch (e) {
      print('Error adding bird observation: $e');
      throw Exception('Error adding bird observation: $e');
    }
  }

  // Method to get all bird observations
  Future<List<BirdObservation>> getAllBirdObservations() async {
    await _ensureConnection();

    try {
      final results = await _connection.query('''
        SELECT 
          id, 
          bird_name, 
          scientific_name, 
          sound_url, 
          latitude, 
          longitude, 
          observation_date, 
          observation_time, 
          observer_id, 
          quantity 
        FROM bird_observations 
        ORDER BY created_at DESC
        ''');

      return results
          .map((row) => BirdObservation(
                id: row[0] as int,
                birdName: row[1] as String,
                scientificName: row[2] as String,
                soundUrl: row[3] as String?,
                latitude: (row[4] as num).toDouble(),
                longitude: (row[5] as num).toDouble(),
                observationDate: row[6] as DateTime,
                observationTime: row[7].toString(), // Convert TIME to String
                observerId: row[8] as int?,
                quantity: row[9] as int,
              ))
          .toList();
    } catch (e) {
      print('Error fetching bird observations: $e');
      throw Exception('Error fetching bird observations: $e');
    }
  }
}
