// In your BirdHomePage.build method
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/speach_regognition/speech_coordinator.dart';

class BirdHomePage extends StatefulWidget {
  const BirdHomePage({super.key});

  @override
  BirdHomePageState createState() => BirdHomePageState();
}

class BirdHomePageState extends State<BirdHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isProcessing = false;
  late Animation<double> _pulseAnimation;

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeechCoordinator>(
      builder: (context, coordinator, child) {
        final birdService = coordinator.birdService;
        final wordService = coordinator.wordService;

        return Scaffold(
          appBar: AppBar(
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
                  color: coordinator.isListening
                      ? Colors.red.withAlpha((0.8 * 255).toInt())
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Row(
                    children: [
                      Icon(
                        coordinator.isListening ? Icons.mic : Icons.mic_off,
                        color: coordinator.isListening ? Colors.white : Colors.white70,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          coordinator.isListening
                              ? 'Lytter efter tale...'
                              : 'Tryk på mikrofonen for at starte',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: coordinator.isListening ? FontWeight.bold : FontWeight.normal,
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
                                    coordinator.recognizedText.isNotEmpty
                                        ? coordinator.recognizedText
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

                        // Confirmation card (conditionally displayed)
                        if (coordinator.isWaitingForConfirmation)
                          Card(
                            elevation: 6,
                            color: Colors.amber[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: Colors.amber, width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Er det en ${coordinator.currentBirdInQuestion}?',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[800],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.check_circle, color: Colors.white),
                                        label: const Text('Ja', style: TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[600],
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        onPressed: () => coordinator.handleConfirmationResponse(true),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.cancel, color: Colors.white),
                                        label: const Text('Nej', style: TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[600],
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        ),
                                        onPressed: () => coordinator.handleConfirmationResponse(false),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Gentag spørgsmål'),
                                    onPressed: () {
                                      coordinator.audioService.playBirdQuestion(coordinator.currentBirdInQuestion);
                                    },
                                  ),
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
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 30),
                    child: FloatingActionButton(
                      onPressed: () {
                        // Only prevent multiple calls to the SAME function
                        final coordinator = Provider.of<SpeechCoordinator>(context, listen: false);

                        if (coordinator.isListening) {
                          // If already listening, stop listening without debounce
                          coordinator.stopListening();
                        } else {
                          // When starting to listen, apply debounce
                          if (_isProcessing) return; // Only prevent rapid start listening
                          setState(() => _isProcessing = true);
                          coordinator.startListening();

                          // Reset after a short delay
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) setState(() => _isProcessing = false);
                          });
                        }
                      },
                      backgroundColor: coordinator.isListening ? Colors.red : Colors.green[600],
                      elevation: 8,
                      child: Icon(
                        coordinator.isListening ? Icons.mic_off : Icons.mic,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Button label
                Text(
                  coordinator.isListening ? 'Stop observation' : 'Start observation',
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