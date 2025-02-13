import 'package:flutter/material.dart';
import 'package:urban_echoes/pages/backend_test.dart';
import 'package:urban_echoes/pages/home_page.dart';
import 'package:urban_echoes/pages/map_page.dart';
import 'package:urban_echoes/pages/take_image_page.dart';

class PageStateManager extends ChangeNotifier {
  var selectedIndex = 0;
  final List<Widget> pages = [
    HomePage(),
    TakeImagePage(),
    BackEndTest(),
    MapPage(),
  ];

  void setPage(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  Widget get currentPage => pages[selectedIndex];
}
