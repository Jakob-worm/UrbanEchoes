import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';
import 'dart:math';

class HomePage extends StatelessWidget {
  // List of image paths
  final List<String> images = [
    'assets/images/dresden-7122254_1920.jpg',
    'assets/images/kingfisher-6562537_1920.jpg',
    'assets/images/song-sparrow-7942522_1920.jpg',
    // Add more image paths as needed
  ];

  // Generate a random index
  final random = Random();

  HomePage({super.key});

  String getRandomImage() {
    return images[random.nextInt(images.length)];
  }

  void handleButtonPress(BuildContext context, ButtonPageType page) {
    var pageStateManager =
        Provider.of<PageStateManager>(context, listen: false);
    pageStateManager.setButtonPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Urban Echoes'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Centers content vertically
          children: [
            BigCustomButton(
              text: 'Make observation',
              onPressed: () => handleButtonPress(
                  context,
                  ButtonPageType
                      .observation), // Navigate to the "Make observation" page
              imageUrl: getRandomImage(), // Use the random image
            ),
            BigCustomButton(
              text: 'Profile',
              onPressed: () => print('Profile pressed'),
            ),
          ],
        ),
      ),
    );
  }
}
