import 'package:flutter/material.dart';
import 'package:urban_echoes/pages/home_page.dart';
import 'package:urban_echoes/pages/make_observation/make_observation_page.dart';
import 'package:urban_echoes/pages/map_page.dart';

enum NavRailPageType {
  home,
  map
  // Add more pages as needed
}

enum ButtonPageType {
  observation,
  profile,
  // Add more pages as needed
}

class PageStateManager extends ChangeNotifier {
  NavRailPageType selectedNavRailPage = NavRailPageType.home;
  ButtonPageType? selectedButtonPage;

  // Instead of storing widget instances directly, use builder functions
  // that will create the widgets with the current context when needed
  Widget getNavRailPage(BuildContext context) {
    switch (selectedNavRailPage) {
      case NavRailPageType.home:
        return HomePage();
      case NavRailPageType.map:
        return MapPage();
      default:
        return HomePage();
    }
  }

  Widget getButtonPage(BuildContext context) {
    switch (selectedButtonPage) {
      case ButtonPageType.observation:
        return MakeObservationPage();
      case ButtonPageType.profile:
        return Placeholder();
      default:
        return Placeholder();
    }
  }

  void setNavRailPage(NavRailPageType page) {
    selectedNavRailPage = page;
    selectedButtonPage = null;
    notifyListeners();
  }

  void setButtonPage(ButtonPageType page) {
    selectedButtonPage = page;
    notifyListeners();
  }

  Widget getCurrentPage(BuildContext context) {
    if (selectedButtonPage != null) {
      return getButtonPage(context);
    }
    return getNavRailPage(context);
  }
}