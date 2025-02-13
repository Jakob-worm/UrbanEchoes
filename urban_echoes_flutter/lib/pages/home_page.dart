import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/page_state_maneger.dart';
import 'package:urban_echoes/wigdets/big_card.dart';
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
  String get randomImage => images[random.nextInt(images.length)];

  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var pageStateManager = Provider.of<PageStateManager>(context);

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
            BigCard(
              text: 'Make observation',
              onPressed: () => pageStateManager
                  .setPage(1), // Navigate to the "Make observation" page
              imageUrl: randomImage, // Use the random image
            ),
            BigCard(
              text: 'Profile',
              onPressed: () => print('Profile pressed'),
            ),
          ],
        ),
      ),
    );
  }
}
