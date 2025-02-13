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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                custom.SearchBar(
                  controller: TextEditingController(),
                  onChanged: (value) => print('Search value: $value'),
                ),
                SizedBox(width: 16), // Add some space between the widgets
                DropdownNumbers(),
              ],
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
