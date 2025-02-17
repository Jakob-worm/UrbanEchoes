import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';
import 'package:urban_echoes/wigdets/dropdown_numbers.dart';
import 'package:urban_echoes/wigdets/searchbar.dart';

class MakeObservationPage extends StatefulWidget {
  const MakeObservationPage({super.key});

  @override
  MakeObservationPageState createState() => MakeObservationPageState();
}

class MakeObservationPageState extends State<MakeObservationPage> {
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
        child: SingleChildScrollView(
          // Prevents overflow
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FractionallySizedBox(
                widthFactor: 0.85,
                child: Column(
                  children: [
                    Searchbar(
                      controller: _searchController,
                      onChanged: (value) => print('Search value: $value'),
                      suggestions: _suggestions,
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Select number observed: '),
                  DropdownNumbers(
                    initialValue: _selectedNumber,
                    onChanged: (value) {
                      setState(() {
                        _selectedNumber = value;
                      });
                    },
                  ),
                  BigCustomButton(
                    text: 'Submit',
                    onPressed: _handleSubmit,
                    width: 200,
                    height: 50,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
