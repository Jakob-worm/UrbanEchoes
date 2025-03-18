import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/pages/nav_bars_page.dart';
import 'package:urban_echoes/pages/intro_screen.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/LocationService.dart';

import 'state manegers/page_state_maneger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Create service instances before the widget tree
  final locationService = LocationService();
  
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
        // Use .value for objects that already exist
        Provider<bool>.value(value: debugMode),
        // Use .value constructor for pre-created service instances
        ChangeNotifierProvider<LocationService>.value(value: locationService),
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

class InitialScreenState extends State<InitialScreen> with WidgetsBindingObserver {
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
              Provider.of<LocationService>(context, listen: false).initialize(context);
            }
          } catch (e) {
            print('Error initializing LocationService: $e');
          }
          
          if (mounted) {
            setState(() {
              _isInitializing = false;
            });
          }
        });
      } catch (e) {
        print('Error in post-frame callback: $e');
        _isInitializing = false;
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Safely access the LocationService provider
    if (!mounted) return;
    
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      
      if (state == AppLifecycleState.resumed) {
        // App is in the foreground - enable tracking
        if (!locationService.isLocationTrackingEnabled) {
          locationService.toggleLocationTracking(true);
        }
      } else if (state == AppLifecycleState.paused) {
        // App is in the background - disable tracking to save battery
        if (locationService.isLocationTrackingEnabled) {
          locationService.toggleLocationTracking(false);
        }
      }
    } catch (e) {
      print('Error accessing LocationService in lifecycle: $e');
    }
  }

  @override
  void dispose() {
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