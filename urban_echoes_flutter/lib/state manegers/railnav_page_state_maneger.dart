import 'package:flutter/material.dart';
import 'package:urban_echoes/pages/backend_test.dart';
import 'package:urban_echoes/pages/home_page.dart';
import 'package:urban_echoes/pages/map_page.dart';
import 'package:urban_echoes/pages/take_image_page.dart';

enum PageType {
  home,
  takeImage,
  backendTest,
  map,
  // Add more pages as needed
}

class RailNavPageStateManager extends ChangeNotifier {
  PageType selectedPage = PageType.home;
  final Map<PageType, Widget> pages = {
    PageType.home: HomePage(),
    PageType.takeImage: TakeImagePage(),
    PageType.backendTest: BackEndTest(),
    PageType.map: MapPage(),
    // Add more pages as needed
  };

  void setPage(PageType page) {
    selectedPage = page;
    notifyListeners();
  }

  Widget get currentPage => pages[selectedPage]!;
}
