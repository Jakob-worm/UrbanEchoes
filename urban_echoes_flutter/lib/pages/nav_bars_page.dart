import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state manegers/page_state_maneger.dart';

class NavBarsPage extends StatelessWidget {
  const NavBarsPage({super.key});

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
    );
  }
}