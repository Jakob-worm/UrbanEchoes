import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_card.dart';

class MakeObservationPage extends StatelessWidget {
  const MakeObservationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Make observation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Centers content vertically
          children: [
            BigCard(
              text: 'Take image',
              onPressed: () => print('Take image pressed'),
            ),
            BigCard(
              text: 'Record sound',
              onPressed: () => print('Record sound pressed'),
            ),
          ],
        ),
      ),
    );
  }

}