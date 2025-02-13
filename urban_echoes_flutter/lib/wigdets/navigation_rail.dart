import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/state%20manegers/railnav_page_state_maneger.dart';

class CustomNavigationRail extends StatelessWidget {
  const CustomNavigationRail({super.key});

  @override
  Widget build(BuildContext context) {
    var railNavPageStateManager = Provider.of<RailNavPageStateManager>(context);

    return NavigationRail(
      extended: MediaQuery.of(context).size.width >= 600,
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
      selectedIndex:
          PageType.values.indexOf(railNavPageStateManager.selectedPage),
      onDestinationSelected: (index) =>
          railNavPageStateManager.setPage(PageType.values[index]),
    );
  }
}
