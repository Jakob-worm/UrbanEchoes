import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';

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
            BigCustomButton(
              text: 'Write text',
              onPressed: () => print('Write text pressed'),
            ),
            BigCustomButton(
              text: 'Take image',
              onPressed: () => print('Take image pressed'),
            ),
            BigCustomButton(
              text: 'Record sound',
              onPressed: () => print('Record sound pressed'),
            ),
          ],
        ),
      ),
    );
  }
}
