// Bird sound player
import 'package:audioplayers/audioplayers.dart';
import 'package:urban_echoes/utils/download_file.dart';

class BirdSoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  final DownloadFile _downloadFile = DownloadFile();

  Future<void> playSound(String scientificName) async {
    if (scientificName.isEmpty) {
      throw ArgumentError('Scientific name cannot be empty');
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      _isPlaying = true;
      await _downloadFile.playBirdSound(scientificName, _audioPlayer);
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
