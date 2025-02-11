import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_card.dart';
import 'dart:math';

class HomePage extends StatelessWidget {
  // List of image paths
  final List<String> images = [
    '/images/dresden-7122254_1920.jpg',
    '/images/kingfisher-6562537_1920.jpg',
    '/images/song-sparrow-7942522_1920.jpg',
    // Add more image paths as needed
  ];

  // Generate a random index
  final random = Random();

  HomePage({super.key});
  String get randomImage => images[random.nextInt(images.length)];

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
            BigCard(
              text: 'Make observation',
              onPressed: () => print('Make observation pressed'),
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
