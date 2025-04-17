import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/pages/nav_bars_page.dart';
import 'package:urban_echoes/pages/intro_screen.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/AppStartupService.dart';
import 'package:urban_echoes/services/location_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:urban_echoes/state%20manegers/map_state_manager.dart';
import 'state manegers/page_state_maneger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Enable wakelock to keep screen on
  WakelockPlus.enable();

  // Store the original function
  final originalDebugPrint = debugPrint;

  // Set up proper audio session
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

  // Replace with filtered version
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null &&
        !message.contains('getCurrentPosition') &&
        !message.contains('MediaPlayer')) {
      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };

  // Create service instances before the widget tree
  final locationService = LocationService(); // Use LocationService
  // We're no longer creating appStartupService here since it's created in the provider

  runApp(MyApp(
    debugMode: false,
    locationService: locationService,
  ));
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
        // Create providers at the highest appropriate level
        ChangeNotifierProvider<PageStateManager>(
          create: (context) => PageStateManager(),
        ),
        // Add our new MapStateManager
        ChangeNotifierProvider<MapStateManager>(
          create: (context) => MapStateManager(),
        ),
        // Use .value for objects that already exist
        Provider<bool>.value(value: debugMode),
        // Use .value constructor for pre-created service instances
        ChangeNotifierProvider<LocationService>.value(value: locationService),
        // Add startup service provider
        Provider<AppStartupService>(create: (_) => AppStartupService()),
      ],
      child: MaterialApp(
        title: 'Urban Echoes',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.grey,
          ),
        ),
        home: InitialScreen(),
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
      // Try-catch to handle potential provider errors
      try {
        // Initialize the location service only once
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Use try-catch to safely access the provider
          try {
            if (mounted) {
              // Initialize location service
              Provider.of<LocationService>(context, listen: false)
                  .initialize(context);

              // Run eBird sync in background - ADD THIS SECTION
              final appStartupService =
                  Provider.of<AppStartupService>(context, listen: false);
              appStartupService.runStartupTasks();
            }
          } catch (e) {
            debugPrint('Error initializing services: $e');
          }

          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }
        });
      } catch (e) {
        debugPrint('Error in post-frame callback: $e');
        _isInitializing = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Safely access the LocationService provider
    if (!mounted) return;

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      if (state == AppLifecycleState.resumed) {
        // App is in the foreground - enable tracking and wakelock
        WakelockPlus.enable(); // Re-enable wakelock when app is resumed
        if (!locationService.isLocationTrackingEnabled) {
          locationService.toggleLocationTracking(true);
        }

        // You can also refresh eBird data when the app is resumed if desired
        // Provider.of<AppStartupService>(context, listen: false).syncEBirdObservations();
      } else if (state == AppLifecycleState.paused) {
        // App is in the background - disable tracking and wakelock to save battery
        WakelockPlus.disable(); // Disable wakelock when app is paused
        if (locationService.isLocationTrackingEnabled) {
          locationService.toggleLocationTracking(false);
        }
      }
    } catch (e) {
      debugPrint('Error accessing services in lifecycle: $e');
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstTime) {
      return IntroScreen(
        onDone: () {
          setState(() {
            _isFirstTime = false;
          });
        },
      );
    } else {
      return NavBarsPage();
    }
  }
}
