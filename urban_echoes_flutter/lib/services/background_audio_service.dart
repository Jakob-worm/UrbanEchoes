import 'package:audio_service/audio_service.dart';
import 'package:urban_echoes/services/background_audio_handler.dart';
import 'package:flutter/material.dart';

class BackgroundAudioService {
  static final BackgroundAudioService _instance = BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  
  bool _isInitialized = false;
  AudioHandler? _audioHandler;
  
  BackgroundAudioService._internal();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
        // Configure audio session
      _audioHandler = await AudioService.init(
      builder: () => UrbanEchoesAudioHandler(),
      config: AudioServiceConfig(
      androidNotificationChannelId: 'com.example.urban_echoes.background',
      androidNotificationChannelName: 'Urban Echoes Background',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: false,
      androidStopForegroundOnPause: false,
      androidNotificationClickStartsActivity: false,
      androidNotificationOngoing: true,
      notificationColor: Color(0xFF2196F3),
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
      
      _isInitialized = true;
      debugPrint('🎵 Background audio service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing background audio service: $e');
    }
  }
  
  Future<void> startService() async {
    if (_audioHandler != null) return;
    
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Create the audio handler
      _audioHandler = await AudioService.init(
        builder: () => UrbanEchoesAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.urban_echoes.audio',
          androidNotificationChannelName: 'Urban Echoes',
          androidNotificationOngoing: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
          notificationColor: Color(0xFF4CAF50),
      ));
      
      debugPrint('🎵 Background audio service started');
    } catch (e) {
      debugPrint('❌ Error starting background audio service: $e');
    }
  }
  
  Future<void> stopService() async {
    if (_audioHandler != null) {
      await _audioHandler!.stop();
      _audioHandler = null;
      debugPrint('🎵 Background audio service stopped');
    }
  }
}