import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  final Map<int, AudioPlayer> _players = {};
  final Map<int, bool> _isActive = {};
  final AzureStorageService _storageService = AzureStorageService();
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Start playing random sounds in sequence for an observation
  Future<void> startSequentialRandomSounds(String folderPath, int observationId) async {
    _isActive[observationId] = true;
    
    // Create a dedicated player for this observation
    if (!_players.containsKey(observationId)) {
      _players[observationId] = AudioPlayer();
      
      // Set up completion listener to play the next sound
      _players[observationId]!.onPlayerComplete.listen((_) {
        // When sound finishes, play another if still active
        if (_isActive[observationId] == true) {
          _playNextRandomSound(folderPath, observationId);
        }
      });
    }
    
    // Start playing the first sound
    await _playNextRandomSound(folderPath, observationId);
  }
  
  // Play the next random sound from the folder
  Future<void> _playNextRandomSound(String folderPath, int observationId) async {
    try {
      // Check if still active
      if (_isActive[observationId] != true) return;
      
      // Fetch the list of available sound files from Azure Storage
      print("folder path $folderPath");
      List<String> files = await _storageService.listFiles(folderPath);
      
      if (files.isEmpty) {
        print('No bird sounds found in folder: $folderPath');
        return;
      }
      
      // Pick a random file
      final random = Random();
      String randomFile = files[random.nextInt(files.length)];
      
      // Play the selected file
      await _players[observationId]!.play(UrlSource(randomFile));
      
    } catch (e) {
      print('Failed to play bird sound: ${e.toString()}');
      
      // If there was an error, attempt to play another sound after a delay
      if (_isActive[observationId] == true) {
        Future.delayed(Duration(seconds: 3), () {
          _playNextRandomSound(folderPath, observationId);
        });
      }
    }
  }
  
  // Stop playing sounds for an observation
  Future<void> stopSounds(int observationId) async {
    // Mark as inactive first to prevent new sounds from starting
    _isActive[observationId] = false;
    
    // Stop the player if it exists
    if (_players.containsKey(observationId)) {
      await _players[observationId]!.stop();
    }
  }
  
  // Clean up resources
  void dispose() {
    for (var id in _players.keys) {
      _players[id]!.stop();
      _players[id]!.dispose();
    }
    _players.clear();
    _isActive.clear();
  }
  Future<void> playRandomSoundOld(String folderPath) async {
    try {
      // Fetch the list of available sound files from Azure Storage
      print("folder path $folderPath");
      List<String> files = await _storageService.listFiles(folderPath);

      if (files.isEmpty) {
        throw Exception('No bird sounds found in the specified folder.');
      }

      // Pick a random file
      final random = Random();
      String randomFile = files[random.nextInt(files.length)];

      // Stop any currently playing sound
      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      // Play the selected file
      await _audioPlayer.play(UrlSource(randomFile));
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
      throw Exception('Failed to play bird sound: ${e.toString()}');
    }
  }

  
    
  }