import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/services/location_service.dart';
import 'package:urban_echoes/services/speach_regognition/speech_coordinator.dart';
import 'package:urban_echoes/wigdets/manual_bird_inputcard.dart';

/// Main screen for the bird observation app
class BirdHomePage extends StatefulWidget {
  const BirdHomePage({super.key});

  @override
  BirdHomePageState createState() => BirdHomePageState();
}

class BirdHomePageState extends State<BirdHomePage> with SingleTickerProviderStateMixin {
  // ===== PROPERTIES =====
  
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;

  // ===== LIFECYCLE METHODS =====
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeServices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ===== INITIALIZATION =====
  
  /// Set up the pulse animation for the microphone button
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  /// Initialize location and audio services after the widget is built
  void _initializeServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      debugPrint('🔊 BirdHomePage post-frame callback - initializing audio services');
      
      try {
        final locationService = Provider.of<LocationService>(context, listen: false);
        await _initializeLocationService(locationService);
        await _restartAudioSystem(locationService);
        
        if (mounted) {
          setState(() {});
          debugPrint('🔊 BirdHomePage state updated after audio initialization');
        }
      } catch (e) {
        debugPrint('❌ Error in BirdHomePage audio initialization: $e');
      }
    });
  }
  
  /// Initialize the location service if needed
  Future<void> _initializeLocationService(LocationService locationService) async {
    if (!locationService.isInitialized) {
      await locationService.initialize(context);
      debugPrint('🔊 LocationService initialized');
    }
    
    if (!locationService.isLocationTrackingEnabled) {
      await locationService.toggleLocationTracking(true);
      debugPrint('🔊 Location tracking enabled');
    }
  }
  
  /// Restart the audio system to ensure proper initialization
  Future<void> _restartAudioSystem(LocationService locationService) async {
    debugPrint('🔊 Restarting audio system to ensure proper initialization');
    await locationService.toggleAudio(false);
    await Future.delayed(const Duration(milliseconds: 300));
    await locationService.toggleAudio(true);
  }

  // ===== EVENT HANDLERS =====
  
  /// Handle microphone button press
  void _handleMicButtonPressed(BuildContext context, SpeechCoordinator coordinator) {
    if (coordinator.isListening) {
      coordinator.stopListening();
      return;
    }
    
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    coordinator.startListening();
    
    // Reset processing flag after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  // ===== UI BUILDERS =====
  
  @override
  Widget build(BuildContext context) {
    return Consumer<SpeechCoordinator>(
      builder: (context, coordinator, child) {
        final bool shouldShowFAB = _shouldShowFloatingButton(coordinator);
        
        return Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(context, coordinator),
          floatingActionButton: shouldShowFAB 
              ? _buildFloatingActionButton(context, coordinator) 
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  /// Build the app bar for the home page
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

  /// Build the main body of the home page
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

  /// Build the status bar showing listening state
  Widget _buildStatusBar(SpeechCoordinator coordinator) {
    final bool isListening = coordinator.isListening;
    
    return Container(
      color: isListening
          ? Colors.red.withAlpha((0.8 * 255).toInt())
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          Icon(
            isListening ? Icons.mic : Icons.mic_off,
            color: isListening ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isListening
                  ? 'Lytter efter tale...'
                  : 'Tryk på mikrofonen for at starte',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isListening ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the main content area with cards
  Widget _buildMainContent(SpeechCoordinator coordinator) {
    // Determine appropriate bottom padding based on FAB visibility
    final bool shouldShowFAB = _shouldShowFloatingButton(coordinator);
    final double bottomPadding = shouldShowFAB ? 150.0 : 20.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        children: [
          const SizedBox(height: 30),
          SpeechRecognitionCard(coordinator: coordinator),
          const SizedBox(height: 20),
          _buildStateSpecificCards(coordinator),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  /// Build cards based on the current recognition state
  Widget _buildStateSpecificCards(SpeechCoordinator coordinator) {
    if (coordinator.isWaitingForConfirmation) {
      return ConfirmationCard(
        birdName: coordinator.currentBirdInQuestion,
        onConfirm: () => coordinator.handleConfirmationResponse(true),
        onDeny: () => coordinator.handleConfirmationResponse(false),
      );
    }
    
    // Important: We now check only the isSystemInDoubt flag, not the possibleBirds list
    // This ensures the card is shown even if the list is empty initially
    if (coordinator.isSystemInDoubt) {
      // Use safe access with empty fallback list if possibleBirds is empty
      final List<String> birds = coordinator.possibleBirds.isNotEmpty 
          ? coordinator.possibleBirds 
          : ['Ingen fugle fundet']; // Fallback text
      
      return SystemInDoubtCard(
        possibleBirds: birds,
        onBirdSelected: coordinator.handleBirdSelection,
        onDismiss: () {
          coordinator.resetConfirmationState();
        },
      );
    }
    
    if (coordinator.isManualInputActive) {
      return ManualBirdInputCard(
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
      );
    }
    
    return const SizedBox.shrink(); // Empty widget if no special state
  }

  /// Build the floating action button for starting/stopping listening
  Widget _buildFloatingActionButton(BuildContext context, SpeechCoordinator coordinator) {
    final bool isListening = coordinator.isListening;
    
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
                backgroundColor: isListening ? Colors.red : AppStyles.primaryColor,
                elevation: 8,
                child: Icon(
                  isListening ? Icons.mic_off : Icons.mic,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Text(
            isListening ? 'Stop observation' : 'Start observation',
            style: AppStyles.buttonLabelStyle,
          ),
        ],
      ),
    );
  }

  /// Determine if the floating action button should be shown
  bool _shouldShowFloatingButton(SpeechCoordinator coordinator) {
    // Updated condition: only check the state, not the possibleBirds list
    return !coordinator.isSystemInDoubt && !coordinator.isManualInputActive;
  }
}

/// Card for displaying recognized speech and matched bird
class SpeechRecognitionCard extends StatelessWidget {
  final SpeechCoordinator coordinator;

  const SpeechRecognitionCard({super.key, required this.coordinator});

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
            onPressed: coordinator.clearRecognizedText,
            tooltip: 'Ryd tekst',
          ),
      ],
    );
  }

  Widget _buildRecognizedTextContent() {
    final String displayText = coordinator.recognizedText.isNotEmpty
        ? coordinator.recognizedText
        : 'Intet genkendt endnu';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        displayText,
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
            _buildTitle(),
            const SizedBox(height: 10),
            _buildSubtitle(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 12),
            _buildMicIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Er det en $birdName?',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.amber[800],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'Sig "ja" eller "nej", eller tryk på knapperne',
      style: TextStyle(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: Colors.amber[800],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
    );
  }

  Widget _buildMicIndicator() {
    return Row(
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
    );
  }
}

/// Card for when the system is in doubt between multiple birds
class SystemInDoubtCard extends StatelessWidget {
  final List<String> possibleBirds;
  final Function(String) onBirdSelected;
  final VoidCallback onDismiss;

  const SystemInDoubtCard({
    super.key,
    required this.possibleBirds,
    required this.onBirdSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
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
            ..._buildBirdOptions(),
            const SizedBox(height: 10),
            _buildDismissButton(coordinator),
          ],
        ),
      ),
    );
  }

  /// Build a list of bird option buttons
  List<Widget> _buildBirdOptions() {
    return possibleBirds.map((bird) => _buildBirdOption(bird)).toList();
  }

  /// Build a single bird option button
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

  /// Build the dismiss button
  Widget _buildDismissButton(SpeechCoordinator coordinator) {
    return Padding(
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
          onDismiss();
          coordinator.activateManualInput();
        },
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