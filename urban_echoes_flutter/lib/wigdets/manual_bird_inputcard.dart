import 'package:flutter/material.dart';
import 'package:urban_echoes/services/speach_regognition/speech_coordinator.dart';

/// Card for manual bird name input with auto-suggestions
class ManualBirdInputCard extends StatefulWidget {
  final SpeechCoordinator coordinator;
  final VoidCallback onCancel;
  final Function(String) onBirdSelected;

  const ManualBirdInputCard({
    super.key,
    required this.coordinator,
    required this.onCancel,
    required this.onBirdSelected,
  });

  @override
  ManualBirdInputCardState createState() => ManualBirdInputCardState();
}

class ManualBirdInputCardState extends State<ManualBirdInputCard> {
  final TextEditingController _textController = TextEditingController();
  List<String> _filteredBirdNames = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBirdNames();
    
    // Play the audio prompt when the card appears
    _playInputPrompt();
  }
  
  // Play the audio prompt for manual input
  void _playInputPrompt() {
    // Access the audio service through the coordinator
    final audioService = widget.coordinator.audioService;
    
    // Play the specified prompt
    // Using playPrompt assumes you have this file in your prompts directory
    audioService.playPrompt('indtast_den_fulg_du_så');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadBirdNames() async {
    setState(() {
      _isLoading = true;
    });

    // Use the BirdDataLoader to load bird names
    final birdLoader = widget.coordinator.birdDataLoader;
    await birdLoader.loadBirdNames();
    
    // Initially show empty list
    setState(() {
      _filteredBirdNames = [];
      _isLoading = false;
    });
  }

  void _filterBirdNames(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBirdNames = [];
      });
      return;
    }

    final birdLoader = widget.coordinator.birdDataLoader;
    final searchResults = birdLoader.searchBirds(query);
    
    setState(() {
      _filteredBirdNames = searchResults.take(5).toList(); // Limit to 5 suggestions
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.blue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Skriv fuglens navn:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Input field
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Indtast fuglenavn...',
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _textController.clear();
                    setState(() {
                      _filteredBirdNames = [];
                    });
                  },
                ),
              ),
              onChanged: _filterBirdNames,
            ),
            
            // Loading indicator or suggestions list
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (_filteredBirdNames.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredBirdNames.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_filteredBirdNames[index]),
                      onTap: () {
                        widget.onBirdSelected(_filteredBirdNames[index]);
                      },
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Submit button
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Bekræft', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _textController.text.isNotEmpty
                      ? () => widget.onBirdSelected(_textController.text)
                      : null,
                ),
                
                // Cancel button
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text('Annuller', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}