import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/pages/bird_regcognition_test_page.dart';
import 'package:urban_echoes/pages/nav_bars_page.dart';
import 'package:urban_echoes/pages/intro_screen.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/AppStartupService.dart';
import 'package:urban_echoes/services/location_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:urban_echoes/services/season_service.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';
import 'package:urban_echoes/state%20manegers/map_state_manager.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:urban_echoes/services/tts_service.dart';
import 'package:urban_echoes/services/service_config.dart';


Future<void> main() async {
  try {
    await _initializeApp();
    final locationService = await _initializeServices();

    runApp(MyApp(
      debugMode: ServiceConfig().debugMode, // Set to true to enable development features
      locationService: locationService,
    ));
  } catch (e) {
    debugPrint('Fatal error during app initialization: $e');
    // You might want to show an error screen here instead of crashing
  }
}

/// Initialize app-level configurations
Future<void> _initializeApp() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Enable wakelock to keep screen on
  await WakelockPlus.enable();

  // Configure debug print to filter noisy logs
  _configureDebugPrint();

  // Set up proper audio session
  await _configureAudioSession();
}

/// Configure audio session for proper media playback
Future<void> _configureAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
    androidAudioAttributes: const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
  ));
}

/// Configure debug print to filter out noisy logs
void _configureDebugPrint() {
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null &&
        !message.contains('getCurrentPosition') &&
        !message.contains('MediaPlayer')) {
      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };
}

/// Initialize services that need to be created before the widget tree
Future<LocationService> _initializeServices() async {
  // Create and return the location service
  return LocationService();
}

class MyApp extends StatelessWidget {
  final bool debugMode;
  final LocationService locationService;

  const MyApp({
    super.key,
    required this.debugMode,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // State managers
        ChangeNotifierProvider<PageStateManager>(
          create: (context) => PageStateManager(),
        ),
        ChangeNotifierProvider<MapStateManager>(
          create: (context) => MapStateManager(),
        ),

        // Services
        ChangeNotifierProvider<SeasonService>(
          create: (_) => SeasonService(),
        ),
        ChangeNotifierProvider<TtsService>(
          create: (_) => TtsService(),
        ),
        Provider<AppStartupService>(
          create: (_) => AppStartupService(),
        ),
        
        // Add Bird Recognition Service (lazy initialization)
        ChangeNotifierProvider<BirdRecognitionService>(
          // Pass debugMode to the service for detailed logging in test mode
          create: (_) => BirdRecognitionService(debugMode: debugMode),
          // Lazy: true ensures it's only created when first accessed
          lazy: true,
        ),

        // Pre-created instances
        Provider<bool>.value(value: debugMode),
        ChangeNotifierProvider<LocationService>.value(value: locationService),
      ],
      child: MaterialApp(
        title: 'Urban Echoes',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
          ),
        ),
        home: const InitialScreen(),
      ),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  InitialScreenState createState() => InitialScreenState();
}

class InitialScreenState extends State<InitialScreen>
    with WidgetsBindingObserver {
  bool _isFirstTime = true;
  bool _isInitializing = true;
  bool _initializationError = false;
  String _errorMessage = '';
  // Add flag for bird recognition test mode
  bool _showBirdRecognitionTest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstTime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitializing) {
      _initializeServices();
    }
  }

  void _initializeServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted) return;

        // Initialize location service
        final locationService =
            Provider.of<LocationService>(context, listen: false);
        locationService.initialize(context);

        // Run startup tasks in background
        final appStartupService =
            Provider.of<AppStartupService>(context, listen: false);
        appStartupService.runStartupTasks();

        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      } catch (e) {
        debugPrint('Error initializing services: $e');
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _initializationError = true;
            _errorMessage = e.toString();
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      switch (state) {
        case AppLifecycleState.resumed:
          // App is in the foreground - enable tracking and wakelock
          WakelockPlus.enable();
          if (!locationService.isLocationTrackingEnabled) {
            locationService.toggleLocationTracking(true);
          }
          break;

        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
          // App is in the background - disable tracking and wakelock to save battery
          WakelockPlus.disable();
          if (locationService.isLocationTrackingEnabled) {
            locationService.toggleLocationTracking(false);
          }
          break;

        default:
          // Handle any future lifecycle states
          break;
      }
    } catch (e) {
      debugPrint('Error managing app lifecycle: $e');
    }
  }

  @override
  void dispose() {
    // Make sure to disable wakelock when the app is closed
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkFirstTime() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

      if (isFirstTime) {
        await prefs.setBool('isFirstTime', false);
      }

      if (mounted) {
        setState(() {
          _isFirstTime = isFirstTime;
        });
      }
    } catch (e) {
      debugPrint('Error checking first time status: $e');
      // Default to showing intro screen if there's an error
      // This ensures users don't get stuck if preferences are corrupted
      if (mounted) {
        setState(() {
          _isFirstTime = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get debug mode from Provider
    final bool debugMode = Provider.of<bool>(context);
    
    // Show test page if in test mode
    if (_showBirdRecognitionTest) {
      return BirdRecognitionTestPage();
    }
    
    // Show error state if initialization failed
    if (_initializationError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _initializationError = false;
                    _errorMessage = '';
                  });
                  _initializeServices();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading indicator while initializing
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show intro screen for first-time users
    if (_isFirstTime) {
      return IntroScreen(
        onDone: () {
          setState(() {
            _isFirstTime = false;
          });
        },
      );
    }

    // Show main app UI with debug options if in debug mode
    return Scaffold(
      body: const NavBarsPage(),
      // Add a debug FAB only in debug mode
      floatingActionButton: debugMode ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _showBirdRecognitionTest = true;
          });
        },
        backgroundColor: Colors.purple,
        mini: true,
        tooltip: 'Bird Recognition Test Mode',
        child: const Text('T', style: TextStyle(fontWeight: FontWeight.bold)),
      ) : null,
    );
  }
}