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
  final TextEditingController _searchController = TextEditingController();
  int? _selectedNumber;
  bool _isValidInput = false;
  String _validSearchText = '';
  List<String> _suggestions = [];
  List<Map<String, String>> _birdData = [];
  final AudioPlayer _audioPlayer = AudioPlayer(); // Declare AudioPlayer

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<List<Map<String, String>>> fetchBirdSuggestions(
      BuildContext context) async {
    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String baseUrl = debugMode
        ? 'http://127.0.0.1:8000' // Local backend
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net'; // Azure backend

    final response = await http.get(Uri.parse('$baseUrl/birds'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> birds = data['birds'];
      return birds
          .map((bird) => {
                'danishName': bird['danishName'] as String,
                'scientificName': bird['scientificName'] as String,
              })
          .toList();
    } else {
      throw Exception('Failed to load bird names');
    }
  }

  void _fetchSuggestions() async {
    try {
      final suggestions = await fetchBirdSuggestions(context);
      setState(() {
        _suggestions = suggestions.map((bird) => bird['danishName']!).toList();
        _birdData = suggestions; // Store the full bird data
      });
    } catch (e) {
      print('Failed to fetch suggestions: $e');
    }
  }

  Future<void> _playBirdSound(String birdName) async {
    final bool debugMode = Provider.of<bool>(context, listen: false);
    final String baseUrl = debugMode
        ? 'http://127.0.0.1:8000' // Local backend
        : 'https://urbanechoes-fastapi-backend-g5asg9hbaqfvaga9.northeurope-01.azurewebsites.net'; // Azure backend

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/birdsound?scientific_name=$birdName'));

      if (response.statusCode == 200) {
        final formattedUrl = response.body.replaceAll('"', '');
        if (formattedUrl.isNotEmpty) {
          _audioPlayer.setSourceUrl(formattedUrl);
          _audioPlayer.resume();
        } else {
          print('No sound available for $birdName');
        }
      } else {
        print('Failed to fetch bird sound: ${response.statusCode}');
      }
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _handleSubmit() async {
    final searchValue = _searchController.text;
    if (searchValue.isNotEmpty && _selectedNumber != null) {
      print('$searchValue + $_selectedNumber has been recorded');

      // Find the scientific name for the selected Danish name
      final selectedBird = _birdData.firstWhere(
        (bird) => bird['danishName'] == searchValue,
        orElse: () => {'scientificName': ''},
      );

      if (selectedBird['scientificName']!.isNotEmpty) {
        await _playBirdSound(selectedBird[
            'scientificName']!); // Play sound using scientific name
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
              if (_isValidInput) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Vælg mængde af ',
                        style: DefaultTextStyle.of(context)
                            .style
                            .copyWith(fontSize: 20),
                        children: <TextSpan>[
                          TextSpan(
                            text: _pluralize(_validSearchText),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 20),
                          ),
                          TextSpan(
                            text: ' set:',
                            style: TextStyle(fontSize: 20),
                          ),
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
                  ],
                ),
                SizedBox(width: 16),
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
}
