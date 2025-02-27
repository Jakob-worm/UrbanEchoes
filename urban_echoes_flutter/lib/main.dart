import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/pages/nav_bars_page.dart';
import 'package:urban_echoes/pages/intro_screen.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(MyApp(debugMode: true));
}

class MyApp extends StatelessWidget {
  final bool debugMode;
  const MyApp({super.key, required this.debugMode});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PageStateManager()),
        Provider<bool>(create: (context) => debugMode),
      ],
      child: MaterialApp(
        title: 'Urban Echoes',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: Colors.black, // Change this to a visible color
            selectedItemColor: Colors.white, // Selected icon color
            unselectedItemColor: Colors.grey, // Unselected icon color
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

class InitialScreenState extends State<InitialScreen> {
  bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
    }

    setState(() {
      _isFirstTime = isFirstTime;
    });
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
