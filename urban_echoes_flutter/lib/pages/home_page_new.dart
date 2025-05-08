import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/speach_regognition/speech_coordinator.dart';
import 'package:urban_echoes/wigdets/manual_bird_inputcard.dart';

/// Main screen for the bird observation app
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
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppStyles.primaryColor,
      elevation: 0,
      title: const Text(
        'Urban Echoes',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SpeechCoordinator coordinator) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppStyles.primaryColor,
            AppStyles.secondaryColor,
          ],
        ),
      ),
      child: Column(
        children: [
          _buildStatusBar(coordinator),
          Expanded(
            child: _buildMainContent(coordinator),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(SpeechCoordinator coordinator) {
    return Container(
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
    );
  }

 Widget _buildMainContent(SpeechCoordinator coordinator) {
  // Adjust bottom padding based on whether FAB is showing
  final bool shouldShowFAB = !(coordinator.isSystemInDoubt && coordinator.possibleBirds.isNotEmpty) && 
                            !coordinator.isManualInputActive;
  final double bottomPadding = shouldShowFAB ? 150.0 : 20.0;
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: ListView(
      children: [
        const SizedBox(height: 30),
        SpeechRecognitionCard(coordinator: coordinator),
        const SizedBox(height: 20),
        if (coordinator.isWaitingForConfirmation)
          ConfirmationCard(
            birdName: coordinator.currentBirdInQuestion,
            onConfirm: () => coordinator.handleConfirmationResponse(true),
            onDeny: () => coordinator.handleConfirmationResponse(false),
          ),
        if (coordinator.isSystemInDoubt && coordinator.possibleBirds.isNotEmpty)
          SystemInDoubtCard(
            possibleBirds: coordinator.possibleBirds,
            onBirdSelected: coordinator.handleBirdSelection,
            onDismiss: () {
              coordinator.resetConfirmationState();
              // Manual input is now activated in the SystemInDoubtCard widget
            },
          ),
        // Add the new ManualBirdInputCard
        if (coordinator.isManualInputActive)
          ManualBirdInputCard(
            coordinator: coordinator,
            onCancel: () {
              coordinator.deactivateManualInput();
              if (!coordinator.isListening) {
                coordinator.startListening();
              }
            },
            onBirdSelected: (birdName) {
              coordinator.handleManualBirdSelection(birdName);
            },
          ),
        SizedBox(height: bottomPadding), // Dynamic space based on FAB visibility
      ],
    ),
  );
}

  Widget _buildFloatingActionButton(BuildContext context, SpeechCoordinator coordinator) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              margin: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                onPressed: () => _handleMicButtonPressed(context, coordinator),
                backgroundColor: coordinator.isListening ? Colors.red : AppStyles.primaryColor,
                elevation: 8,
                child: Icon(
                  coordinator.isListening ? Icons.mic_off : Icons.mic,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Text(
            coordinator.isListening ? 'Stop observation' : 'Start observation',
            style: AppStyles.buttonLabelStyle,
          ),
        ],
      ),
    );
  }

  void _handleMicButtonPressed(BuildContext context, SpeechCoordinator coordinator) {
    if (coordinator.isListening) {
      coordinator.stopListening();
    } else {
      if (_isProcessing) return;
      setState(() => _isProcessing = true);

      coordinator.startListening();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeechCoordinator>(
      builder: (context, coordinator, child) {
        // Hide FAB when SystemInDoubtCard is visible or ManualBirdInputCard is visible
        final bool shouldShowFAB = !(coordinator.isSystemInDoubt && coordinator.possibleBirds.isNotEmpty) && 
                                !coordinator.isManualInputActive;
        
        return Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(context, coordinator),
          floatingActionButton: shouldShowFAB ? _buildFloatingActionButton(context, coordinator) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

/// Card for displaying recognized speech and matched bird
class SpeechRecognitionCard extends StatelessWidget {
  const SpeechRecognitionCard({super.key, required this.coordinator});

  final SpeechCoordinator coordinator;

  Widget _buildRecognizedTextHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Genkendt tale:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppStyles.primaryTextColor,
          ),
        ),
        if (coordinator.recognizedText.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              coordinator.clearRecognizedText();
            },
            tooltip: 'Ryd tekst',
          ),
      ],
    );
  }

  Widget _buildRecognizedTextContent() {
    return Container(
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
    );
  }

  Widget _buildMatchedBirdHeader() {
    return Text(
      'Genkendt fugl:',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue[800],
      ),
    );
  }

  Widget _buildMatchedBirdContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Text(
        coordinator.birdService.matchedBird,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          height: 1.3,
          color: Colors.blue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: AppStyles.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecognizedTextHeader(),
            const SizedBox(height: 10),
            _buildRecognizedTextContent(),
            if (coordinator.birdService.matchedBird.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildMatchedBirdHeader(),
              const SizedBox(height: 10),
              _buildMatchedBirdContent(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card for confirming bird observations
class ConfirmationCard extends StatelessWidget {
  final String birdName;
  final VoidCallback onConfirm;
  final VoidCallback onDeny;

  const ConfirmationCard({
    super.key,
    required this.birdName,
    required this.onConfirm,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              'Er det en $birdName?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            
            // Add a subtitle to indicate voice confirmation is possible
            Text(
              'Sig "ja" eller "nej", eller tryk på knapperne',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
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
                  onPressed: onConfirm,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text('Nej', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: onDeny,
                ),
              ],
            ),
            
            // Visual indicator that microphone is active
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic, 
                  color: Colors.amber[700],
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Lytter efter svar...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for when the system is in doubt between multiple birds
class SystemInDoubtCard extends StatelessWidget {
  const SystemInDoubtCard({
    super.key,
    required this.possibleBirds,
    required this.onBirdSelected,
    required this.onDismiss,
  });

  final Function(String) onBirdSelected;
  final VoidCallback onDismiss;
  final List<String> possibleBirds;

  Widget _buildBirdOption(String bird) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.pets, color: Colors.white),
        label: Text(
          bird,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple[600],
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () => onBirdSelected(bird),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get coordinator from Provider to activate manual input
    final coordinator = Provider.of<SpeechCoordinator>(context, listen: false);
    
    return Card(
      elevation: 6,
      color: Colors.purple[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.purple, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            ...possibleBirds.map((bird) => _buildBirdOption(bird)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.white),
                label: const Text(
                  'Ingen af dem',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  // Call the provided onDismiss callback
                  onDismiss();
                  
                  // Also activate manual input
                  coordinator.activateManualInput();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centralized styles for the app
class AppStyles {
  // Text Styles
  static const buttonLabelStyle = TextStyle(
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
  );

  // Shapes
  static final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(15),
  );

  // Colors
  static final Color primaryColor = Colors.green[700]!;

  static final Color primaryTextColor = Colors.green[800]!;
  static final Color secondaryColor = Colors.green[100]!;
}