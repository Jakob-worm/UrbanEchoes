import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';
import 'package:urban_echoes/wigdets/dropdown_numbers.dart';

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
            SearchBar(
              controller: TextEditingController(),
              onChanged: (value) => print('Search value: $value'),
            ),
            SizedBox(width: 16), // Add some space between the widgets
            DropdownNumbers(),
            BigCustomButton(
              text: 'Submit',
              onPressed: () => print('Submit pressed'),
            ),
            BigCustomButton(
                text: 'I am unsure aboubt what i saw/heard',
                onPressed: () => print('Unsure pressed')),
          ],
        ),
      ),
    );
  }
}
