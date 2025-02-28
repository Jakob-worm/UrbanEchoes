import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/searchbar.dart';

class BirdSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final List<String> suggestions;
  final Function(bool) onValidInput;
  final bool isLoading;
  final String errorMessage;

  const BirdSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.suggestions,
    required this.onValidInput,
    this.isLoading = false,
    this.errorMessage = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FractionallySizedBox(
          widthFactor: 0.7,
          child: Column(
            children: [
              Searchbar(
                controller: controller,
                onChanged: onChanged,
                suggestions: suggestions,
                onValidInput: onValidInput,
                isLoading: isLoading,
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
        if (errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
