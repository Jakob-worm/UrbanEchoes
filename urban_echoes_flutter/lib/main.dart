import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/page_state_maneger.dart';

import 'app_state_maneger.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => PageStateManager()),
        ChangeNotifierProvider(create: (context) => MyAppState()),
      ],
      child: MaterialApp(
        title: 'Urban Echoes',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var pageStateManager = Provider.of<PageStateManager>(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              children: [
                Expanded(child: pageStateManager.currentPage),
                SafeArea(
                  child: BottomNavigationBar(
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.camera),
                        label: 'Take image page',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.abc),
                        label: 'Backend Test',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.map),
                        label: 'Map',
                      ),
                    ],
                    currentIndex: pageStateManager.selectedIndex,
                    onTap: pageStateManager.setPage,
                  ),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 600,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.camera),
                        label: Text('Take image page'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.abc),
                        label: Text('Backend Test'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.map),
                        label: Text('Map'),
                      ),
                    ],
                    selectedIndex: pageStateManager.selectedIndex,
                    onDestinationSelected: pageStateManager.setPage,
                  ),
                ),
                Expanded(child: pageStateManager.currentPage),
              ],
            );
          }
        },
      ),
    );
  }
}
