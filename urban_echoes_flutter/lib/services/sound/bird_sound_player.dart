import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:urban_echoes/services/service_config.dart';
import 'package:urban_echoes/services/storage&database/azure_storage_service.dart';

class BirdSoundPlayer {
  // Get config instance once
  final ServiceConfig _config = ServiceConfig();

  // Configuration
  late int maxActivePlayers;
  static const int retryLimit = 3;
  
  // Player pool
  final List<AudioPlayer> _playerPool = [];
  final Map<String, _SoundRequest> _activeRequests = {};
  
  // Services & utilities
  final AzureStorageService _storageService = AzureStorageService();
  final Random _random = Random();
  
  // Sound file cache
  final Map<String, List<String>> _soundFileCache = {};
  
  // Player status tracking
  final Map<AudioPlayer, DateTime> _lastPlayerActivity = {};
  final Map<AudioPlayer, bool> _playerBusy = {};
  
  // Volume/balance tracking
  final Map<String, _AudioSettings> _soundSettings = {};
  
  // Periodic checker
  Timer? _periodicChecker;
  Timer? _audioGuardTimer;
  
  // Event callback for buffering timeout
  Function? onBufferingTimeout;
  
  // Debug flag 
  final bool _debugMode = true;
  
  void _log(String message) {
    if (_debugMode) {
      debugPrint(message);
    }
  }
  
  // Constructor 
  BirdSoundPlayer() {
    maxActivePlayers = _config.maxActivePlayers;
    _initializeAllPlayers();
    _startPeriodicChecks();
  }
  
  void _initializeAllPlayers() {
  // Ensure we start with an empty pool
  _playerPool.clear();
  _playerBusy.clear();
  _lastPlayerActivity.clear();
  
  for (int i = 0; i < maxActivePlayers; i++) {
    _createAndAddPlayer();
  }
  
  // Verify player pool after creation
  _verifyPlayerPool();
  
  _log('🎵 Created $maxActivePlayers audio players in pool');
}

void _createAndAddPlayer() {
  try {
    final player = AudioPlayer();
    
    // Configure audio context to allow simultaneous playback
    player.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          isSpeakerphoneOn: false,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    
    // Assign a unique name to the player for better debugging
    final playerName = 'Player_${_playerPool.length + 1}';
    
    // Configure player
    player.setReleaseMode(ReleaseMode.release);
    player.setPlayerMode(PlayerMode.mediaPlayer);
    player.setVolume(0.5);
    
    // THIS IS THE MISSING PART:
    // Add the onPlayerComplete listener
    player.onPlayerComplete.listen((_) {
      _log('🎵 $playerName: Playback completed');
      _onPlayerComplete(player);
    });
    
    // Setup state change listener (which you already have)
    player.onPlayerStateChanged.listen((state) {
      _log('🔊 $playerName: State changed to $state');
    });
    
    // Add to pool and initialize status
    _playerPool.add(player);
    _playerBusy[player] = false;
    _lastPlayerActivity[player] = DateTime.now();
    
    _log('✅ Added $playerName to pool (Total: ${_playerPool.length})');
  } catch (e) {
    _log('❌ Error creating audio player: $e');
  }
}

// Add a method to verify player pool
void _verifyPlayerPool() {
  _log('🔍 Player Pool Verification:');
  _log('Total Players: ${_playerPool.length}');
  _log('Busy Players: ${_playerBusy.values.where((busy) => busy).length}');
  
  for (int i = 0; i < _playerPool.length; i++) {
    final player = _playerPool[i];
    _log('Player ${i + 1}: Busy = ${_playerBusy[player]}, Last Activity = ${_lastPlayerActivity[player]}');
  }
}
  // Start periodic status checks
  void _startPeriodicChecks() {
    _periodicChecker = Timer.periodic(Duration(seconds: 5), (_) {
      _checkPlayersStatus();
    });
    
    // Add a guard timer that ensures volume settings are correct
    _audioGuardTimer = Timer.periodic(Duration(seconds: 2), (_) {
      _ensureAudioSettings();
    });
  }
  
  // Make sure volume and balance settings are applied
  void _ensureAudioSettings() {
    // Check all active requests to make sure settings are applied
    for (final entry in _activeRequests.entries) {
      final request = entry.value;
      final id = entry.key;
      
      if (request.player != null && _soundSettings.containsKey(id)) {
        final settings = _soundSettings[id]!;
        
        // Reapply volume/balance settings if they were set to zero
        try {
          request.player!.setVolume(settings.volume);
          request.player!.setBalance(settings.pan);
        } catch (e) {
          // Ignore errors during volume adjustment
        }
      }
    }
  }
  
  // Check all players for issues
  void _checkPlayersStatus() {
    final now = DateTime.now();
    
    // Check for stuck players
    for (final player in _playerPool) {
      final lastActivity = _lastPlayerActivity[player];
      if (lastActivity != null && now.difference(lastActivity).inMinutes > 3) {
        _log('⚠️ Player appears stuck, resetting');
        _resetPlayer(player);
      }
    }
    
    // Check for orphaned requests
    List<String> orphanedIds = [];
    for (final entry in _activeRequests.entries) {
      final request = entry.value;
      if (request.player == null || 
          !_playerPool.contains(request.player) || 
          now.difference(request.lastActivity).inMinutes > 5) {
        orphanedIds.add(entry.key);
      }
    }
    
    // Remove orphaned requests
    for (final id in orphanedIds) {
      _log('⚠️ Removing orphaned request: $id');
      _activeRequests.remove(id);
    }
    
    // Check for accounting errors
    int busyCount = 0;
    for (final busy in _playerBusy.values) {
      if (busy) busyCount++;
    }
    
    if (busyCount != _activeRequests.length) {
      _log('⚠️ Player accounting error: $busyCount busy players, ${_activeRequests.length} active requests');
      _fixPlayerAccounting();
    }
  }
  
  // Fix player accounting if there's a mismatch
  void _fixPlayerAccounting() {
    // Reset all players to idle
    for (final player in _playerPool) {
      _playerBusy[player] = false;
    }
    
    // Mark players that are actually in use
    for (final request in _activeRequests.values) {
      if (request.player != null && _playerPool.contains(request.player)) {
        _playerBusy[request.player!] = true;
      }
    }
  }
  
  // Reset a problematic player
  Future<void> _resetPlayer(AudioPlayer player) async {
    try {
      await player.stop();
    } catch (e) {
      // Ignore errors during reset
    }
    
    _playerBusy[player] = false;
    _lastPlayerActivity[player] = DateTime.now();
    
    // Find and clean up any associated request
    String? requestId;
    for (final entry in _activeRequests.entries) {
      if (entry.value.player == player) {
        requestId = entry.key;
        break;
      }
    }
    
    if (requestId != null) {
      _activeRequests.remove(requestId);
    }
  }
  
  AudioPlayer? _getAvailablePlayer() {
  // Keep track of the last used player index
   int lastPlayerIndex = -1;
  
  // Find an available player starting from the next index after the last used
  for (int i = 0; i < _playerPool.length; i++) {
    // Calculate the rotated index
    int index = (lastPlayerIndex + 1 + i) % _playerPool.length;
    
    if (_playerBusy[_playerPool[index]] == false) {
      lastPlayerIndex = index;
      return _playerPool[index];
    }
  }
  
  return null;
}
  
  Future<void> startSound(String folderPath, String observationId, double pan, double volume) async {
  if (folderPath.isEmpty) {
    _log('⚠️ Cannot play sound: empty folder path for $observationId');
    return;
  }

  _log('🔊 Starting sound for $observationId');
  _log('📂 Folder Path: $folderPath');
  _log('🎚️ Pan: $pan, Volume: $volume');
  
  // Store settings regardless of whether we have an active player
  _soundSettings[observationId] = _AudioSettings(pan: pan, volume: volume);
  
  // If already active, just update parameters and player
  if (_activeRequests.containsKey(observationId)) {
    final request = _activeRequests[observationId]!;
    request.pan = pan;
    request.volume = volume;
    request.lastActivity = DateTime.now();
    
    if (request.player != null) {
      await _applyAudioSettings(request.player!, pan, volume);
      _lastPlayerActivity[request.player!] = DateTime.now();
    }
    return;
  }
  
  // Get sound files
  List<String> soundFiles = _soundFileCache[folderPath] ?? [];
  if (soundFiles.isEmpty) {
    await _loadSoundFiles(folderPath);
    soundFiles = _soundFileCache[folderPath] ?? [];
  }
  
  if (soundFiles.isEmpty) {
    _log('❌ No sound files available for $observationId');
    return;
  }
  
  // Get an available player
  final player = _getAvailablePlayer();
  if (player == null) {
    _log('⚠️ No available players for $observationId, checking for lower priority sounds');
    return;
  }
  
  // Mark player as busy
  _playerBusy[player] = true;
  _lastPlayerActivity[player] = DateTime.now();
  
  // Create request
  final request = _SoundRequest(
    observationId: observationId,
    folderPath: folderPath,
    pan: pan,
    volume: volume,
    player: player,
    lastActivity: DateTime.now(),
  );
  
  // Check if this observation is already playing on a different player
  // This shouldn't happen with proper accounting, but let's be safe
  for (final entry in _activeRequests.entries) {
    if (entry.key == observationId && entry.value.player != player) {
      _log('⚠️ Found duplicate player for $observationId, stopping old one');
      final oldPlayer = entry.value.player;
      if (oldPlayer != null) {
        try {
          await oldPlayer.stop();
          _playerBusy[oldPlayer] = false;
        } catch (e) {
          // Ignore errors when stopping the old player
        }
      }
      // Remove the old request
      _activeRequests.remove(observationId);
      break;
    }
  }
  
  // Add to active requests
  _activeRequests[observationId] = request;
  
  // Play sound
  _playRandomSound(request);
}
  
  // Apply audio settings with error handling
  Future<void> _applyAudioSettings(AudioPlayer player, double pan, double volume) async {
    try {
      await player.setVolume(volume);
      await player.setBalance(pan);
      
      // Ensure volume isn't 0 unless it's supposed to be
      if (volume > 0.01) {
        // Double-check that volume was actually set
        Future.delayed(Duration(milliseconds: 100), () async {
          try {
            await player.setVolume(volume);
          } catch (e) {
            // Ignore errors in the double-check
          }
        });
      }
    } catch (e) {
      _log('❌ Error setting audio parameters: $e');
    }
  }
  
  // Load sound files for a folder
  Future<void> _loadSoundFiles(String folderPath) async {
    try {
      _log('📁 Fetching audio files for: $folderPath');
      final files = await _storageService.listFiles(folderPath);
      
      // Prioritize MP3 files when available
      final mp3Files = files.where((file) => 
        file.toLowerCase().endsWith('.mp3')).toList();
      
      final filesToUse = mp3Files.isNotEmpty ? mp3Files : files;
      
      _soundFileCache[folderPath] = filesToUse;
      _log('✅ Cached ${filesToUse.length} audio files for $folderPath');
    } catch (e) {
      _log('❌ Error loading sound files: $e');
      _soundFileCache[folderPath] = [];
    }
  }
  
  // Play a random sound for a request
  Future<void> _playRandomSound(_SoundRequest request) async {
    final player = request.player;
    if (player == null) return;

      // Check if this observation already has another player assigned
  for (final entry in _activeRequests.entries) {
    if (entry.key == request.observationId && entry.value.player != player) {
      _log('⚠️ Found another player for ${request.observationId}, stopping it first');
      final oldPlayer = entry.value.player;
      if (oldPlayer != null) {
        try {
          await oldPlayer.stop();
          _playerBusy[oldPlayer] = false;
        } catch (e) {
          // Ignore errors when stopping old player
        }
      }
      break;
    }
  }
    
    try {
      final soundFiles = _soundFileCache[request.folderPath] ?? [];
      if (soundFiles.isEmpty) {
        _log('❌ No sound files for ${request.observationId}');
        return;
      }
      
      // Pick a random file
      final file = soundFiles[_random.nextInt(soundFiles.length)];
      _log('🎵 Playing sound for ${request.observationId}: $file');
      
      // Make sure volume is properly set BEFORE starting
      await _applyAudioSettings(player, request.pan, request.volume);
      
      _lastPlayerActivity[player] = DateTime.now();
      
      // Play the sound
      await player.play(UrlSource(file));
      
      // Double-check volume setting AFTER the source is loaded
      Future.delayed(Duration(milliseconds: 300), () async {
        if (request.player != null && _activeRequests.containsKey(request.observationId)) {
          await _applyAudioSettings(player, request.pan, request.volume);
        }
      });
    } catch (e) {
      _log('❌ Error playing sound: $e');
      request.retryCount++;
      
      if (request.retryCount <= retryLimit) {
        // Retry after delay
        int delay = (1000 * request.retryCount).clamp(1000, 5000);
        Future.delayed(Duration(milliseconds: delay), () {
          if (_activeRequests.containsKey(request.observationId)) {
            _playRandomSound(request);
          }
        });
      } else {
        _log('❌ Exceeded retry limit for ${request.observationId}');
        stopSounds(request.observationId);
      }
    }
  }

  void _onPlayerComplete(AudioPlayer player) {
  _lastPlayerActivity[player] = DateTime.now();
  
  // Find which request this belongs to
  String? completedId;
  _SoundRequest? request;
  for (final entry in _activeRequests.entries) {
    if (entry.value.player == player) {
      completedId = entry.key;
      request = entry.value;
      break;
    }
  }
  
  if (completedId != null && request != null) {
    _log('✅ Sound completed for ${request.observationId}');
    
    // Reset retry count
    request.retryCount = 0;
    
    // Ensure player is marked as available for reuse
    _playerBusy[player] = false;
    
    // Schedule the next sound playback with delay
    int delay = 2000 + _random.nextInt(2000); // 2-4 seconds delay
    Future.delayed(Duration(milliseconds: delay), () {
      // Check if the observation is still active before replaying
      if (_activeRequests.containsKey(completedId)) {
        _log('🔄 Replaying sound for ${request!.observationId}');
        
        // Check if another player is already assigned to this observation
        bool hasAnotherPlayer = false;
        for (final entry in _activeRequests.entries) {
          if (entry.key == completedId && entry.value.player != null && entry.value.player != player) {
            hasAnotherPlayer = true;
            _log('⚠️ Another player already assigned to ${request.observationId}');
            break;
          }
        }
        
        if (!hasAnotherPlayer) {
          // Get an available player
          final availablePlayer = _getAvailablePlayer();
          if (availablePlayer != null) {
            // Update the request with the new player
            request.player = availablePlayer;
            _playerBusy[availablePlayer] = true;
            
            // Play the sound again
            _playRandomSound(request);
          } else {
            _log('⚠️ No available players for replay, will try again later');
            // Try again later if no players are available
            Future.delayed(Duration(seconds: 3), () {
              if (_activeRequests.containsKey(completedId)) {
                _onPlayerComplete(player); // Recursively try again
              }
            });
          }
        }
      } else {
        _log('❌ Observation ${request!.observationId} no longer active, not replaying');
      }
    });
  } else {
    // No matching request found, just mark player as available
    _playerBusy[player] = false;
    _log('⚠️ Could not identify which sound completed');
  }
}

// Add this callback to be set by LocationService
Function(String observationId)? onSoundComplete;
  
  // Update panning and volume
  Future<void> updatePanningAndVolume(String observationId, double pan, double volume) async {
    // Store the settings regardless of active status
    _soundSettings[observationId] = _AudioSettings(pan: pan, volume: volume);
    
    if (_activeRequests.containsKey(observationId)) {
      final request = _activeRequests[observationId]!;
      request.pan = pan;
      request.volume = volume;
      request.lastActivity = DateTime.now();
      
      if (request.player != null) {
        await _applyAudioSettings(request.player!, pan, volume);
        _lastPlayerActivity[request.player!] = DateTime.now();
      }
    }
  }
  
  // Modify stopSounds to gradually reduce volume
Future<void> stopSounds(String observationId) async {
  _log('🛑 Stopping sound for $observationId');
  
  if (_activeRequests.containsKey(observationId)) {
    final request = _activeRequests.remove(observationId)!;
    final player = request.player;
    
    if (player != null) {
      try {
        // Gradually reduce volume
        await player.setVolume(0.3);
        await Future.delayed(Duration(milliseconds: 100));
        await player.setVolume(0.1);
        await Future.delayed(Duration(milliseconds: 100));
        await player.setVolume(0);
        await player.stop();
        
        _playerBusy[player] = false;
        _lastPlayerActivity[player] = DateTime.now();
      } catch (e) {
        _log('❌ Error stopping sound: $e');
        _playerBusy[player] = false;
      }
    }
  }
  
  _soundSettings.remove(observationId);
}
  
  // Dispose
  void dispose() {
    _log('🧹 Disposing all players');
    
    _periodicChecker?.cancel();
    _audioGuardTimer?.cancel();
    
    // Stop and dispose all players
    for (final player in _playerPool) {
      try {
        player.stop();
        player.dispose();
      } catch (e) {
        // Ignore errors during disposal
      }
    }
    
    _playerPool.clear();
    _activeRequests.clear();
    _playerBusy.clear();
    _lastPlayerActivity.clear();
    _soundFileCache.clear();
    _soundSettings.clear();
  }
}

// Helper class for sound requests
class _SoundRequest {
  final String observationId;
  final String folderPath;
  double pan;
  double volume;
  AudioPlayer? player;
  DateTime lastActivity;
  int retryCount = 0;
  
  _SoundRequest({
    required this.observationId,
    required this.folderPath,
    required this.pan,
    required this.volume,
    this.player,
    required this.lastActivity,
  });
}

// Helper class to track audio settings
class _AudioSettings {
  final double pan;
  final double volume;
  
  _AudioSettings({
    required this.pan,
    required this.volume,
  });
}