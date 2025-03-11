import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:urban_echoes/services/AzureStorageService.dart';

class BirdSoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AzureStorageService _storageService = AzureStorageService();
  bool _isPlaying = false;

  Future<void> playRandomSound(String folderPath) async {
    try {
      // Fetch the list of available sound files from Azure Storage
      print("folder path " + folderPath);
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

  Future<void> stop() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _isPlaying = false;
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
