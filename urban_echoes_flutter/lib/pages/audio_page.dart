import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/observation/observation_service.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});

  @override
  AudioPageState createState() => AudioPageState();
}

class AudioPageState extends State<AudioPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> soundUrls = [];
  int currentIndex = 0;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    // We'll load the observations in didChangeDependencies instead
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadObservations();
  }

  void loadObservations() {
    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String apiUrl = debugMode
        ? 'http://10.0.2.2:8000/observations'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';

    ObservationService(apiUrl: apiUrl).fetchObservations().then((data) {
      setState(() {
        soundUrls = data
            .where((obs) => obs["sound_url"].isNotEmpty)
            .take(10)
            .map<String>((obs) => obs["sound_url"])
            .toList();
      });
    });
  }

  Future<void> _playNextSound() async {
    if (currentIndex < soundUrls.length) {
      setState(() => isPlaying = true);
      await _audioPlayer.play(UrlSource(soundUrls[currentIndex]));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (currentIndex < soundUrls.length - 1) {
          setState(() => currentIndex++);
          _playNextSound();
        } else {
          setState(() => isPlaying = false);
        }
      });
    }
  }

  void _stopPlayback() {
    _audioPlayer.stop();
    setState(() => isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Audio Player")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              soundUrls.isNotEmpty
                  ? "Playing: ${currentIndex + 1} of ${soundUrls.length}"
                  : "No audio available",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            if (isPlaying)
              ElevatedButton(
                onPressed: _stopPlayback,
                child: const Text("Stop"),
              )
            else
              ElevatedButton(
                onPressed: _playNextSound,
                child: const Text("Play"),
              ),
            ElevatedButton(
              onPressed: _playNextSound,
              child: const Text("Spil næste lyd"),
            ),
          ],
        ),
      ),
    );
  }
}