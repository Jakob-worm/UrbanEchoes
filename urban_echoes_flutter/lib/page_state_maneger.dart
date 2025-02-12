import 'package:flutter/material.dart';
import 'package:urban_echoes/main.dart';
import 'package:urban_echoes/pages/backend_test.dart';
import 'package:urban_echoes/pages/home_page.dart';
import 'package:urban_echoes/pages/map_page.dart';
import 'package:urban_echoes/pages/take_image_page.dart';

class PageStateManeger extends State<MyHomePage> {
  var selectedIndex = 0;
  Widget page = HomePage();

  void setPage(Widget page) {
    setState(() {
      this.page = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    switch (selectedIndex) {
      case 0:
        setPage(HomePage());
        break;
      case 1:
        setPage(TakeImagePage());
        break;
      case 2:
        setPage(BackEndTest());
        break;
      case 3:
        setPage(MapPage());
        break;
      default:
        throw UnimplementedError('No widget for $selectedIndex');
    }

    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              children: [
                Expanded(child: mainArea),
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
                    currentIndex: selectedIndex,
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
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
                        label: Text('camera'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.abc),
                        label: Text('Backend Test'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.map),
                        label: Text('Map'),
                      )
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
      ),
    );
  }
}