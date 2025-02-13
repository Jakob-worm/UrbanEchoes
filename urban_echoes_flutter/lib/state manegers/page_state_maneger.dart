import 'package:flutter/material.dart';
import 'package:urban_echoes/pages/backend_test.dart';
import 'package:urban_echoes/pages/home_page.dart';
import 'package:urban_echoes/pages/make_observation_page.dart';
import 'package:urban_echoes/pages/map_page.dart';
import 'package:urban_echoes/pages/take_image_page.dart';

enum NavRailPageType {
  home,
  takeImage,
  backendTest,
  map,
  // Add more pages as needed
}

enum ButtonPageType {
  observation,
  // Add more pages as needed
}

class PageStateManager extends ChangeNotifier {
  NavRailPageType selectedNavRailPage = NavRailPageType.home;
  ButtonPageType? selectedButtonPage;

  final Map<NavRailPageType, Widget> navRailPages = {
    NavRailPageType.home: HomePage(),
    NavRailPageType.takeImage: TakeImagePage(),
    NavRailPageType.backendTest: BackEndTest(),
    NavRailPageType.map: MapPage(),
    // Add more pages as needed
  };

  final Map<ButtonPageType, Widget> buttonPages = {
    ButtonPageType.observation: MakeObservationPage(),
    // Add more pages as needed
  };

  void setNavRailPage(NavRailPageType page) {
    selectedNavRailPage = page;
    selectedButtonPage = null;
    notifyListeners();
  }

  void setButtonPage(ButtonPageType page) {
    selectedButtonPage = page;
    notifyListeners();
  }

  Widget get currentPage {
    if (selectedButtonPage != null) {
      return buttonPages[selectedButtonPage]!;
    }
    return navRailPages[selectedNavRailPage]!;
  }
}
