import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/pages/nav_bars_page.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PageStateManager(),
      child: MaterialApp(
        title: 'Urban Echoes',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: NavBarsPage(),
      ),
    );
  }
}
