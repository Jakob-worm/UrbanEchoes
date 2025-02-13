import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';

class NavBarsPage extends StatelessWidget {
  const NavBarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var pageStateManager = Provider.of<PageStateManager>(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
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
                  selectedIndex: NavRailPageType.values
                      .indexOf(pageStateManager.selectedNavRailPage),
                  onDestinationSelected: (index) => pageStateManager
                      .setNavRailPage(NavRailPageType.values[index]),
                ),
              ),
              Expanded(child: pageStateManager.currentPage),
            ],
          );
        },
      ),
    );
  }
}
