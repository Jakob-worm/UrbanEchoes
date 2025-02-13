import 'package:flutter/material.dart';
import 'package:urban_echoes/main.dart';
import 'package:urban_echoes/pages/backend_test.dart';
import 'package:urban_echoes/pages/home_page.dart';
import 'package:urban_echoes/pages/map_page.dart';
import 'package:urban_echoes/pages/take_image_page.dart';

class PageStateManager extends State<MyHomePage> {
  var selectedIndex = 0;
  final List<Widget> pages = [
    HomePage(),
    TakeImagePage(),
    BackEndTest(),
    MapPage(),
  ];

  void setPage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    var mainArea = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: pages[selectedIndex],
      ),
    );

    final navItems = [
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
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    items: navItems,
                    currentIndex: selectedIndex,
                    onTap: setPage,
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
                    destinations: navItems
                        .map((item) => NavigationRailDestination(
                              icon: item.icon,
                              label: Text(item.label ?? ''),
                            ))
                        .toList(),
                    selectedIndex: selectedIndex,
                    onDestinationSelected: setPage,
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
