import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import models
import 'package:urban_echoes/models/bird.dart';

// Import controllers
import 'package:urban_echoes/controllers/bird_observation_controller.dart';
import 'package:urban_echoes/pages/make_observation/make_observation_state.dart';

// Import services
import 'package:urban_echoes/services/bird_search_service.dart';

// Import exceptions
import 'package:urban_echoes/exceptions/api_exceptions.dart';
import 'package:urban_echoes/state%20manegers/page_state_maneger.dart';

// Import state definitions

// Import screen-specific widgets
import 'package:urban_echoes/wigdets/bird_search_bar.dart';
import 'package:urban_echoes/wigdets/quantity_selector.dart';

// Import shared widgets
import 'package:urban_echoes/wigdets/big_custom_button.dart';

class MakeObservationPage extends StatefulWidget {
  const MakeObservationPage({super.key});

  @override
  MakeObservationPageState createState() => MakeObservationPageState();
}

class MakeObservationPageState extends State<MakeObservationPage> {
  final _controller = BirdObservationController();
  final TextEditingController _searchController = TextEditingController();

  List<Bird> _birds = [];
  List<String> _suggestions = [];
  Timer? _debounce;

  bool _isValidInput = false;
  int? _selectedNumber;
  String _validSearchText = '';
  ObservationState _state = ObservationState.initial;
  String _errorMessage = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (mounted) {
        setState(() {
          _isSearching = true;
          _errorMessage = '';
        });
      }

      try {
        final bool debugMode = Provider.of<bool>(context, listen: false);
        final birds = await BirdSearchService.searchBirds(query, debugMode);

        if (mounted) {
          setState(() {
            _birds = birds;
            _suggestions = birds.map((bird) => bird.commonName).toList();
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e is BirdSearchException
                ? e.message
                : 'Failed to search for birds';
            _isSearching = false;
          });
        }
      }
    });
  }

  void _handleValidInput(bool isValid) {
    setState(() {
      _isValidInput = isValid;
      _validSearchText = isValid ? _searchController.text : '';
    });
  }

  Future<void> _handleSubmit() async {
    final searchValue = _searchController.text;
    if (searchValue.isEmpty || _selectedNumber == null) {
      _showErrorSnackbar('Please fill in both the bird name and quantity');
      return;
    }

    setState(() {
      _state = ObservationState.loading;
    });

    try {
      final selectedBird = _birds.firstWhere(
        (bird) => bird.commonName == searchValue,
        orElse: () => Bird(commonName: searchValue, scientificName: ''),
      );

      final success = await _controller.submitObservation(
          searchValue, selectedBird.scientificName, _selectedNumber!);

      setState(() {
        _state = success ? ObservationState.success : ObservationState.error;
      });

      if (success) {
        _showSuccessSnackbar('Observation recorded successfully!');

        // Navigate to the map page using PageStateManager
        // This will change the selected tab in the bottom navigation bar
        final pageStateManager =
            Provider.of<PageStateManager>(context, listen: false);
        pageStateManager.setNavRailPage(
            NavRailPageType.values[1]); // Assuming Map is index 1
      } else {
        _showErrorSnackbar('Failed to record observation');
      }
    } catch (e) {
      setState(() {
        _state = ObservationState.error;
        _errorMessage = 'Error: ${e.toString()}';
      });
      _showErrorSnackbar('Error: ${e.toString()}');
    }
  }

  void _resetForm() {
    setState(() {
      _searchController.clear();
      _selectedNumber = null;
      _isValidInput = false;
      _validSearchText = '';
      _state = ObservationState.initial;
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              BirdSearchBar(
                controller: _searchController,
                onChanged: _fetchSuggestions,
                suggestions: _suggestions,
                onValidInput: _handleValidInput,
                isLoading: _isSearching,
                errorMessage: _errorMessage,
              ),
              if (_isValidInput) ...[
                QuantitySelector(
                  birdName: _validSearchText,
                  selectedNumber: _selectedNumber,
                  onNumberChanged: (value) {
                    setState(() {
                      _selectedNumber = value;
                    });
                  },
                ),
              ],
              if (_isValidInput && _selectedNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: BigCustomButton(
                    text: _state == ObservationState.loading
                        ? 'Sender...'
                        : 'Indsend observation',
                    onPressed: _state == ObservationState.loading
                        ? null
                        : _handleSubmit,
                    width: 500,
                    height: 50,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
