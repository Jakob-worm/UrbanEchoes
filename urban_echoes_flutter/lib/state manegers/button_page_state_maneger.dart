import 'package:flutter/material.dart';
import 'package:urban_echoes/pages/make_observation_page.dart';

enum ButtonPages {
  observation,
  // Add more pages as needed
}

class ButtonPageStateManeger extends ChangeNotifier {
  ButtonPages? selectedPage;
  final Map<ButtonPages, Widget> pages = {
    ButtonPages.observation: MakeObservationPage(),
    // Add more pages as needed
  };

  void setPage(ButtonPages page) {
    selectedPage = page;
    notifyListeners();
  }

  Widget? get currentPage => selectedPage != null ? pages[selectedPage] : null;
}
