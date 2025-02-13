import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/state%20manegers/railnav_page_state_maneger.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  const CustomBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    var railNavPageStateManager = Provider.of<RailNavPageStateManager>(context);

    return BottomNavigationBar(
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
      currentIndex:
          PageType.values.indexOf(railNavPageStateManager.selectedPage),
      onTap: (index) => railNavPageStateManager.setPage(PageType.values[index]),
    );
  }
}
