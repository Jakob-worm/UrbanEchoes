import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/speach_regognition/bird_regognition_service.dart';

class BirdHomePage extends StatefulWidget {
  const BirdHomePage({super.key});

  @override
  _BirdHomePageState createState() => _BirdHomePageState();
}

class _BirdHomePageState extends State<BirdHomePage> with SingleTickerProviderStateMixin {
  late Animation<double> _pulseAnimation;
  late AnimationController _pulseAnimationController;

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Setup pulsing animation for the microphone button
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _pulseAnimationController.repeat(reverse: true);
    
      WidgetsBinding.instance.addPostFrameCallback((_) {
    final birdService = Provider.of<BirdRecognitionService>(context, listen: false);
    if (birdService.isInitialized && birdService.isDataInitialized) {
      // Set test mode to false to use all birds
      birdService.setTestMode(false);
      debugPrint("Test mode set after initialization");
    }
  });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BirdRecognitionService>(
      builder: (context, birdService, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dansk Fugle Genkendelse'),
            backgroundColor: Colors.green[700],
            elevation: 0,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green[700]!,
                  Colors.green[100]!,
                ],
              ),
            ),
            child: Column(
              children: [
                // Status bar
                Container(
                  color: birdService.isListening 
                      ? Colors.red.withOpacity(0.8) 
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        birdService.isListening ? Icons.mic : Icons.mic_off,
                        color: birdService.isListening ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          birdService.isListening 
                              ? 'Lytter efter fuglenavne...' 
                              : 'Tryk på mikrofonen for at starte',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: birdService.isListening ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      children: [
                        const SizedBox(height: 30),
                        
                        // Recognized text card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Genkendt tale:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    birdService.recognizedText.isNotEmpty 
                                        ? birdService.recognizedText 
                                        : 'Intet genkendt endnu',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Matched bird card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Matchende fugl:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: birdService.matchedBird.isNotEmpty 
                                        ? Colors.green[50] 
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: birdService.matchedBird.isNotEmpty 
                                              ? Colors.green[800] 
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      if (birdService.confidence > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            'Sikkerhed: ${(birdService.confidence * 100).toStringAsFixed(1)}%',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Possible matches
                        if (birdService.possibleMatches.length > 1)
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Andre mulige matches:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: birdService.possibleMatches
                                        .skip(1) // Skip the first one as it's already shown as the main match
                                        .map((bird) => Chip(
                                              label: Text(bird),
                                              backgroundColor: Colors.amber[100],
                                              labelStyle: TextStyle(color: Colors.brown[800]),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                        // Stats card
                        Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statistik:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text('Antal forsøg: ${birdService.recognitionAttempts}'),
                                Text('Succesfulde matches: ${birdService.successfulMatches}'),
                                Text('Succesrate: ${(birdService.successRate * 100).toStringAsFixed(1)}%'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 100), // Extra space for the FAB
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Large microphone button
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120, // Larger button
                    height: 120, // Larger button
                    margin: const EdgeInsets.only(bottom: 30),
                    child: FloatingActionButton(
                      onPressed: () {
                        if (birdService.isListening) {
                          birdService.stopListening();
                        } else {
                          birdService.startListening();
                        }
                      },
                      backgroundColor: birdService.isListening ? Colors.red : Colors.green[600],
                      child: Icon(
                        birdService.isListening ? Icons.mic_off : Icons.mic,
                        size: 50, // Larger icon
                        color: Colors.white,
                      ),
                      elevation: 8,
                    ),
                  ),
                ),
                // Button label
                Text(
                  birdService.isListening ? 'Stop lytning' : 'Start lytning',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black38,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}