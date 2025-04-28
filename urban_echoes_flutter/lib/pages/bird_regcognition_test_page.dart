import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';

class BirdRecognitionTestPage extends StatefulWidget {
  const BirdRecognitionTestPage({super.key});

  @override
  _BirdRecognitionTestPageState createState() => _BirdRecognitionTestPageState();
}

class _BirdRecognitionTestPageState extends State<BirdRecognitionTestPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Test mode variables
  bool _showTestControls = true;
  final List<String> _testLog = [];
  
  @override
  void initState() {
    super.initState();
    
    // Set up animation for microphone button
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Add to test log
  void _addToLog(String message) {
    setState(() {
      _testLog.add("[${DateTime.now().toString().split('.').first}] $message");
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<BirdRecognitionService>(
      builder: (context, birdService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Bird Recognition Test'),
            actions: [
              IconButton(
                icon: Icon(_showTestControls ? Icons.visibility_off : Icons.visibility),
                tooltip: _showTestControls ? 'Hide test controls' : 'Show test controls',
                onPressed: () {
                  setState(() {
                    _showTestControls = !_showTestControls;
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Recognition status bar
              Container(
                color: birdService.isListening ? Colors.green : Colors.grey[200],
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      birdService.isListening ? Icons.mic : Icons.mic_off,
                      color: birdService.isListening ? Colors.white : Colors.grey,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        birdService.isListening 
                            ? 'Lytter...' 
                            : 'Tryk på mikrofonen for at starte',
                        style: TextStyle(
                          color: birdService.isListening ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (birdService.isInitialized)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      )
                    else
                      Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 16,
                      ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    // Recognized text card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Genkendt tale:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                birdService.recognizedText.isNotEmpty 
                                    ? birdService.recognizedText 
                                    : 'Intet genkendt endnu',
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Matched bird card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Matchende fugl:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: birdService.matchedBird.isNotEmpty 
                                    ? Colors.green[50] 
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: birdService.matchedBird.isNotEmpty 
                                      ? Colors.green 
                                      : Colors.grey[300]!,
                                  width: birdService.matchedBird.isNotEmpty ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    birdService.matchedBird.isNotEmpty 
                                        ? birdService.matchedBird 
                                        : 'Intet match fundet',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: birdService.matchedBird.isNotEmpty 
                                          ? Colors.green[800] 
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  if (birdService.confidence > 0)
                                    Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Sikkerhed: ${(birdService.confidence * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Error message if any
                    if (birdService.errorMessage != null)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Card(
                          elevation: 3,
                          color: Colors.red[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    birdService.errorMessage!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.red[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Test controls (can be toggled)
                    if (_showTestControls) ...[
                      SizedBox(height: 24),
                      Divider(thickness: 2),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'TEST CONTROLS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // Test statistics
                      Card(
                        elevation: 2,
                        color: Colors.blue[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Test Statistics',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text('Recognition Attempts: ${birdService.recognitionAttempts}'),
                              Text('Successful Matches: ${birdService.successfulMatches}'),
                              Text('Success Rate: ${(birdService.successRate * 100).toStringAsFixed(1)}%'),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      birdService.resetStatistics();
                                      _addToLog('Statistics reset');
                                    },
                                    child: Text('Reset Statistics'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Available bird names
                      Card(
                        elevation: 2,
                        color: Colors.amber[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Bird Names',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: birdService.birdNames.map((bird) {
                                  return Chip(
                                    label: Text(bird),
                                    backgroundColor: Colors.white,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Test log
                      Card(
                        elevation: 2,
                        color: Colors.grey[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Test Log',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _testLog.clear();
                                      });
                                    },
                                    child: Text('Clear'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.all(8),
                                  itemCount: _testLog.length,
                                  reverse: true,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        _testLog[_testLog.length - 1 - index],
                                        style: TextStyle(
                                          color: Colors.green[300],
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: ScaleTransition(
            scale: _animation,
            child: FloatingActionButton.large(
              onPressed: () {
                if (birdService.isListening) {
                  birdService.stopListening();
                  _addToLog('Listening stopped');
                } else {
                  birdService.startListening();
                  _addToLog('Listening started');
                }
              },
              tooltip: birdService.isListening ? 'Stop lytning' : 'Start lytning',
              backgroundColor: birdService.isListening ? Colors.red : Colors.green,
              child: Icon(
                birdService.isListening ? Icons.mic_off : Icons.mic,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }
}