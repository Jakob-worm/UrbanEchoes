import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:urban_echoes/utils/noise_gate.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';

/// Import dart:html only for web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:io' as io;

class NoiseGateTestPage extends StatefulWidget {
  const NoiseGateTestPage({super.key});

  @override
  _NoiseGateTestPageState createState() => _NoiseGateTestPageState();
}

class _NoiseGateTestPageState extends State<NoiseGateTestPage> {
  dynamic _selectedFile; // Can be File or html.File
  double _threshold = 0.1;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  final List<String> audioFiles = [
    'assets/audio/XC944072 - Bougainvillesanger - Cincloramphus llaneae.wav',
    'assets/audio/XC521615 - Blåmejse - Cyanistes caeruleus.mp3'
  ];

  void _pickAudioFile() async {
    if (kIsWeb) {
      var uploadInput = html.FileUploadInputElement();
      uploadInput.accept = 'audio/*';
      uploadInput.click();

      uploadInput.onChange.listen((event) {
        final file = uploadInput.files!.first;
        setState(() {
          _selectedFile = file;
        });
      });
    } else {
      // Mobile/desktop file selection
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = io.File(result.files.single.path!);
        });
      }
    }
  }

  void _pickRandomAudioFile() async {
    var randomFile = audioFiles[Random().nextInt(audioFiles.length)];
    debugPrint('Selected file: $randomFile');

    final player = AudioPlayer();
    await player.play(AssetSource(randomFile)); // Play from assets
  }

  Future<void> _processAndPlayAudio() async {
    if (_selectedFile == null) return;

    try {
      Uint8List originalBytes;

      // Handle byte extraction differently for web and mobile
      if (kIsWeb) {
        html.File webFile = _selectedFile;
        originalBytes = await _readWebFileBytes(webFile);
      } else {
        originalBytes = await _selectedFile.readAsBytes();
      }

      // Apply noise gate
      NoiseGate noiseGate = NoiseGate(threshold: _threshold);
      Uint8List processedBytes = noiseGate.processAudioBytes(originalBytes);

      // Web-specific audio playback
      if (kIsWeb) {
        // Create a blob from processed bytes
        final blob = html.Blob([processedBytes], 'audio/mp3');
        final url = html.Url.createObjectUrl(blob);

        // Play using audioplayers
        await _audioPlayer.play(UrlSource(url));
        setState(() {
          _isPlaying = true;
        });
      } else {
        // Mobile/desktop approach
        final tempDir = await getTemporaryDirectory();
        final tempFile = io.File('${tempDir.path}/processed_audio.mp3');
        await tempFile.writeAsBytes(processedBytes);

        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Error processing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing audio: $e')),
      );
    }
  }

  // Utility method to read web file bytes
  Future<Uint8List> _readWebFileBytes(html.File file) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    return reader.result as Uint8List;
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Noise Gate Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File Selection
            ElevatedButton(
              onPressed: _pickAudioFile,
              child: Text('Select Audio File from disk'),
            ),
            ElevatedButton(
              onPressed: _pickRandomAudioFile,
              child: Text('Select Audio File from project'),
            ),

            // Selected File Display
            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Selected: ${_selectedFile is html.File ? _selectedFile.name : _selectedFile.path.split('/').last}',
                  style: TextStyle(fontSize: 16),
                ),
              ),

            // Threshold Slider
            Slider(
              value: _threshold,
              min: 0.01,
              max: 1.0,
              divisions: 100,
              label:
                  'Noise Gate Threshold: ${(_threshold * 100).toStringAsFixed(2)}%',
              onChanged: (value) {
                setState(() {
                  _threshold = value;
                });
              },
            ),

            // Current Threshold Display
            Text(
              'Current Threshold: ${(_threshold * 100).toStringAsFixed(2)}%',
              textAlign: TextAlign.center,
            ),

            // Playback Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Original Audio
                ElevatedButton(
                  onPressed: _selectedFile == null
                      ? null
                      : () async {
                          if (_isPlaying) {
                            await _stopAudio();
                          }

                          if (kIsWeb) {
                            // Web-specific original audio playback
                            final reader = html.FileReader();
                            reader.readAsArrayBuffer(_selectedFile);
                            await reader.onLoad.first;
                            final blob =
                                html.Blob([reader.result], 'audio/mp3');
                            final url = html.Url.createObjectUrl(blob);
                            await _audioPlayer.play(UrlSource(url));
                          } else {
                            // Mobile/desktop original audio playback
                            await _audioPlayer
                                .play(DeviceFileSource(_selectedFile.path));
                          }

                          setState(() {
                            _isPlaying = true;
                          });
                        },
                  child: Text('Play Original'),
                ),

                // Processed Audio
                ElevatedButton(
                  onPressed:
                      _selectedFile == null ? null : _processAndPlayAudio,
                  child: Text('Play Processed'),
                ),

                // Stop Button
                ElevatedButton(
                  onPressed: _isPlaying ? _stopAudio : null,
                  child: Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
