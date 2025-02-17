import 'package:flutter/material.dart';

class Searchbar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<String> suggestions;
  final ValueChanged<bool> onValidInput;

  const Searchbar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.suggestions,
    required this.onValidInput,
  });

  @override
  _SearchbarState createState() => _SearchbarState();
}

class _SearchbarState extends State<Searchbar> {
  List<String> _filteredSuggestions = [];

  void _updateSuggestions(String query) {
    setState(() {
      _filteredSuggestions = widget.suggestions
          .where((term) => term.toLowerCase().contains(query.toLowerCase()))
          .toList();
      widget.onValidInput(_filteredSuggestions.contains(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        children: [
          TextField(
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
          if (_filteredSuggestions.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: 50, // Position it below the search bar
              child: Material(
                elevation: 4, // Ensure visibility above other elements
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  constraints: BoxConstraints(maxHeight: 200), // Limit height
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredSuggestions.length,
                    itemBuilder: (context, index) {
                      final result = _filteredSuggestions[index];
                      return ListTile(
                        title: Text(result),
                        onTap: () {
                          widget.controller.text = result;
                          widget.onChanged(result);
                          widget.onValidInput(true);
                          setState(() {
                            _filteredSuggestions.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
