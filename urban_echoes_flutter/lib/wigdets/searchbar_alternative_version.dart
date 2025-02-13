import 'package:flutter/material.dart';

class SearchbarAlternative extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<String> suggestions;

  const SearchbarAlternative({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.suggestions,
  });

  @override
  _SearchbarAlternativeState createState() => _SearchbarAlternativeState();
}

class _SearchbarAlternativeState extends State<SearchbarAlternative> {
  List<String> _filteredSuggestions = [];

  void _updateSuggestions(String query) {
    setState(() {
      _filteredSuggestions = widget.suggestions
          .where((term) => term.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: widget.controller,
            onChanged: (value) {
              widget.onChanged(value);
              _updateSuggestions(value);
            },
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
            ),
          ),
        ),
        if (_filteredSuggestions.isNotEmpty)
          Container(
            height: 200, // Set a fixed height for the suggestions
            child: ListView.builder(
              itemCount: _filteredSuggestions.length,
              itemBuilder: (context, index) {
                final result = _filteredSuggestions[index];
                return ListTile(
                  title: Text(result),
                  onTap: () {
                    widget.controller.text = result;
                    widget.onChanged(result);
                    setState(() {
                      _filteredSuggestions.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
