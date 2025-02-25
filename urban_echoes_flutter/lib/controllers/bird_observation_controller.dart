// BirdObservation Controller
import 'package:urban_echoes/services/bird_sound_player.dart';

class BirdObservationController {
  final BirdSoundPlayer _soundPlayer = BirdSoundPlayer();

  Future<void> playBirdSound(String scientificName) async {
    try {
      await _soundPlayer.playSound(scientificName);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> submitObservation(
      String birdName, String scientificName, int count) async {
    try {
      print('$birdName ($count) has been recorded');

      if (scientificName.isNotEmpty) {
        await playBirdSound(scientificName);
      } else {
        print('Warning: No scientific name found for $birdName');
      }

      // Here you would typically send data to your backend
      // await _apiService.submitObservation(birdName, scientificName, count);

      return true;
    } catch (e) {
      print('Error submitting observation: $e');
      return false;
    }
  }

  void dispose() {
    _soundPlayer.dispose();
  }
}
