import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';

// This is the main widget that will be used to display the navigation items
// So adding a new item to the navbars should be done in here
class NavigationItems extends StatelessWidget {
  final bool isRail;
  final bool isExtended;

  const NavigationItems(
      {super.key, required this.isRail, this.isExtended = false});

  @override
  Widget build(BuildContext context) {
    var pageStateManager = Provider.of<PageStateManager>(context);

    final items = [
      NavigationRailDestination(
        icon: Icon(Icons.home),
        label: Text('Hjem'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.camera),
        label: Text('tag billde side'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.abc),
        label: Text('Backend Test'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.map),
        label: Text('Kort'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.audio_file),
        label: Text('Audio'),
      ),
    ];

    if (isRail) {
      return NavigationRail(
        extended: isExtended,
        destinations: items,
        selectedIndex: NavRailPageType.values
            .indexOf(pageStateManager.selectedNavRailPage),
        onDestinationSelected: (index) {
          pageStateManager.setNavRailPage(NavRailPageType.values[index]);
        },
      );
    } else {
      return BottomNavigationBar(
        items: items
            .map((item) => BottomNavigationBarItem(
                icon: item.icon, label: item.label.toString()))
            .toList(),
        currentIndex: NavRailPageType.values
            .indexOf(pageStateManager.selectedNavRailPage),
        onTap: (index) {
          pageStateManager.setNavRailPage(NavRailPageType.values[index]);
        },
      );
    }
  }
}
