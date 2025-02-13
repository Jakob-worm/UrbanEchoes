import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';
import 'package:urban_echoes/wigdets/searchbar.dart' as custom;
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
            FractionallySizedBox(
              widthFactor:
                  0.85, // Set the total width to 85% of the screen width
              child: Row(
                children: [
                  Expanded(
                    flex: 9, // Adjust the flex value to control the proportion
                    child: custom.SearchBar(
                      controller: TextEditingController(),
                      onChanged: (value) => print('Search value: $value'),
                    ),
                  ),
                  SizedBox(width: 16), // Add some space between the widgets
                  Expanded(
                    flex: 1, // Adjust the flex value to control the proportion
                    child: DropdownNumbers(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16), // Add some space between the rows
            BigCustomButton(
              text: 'Submit',
              onPressed: () => print('Submit pressed'),
            ),
            BigCustomButton(
              text: 'I am unsure about what I saw/heard',
              onPressed: () => print('Unsure pressed'),
            ),
          ],
        ),
      ),
    );
  }
}
