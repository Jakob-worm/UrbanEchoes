import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/pages/home_page_new.dart';
import 'package:urban_echoes/utils/navigation_provider.dart';
import '../pages/map_page.dart';

class NavBarsPage extends StatelessWidget {
  const NavBarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    
    return Scaffold(
      // Body now uses IndexedStack to maintain state across tab switches
      body: IndexedStack(
        index: navigationProvider.currentIndex,
        children: const [
          BirdHomePage(),
          MapPage(),
        ],
      ),
      
      // Bottom navigation bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationProvider.currentIndex,
        onTap: (index) => navigationProvider.setIndex(index),
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
        ],
      ),
    );
  }
}