import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state manegers/page_state_maneger.dart';

class NavBarsPage extends StatelessWidget {
  const NavBarsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pageStateManager = Provider.of<PageStateManager>(context);
    
    return Scaffold(
      // Main content area - full screen without side rail
      body: pageStateManager.getCurrentPage(context),
      
      // Bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: pageStateManager.selectedNavRailPage.index,
        onTap: (index) {
          pageStateManager.setNavRailPage(NavRailPageType.values[index]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          // Add more items as needed
        ],
      ),
      
      // Floating action buttons for additional functionality
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "observationButton",
            onPressed: () {
              pageStateManager.setButtonPage(ButtonPageType.observation);
            },
            tooltip: 'Make Observation',
            child: const Icon(Icons.add_location),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "profileButton",
            onPressed: () {
              pageStateManager.setButtonPage(ButtonPageType.profile);
            },
            tooltip: 'Profile',
            child: const Icon(Icons.person),
          ),
        ],
      ),
    );
  }
}