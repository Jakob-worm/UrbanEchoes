import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/pages/nav_bars_page.dart';
import 'package:urban_echoes/pages/intro_screen.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/LocationService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(debugMode: false));
}

class MyApp extends StatelessWidget {
  final bool debugMode;

  const MyApp({super.key, required this.debugMode});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PageStateManager()),
        Provider<bool>.value(value: debugMode),
        // Make LocationService a ChangeNotifierProvider so widgets can listen to it
        ChangeNotifierProvider(create: (context) => LocationService()),
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
      // Initialize the location service only once
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<LocationService>(context, listen: false).initialize(context);
        setState(() {
          _isInitializing = false;
        });
      });
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Manage resource usage based on app lifecycle
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