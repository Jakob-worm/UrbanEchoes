import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/wigdets/big_custom_button.dart';
import 'package:urban_echoes/wigdets/dropdown_numbers.dart';
import 'package:urban_echoes/wigdets/searchbar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:urban_echoes/utils/download_file.dart'; // Import the utility file

class MakeObservationPage extends StatefulWidget {
  const MakeObservationPage({super.key});

  @override
  MakeObservationPageState createState() => MakeObservationPageState();
}

class MakeObservationPageState extends State<MakeObservationPage> {
  final AudioPlayer _audioPlayer = AudioPlayer(); // Declare AudioPlayer
  List<Map<String, String>> _birdData = [];
  bool _isValidInput = false;
  final TextEditingController _searchController = TextEditingController();
  int? _selectedNumber;
  List<String> _suggestions = [];
  String _validSearchText = '';

  @override
  void initState() {
    super.initState();
    _fetchSuggestions(''); // Provide a default value
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) return; // Prevent empty queries

    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String baseUrl = debugMode
        ? 'http://10.0.2.2:8000'
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net';

    try {
      final response = await http.get(Uri.parse('$baseUrl/search_birds?query=$query'));

      if (response.statusCode == 200) {
        final Map<String, dynamic>? data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;
        if (data != null && data.containsKey('birds')) {
          final List<dynamic> birds = data['birds'];
          setState(() {
            _suggestions = birds.map((bird) => bird['common_name'] as String).toList();
            _birdData = birds.map((bird) => {
              'common_name': bird['common_name'] as String,
              'scientificName': bird['scientificName'] as String
            }).toList();
          });
        } else {
          print('No birds found for query: $query');
          setState(() {
            _suggestions = [];
            _birdData = [];
          });
        }
      } else {
        print('Failed to fetch suggestions: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Exception during bird search: $e');
      // Clear suggestions on error
      setState(() {
        _suggestions = [];
        _birdData = [];
      });
    }
  }

  Future<void> _playBirdSound(String scientificName) async {
    await playBirdSound(scientificName, _audioPlayer);
  }

  void _handleSubmit() async {
    final searchValue = _searchController.text;
    if (searchValue.isNotEmpty && _selectedNumber != null) {
      print('$searchValue + $_selectedNumber has been recorded');

      // Find the scientific name for the selected Danish name
      final selectedBird = _birdData.firstWhere(
        (bird) => bird['common_name'] == searchValue,
        orElse: () => {'scientificName': ''},
      );

      if (selectedBird['scientificName']!.isNotEmpty) {
        await _playBirdSound(selectedBird['scientificName']!); // Play sound using scientific name
      } else {
        print('Scientific name not found for $searchValue');
      }
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
    if (text.endsWith('r')) return text; // Already plural
    return '${text}r';
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lav observation'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSearchBar(),
              if (_isValidInput) ...[
                _buildQuantitySelector(theme),
                SizedBox(height: 16),
                DropdownNumbers(
                  initialValue: _selectedNumber,
                  onChanged: (value) {
                    setState(() {
                      _selectedNumber = value;
                    });
                  },
                ),
              ],
              if (_isValidInput && _selectedNumber != null)
                BigCustomButton(
                  text: 'Indsend observation',
                  onPressed: _handleSubmit,
                  width: 500,
                  height: 50,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return FractionallySizedBox(
      widthFactor: 0.7,
      child: Column(
        children: [
          Searchbar(
            controller: _searchController,
            onChanged: (value) => _fetchSuggestions(value),
            suggestions: _suggestions,
            onValidInput: _handleValidInput,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: TextSpan(
                text: 'Vælg mængde af ',
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 15),
                children: <TextSpan>[
                  TextSpan(
                    text: _pluralize(_validSearchText),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 15,
                    ),
                  ),
                  TextSpan(
                    text: ' set:',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
          ],
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
