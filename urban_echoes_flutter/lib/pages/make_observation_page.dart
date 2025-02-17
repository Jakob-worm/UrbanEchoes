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
  bool _isValidInput = false;
  String _validSearchText = '';
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

  void _handleValidInput(bool isValid) {
    setState(() {
      _isValidInput = isValid;
      if (isValid) {
        _validSearchText = _searchController.text;
      } else {
        _validSearchText = '';
      }
    });
  }

  String _pluralize(String text) {
    if (text.isEmpty) return text;
    if (text.endsWith('s')) return text; // Already plural
    return text + 's';
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
                widthFactor: 0.5,
                child: Column(
                  children: [
                    Searchbar(
                      controller: _searchController,
                      onChanged: (value) {},
                      suggestions: _suggestions,
                      onValidInput: _handleValidInput,
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      text: 'Select amount of ',
                      style: DefaultTextStyle.of(context).style,
                      children: <TextSpan>[
                        TextSpan(
                          text: _pluralize(_validSearchText),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' observed:'),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
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
                    onPressed: _isValidInput ? _handleSubmit : null,
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
