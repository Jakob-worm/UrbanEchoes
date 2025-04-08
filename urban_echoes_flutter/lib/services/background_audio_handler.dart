import 'package:audio_service/audio_service.dart';
import 'dart:async';

class UrbanEchoesAudioHandler extends BaseAudioHandler {
  Timer? _keepAliveTimer;
  
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
  
  @override
  Future<void> stop() async {
    _keepAliveTimer?.cancel();
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