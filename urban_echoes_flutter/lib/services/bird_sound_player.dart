// Bird sound player
import 'package:audioplayers/audioplayers.dart';

class BirdSoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Future<void> playSound(String soundUrl) async {
    if (soundUrl.isEmpty) {
      throw ArgumentError('Scientific name cannot be empty');
    }

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      _audioPlayer.play(UrlSource(soundUrl));
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
