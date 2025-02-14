import 'package:flutter/material.dart';
import 'package:urban_echoes/deprecated/searchbar_old.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';
import 'package:urban_echoes/wigdets/dropdown_numbers.dart';

class MakeObservationPageOld extends StatefulWidget {
  const MakeObservationPageOld({super.key});

  @override
  _MakeObservationPageOldState createState() => _MakeObservationPageOldState();
}

class _MakeObservationPageOldState extends State<MakeObservationPageOld> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedNumber = 1;
  final List<String> _suggestions = [
    'bird',
    'tree',
    'flower',
    'river',
    'mountain',
    'animal',
    'insect',
    'fish',
    'cloud',
    'rain',
  ];

  void _handleSubmit() {
    final searchValue = _searchController.text;
    if (searchValue.isNotEmpty) {
      print('$searchValue + ${_selectedNumber.toString()} has been recorded');
    } else {
      print('Please fill in both the search bar and select a number.');
    }
  }

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
                    child: SearchBarOld(
                      controller: _searchController,
                      onChanged: (value) => print('Search value: $value'),
                      suggestions: _suggestions,
                    ),
                  ),
                  SizedBox(width: 16), // Add some space between the widgets
                  Expanded(
                    flex: 1, // Adjust the flex value to control the proportion
                    child: DropdownNumbers(
                      initialValue: _selectedNumber,
                      onChanged: (value) {
                        setState(() {
                          _selectedNumber = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16), // Add some space between the rows
            BigCustomButton(
              text: 'Submit',
              onPressed: _handleSubmit,
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
