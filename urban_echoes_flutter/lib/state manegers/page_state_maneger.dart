import 'package:flutter/material.dart';
import 'package:urban_echoes/pages/home_page_new.dart';
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
  Map<String, dynamic>? newObservationData;

    // Add this flag to track when map needs refreshing
  bool _needsMapRefresh = false;
  bool get needsMapRefresh => _needsMapRefresh;

  void setNeedsMapRefresh(bool value) {
    _needsMapRefresh = value;
    notifyListeners();
  }

  // Instead of storing widget instances directly, use builder functions
  // that will create the widgets with the current context when needed
  Widget getNavRailPage(BuildContext context) {
    switch (selectedNavRailPage) {
      case NavRailPageType.home:
        return BirdHomePage();
      case NavRailPageType.map:
        return MapPage();
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
