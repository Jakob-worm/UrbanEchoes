import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
            BigCard(text: 'Make observation'),
            BigCard(text: 'Profile'),
            ElevatedButton(
              onPressed: () {
                print('Click!');
              },
              child: const Text('A button'),
            ),
          ],
        ),
      ),
    );
  }
}
