import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';
import 'package:urban_echoes/wigdets/navigation_items.dart';

class NavBarsPage extends StatelessWidget {
  const NavBarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var pageStateManager = Provider.of<PageStateManager>(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return Column(
              children: [
                Expanded(child: pageStateManager.currentPage),
                SafeArea(
                  child: NavigationItems(isRail: false),
                ),
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationItems(
                      isRail: true, isExtended: constraints.maxWidth >= 600),
                ),
                Expanded(child: pageStateManager.currentPage),
              ],
            );
          }
        },
      ),
    );
  }
}
