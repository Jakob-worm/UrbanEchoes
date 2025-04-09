import 'dart:async';

import 'package:audio_service/audio_service.dart';

class UrbanEchoesAudioHandler extends BaseAudioHandler {
  Timer? _keepAliveTimer;
  Timer? _silentAudioTimer;
  StreamSubscription? _locationSubscription;
  
  UrbanEchoesAudioHandler() {
    // Initialize with a dummy media item
    mediaItem.add(const MediaItem(
      id: 'urban_echoes_background',
      title: 'Urban Echoes',
      artist: 'Background Service',
      playable: true,
    ));
    
    // Set as playing but silent
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.ready,
      playing: true,
    ));
    
    _startKeepAliveTimer();
    _startSilentAudioPlayer();
  }
  
  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Just keep the service alive without playing audio
      playbackState.add(playbackState.value.copyWith(
        updatePosition: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      ));
    });
  }
  
  // Play a silent audio track to keep the audio session active
  void _startSilentAudioPlayer() {
    _silentAudioTimer?.cancel();
    _silentAudioTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      // Update state to ensure the system thinks we're playing audio
      playbackState.add(PlaybackState(
        processingState: AudioProcessingState.ready,
        playing: true,
        updatePosition: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      ));
    });
  }
  
  @override
  Future<void> stop() async {
    _keepAliveTimer?.cancel();
    _silentAudioTimer?.cancel();
    _locationSubscription?.cancel();
    await super.stop();
  }
  
  // Override play method to not actually play audio
  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(playing: true));
  }
  
  // Override pause method to not affect our real audio players
  @override
  Future<void> pause() async {
    // Don't actually pause, just update state
    playbackState.add(playbackState.value.copyWith(playing: true));
  }
}