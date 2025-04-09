class ServiceConfig {
  // Singleton instance
  static final ServiceConfig _instance = ServiceConfig._internal();
  factory ServiceConfig() => _instance;
  ServiceConfig._internal();

  // Location settings
  double maxRange = 50.0; // Default point radius in meters (was AppConstants.defaultPointRadius)
  double hyperlocalRadius = 10.0; // Hyperlocal point radius (was AppConstants.hyperlocalPointRadius)
  int gridSize = 1000; // Grid size in meters (was AppConstants.gridSize)
  double distanceFilter = 5.0; // Minimum distance between location updates
  int updateIntervalSeconds = 15; // Time between location updates
  int batchUpdateMs = 500; // UI update batching time
  int maxFailuresBeforeFallback = 3; // Number of failures before using fallback
  
  // Map settings (migrated from AppConstants)
  double defaultZoom = 15.0;
  double maxZoom = 18.0;
  double minZoom = 10.0;
  
  // Audio settings
  double minVolume = 0.05; // Minimum volume for distant sounds
  double maxVolume = 0.9; // Maximum volume for nearby sounds
  int minSoundDelayMs = 300; // Minimum delay between sounds
  int maxSoundDelayMs = 1000; // Maximum base delay for sounds
  int minSoundIntervalMs = 500; // Minimum interval between sounds
  int maxSoundIntervalMs = 20000; // Maximum interval between sounds
  int maxActivePlayers = 5; // Max number of active players (was AppConstants.maxActivePlayers)
  
  // Service timers
  int watchdogIntervalMinutes = 2; // Watchdog check interval
  int fallbackTimerSeconds = 10; // Fallback location check interval
  int locationStallThresholdMinutes = 3; // Time before restart
  
  // Debug settings to Default to Flutter's debug mode write debugMode = kDebugMode; //
  bool debugMode = false;

  // API URLs
  String getApiUrl(bool debugMode) {
    return debugMode
      ? 'http://10.0.2.2:8000/observations'
      : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net/observations';
  }
}