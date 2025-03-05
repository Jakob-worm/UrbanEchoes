import 'dart:math';
import 'package:flutter/material.dart';

class NoiseGate {
  // Parameters for noise gate
  final double threshold; // Amplitude threshold to trigger the gate
  final double attackTime; // How quickly the gate opens
  final double releaseTime; // How quickly the gate closes
  final double sampleRate; // Audio sample rate

  NoiseGate({
    this.threshold = 0.1, // Default threshold (adjust based on your audio)
    this.attackTime = 0.01, // 10ms attack time
    this.releaseTime = 0.1, // 100ms release time
    this.sampleRate = 44100.0, // Standard sample rate
  });

  // Apply noise gate to audio samples
  List<double> process(List<double> inputSamples) {
    List<double> outputSamples = List.from(inputSamples);
    
    // Calculate attack and release coefficients
    double attackCoeff = calculateCoefficient(attackTime);
    double releaseCoeff = calculateCoefficient(releaseTime);
    
    // State variables for envelope tracking
    double envelopeOut = 0.0;
    
    for (int i = 0; i < inputSamples.length; i++) {
      // Calculate absolute value (envelope) of the signal
      double envIn = inputSamples[i].abs();
      
      // Envelope detection with different attack and release rates
      if (envIn > envelopeOut) {
        // Attack phase
        envelopeOut += (envIn - envelopeOut) * attackCoeff;
      } else {
        // Release phase
        envelopeOut += (envIn - envelopeOut) * releaseCoeff;
      }
      
      // Apply noise gate
      if (envelopeOut < threshold) {
        // Below threshold: attenuate or mute
        outputSamples[i] = 0.0; // Mute
        // Alternative: soft attenuation
        // outputSamples[i] *= 0.1; // Reduce volume instead of complete mute
      }
    }
    
    return outputSamples;
  }

  // Calculate coefficient for envelope tracking
  double calculateCoefficient(double time) {
    // Convert time constant to coefficient
    return 1.0 - exp(-1.0 / (time * sampleRate));
  }
}

class NoiseGateDemo extends StatefulWidget {
  @override
  _NoiseGateDemoState createState() => _NoiseGateDemoState();
}

class _NoiseGateDemoState extends State<NoiseGateDemo> {
  // Noise gate parameters
  double _threshold = 0.1;
  double _attackTime = 0.01;
  double _releaseTime = 0.1;

  // Noise gate instance
  late NoiseGate _noiseGate;

  @override
  void initState() {
    super.initState();
    _noiseGate = NoiseGate(
      threshold: _threshold,
      attackTime: _attackTime,
      releaseTime: _releaseTime,
    );
  }

  // Method to apply noise gate to audio samples
  List<double> applyNoiseGate(List<double> audioSamples) {
    return _noiseGate.process(audioSamples);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Noise Gate Demo')),
      body: Column(
        children: [
          // Threshold Slider
          Slider(
            value: _threshold,
            min: 0.01,
            max: 1.0,
            label: 'Threshold: ${(_threshold * 100).toStringAsFixed(2)}%',
            onChanged: (value) {
              setState(() {
                _threshold = value;
                _noiseGate = NoiseGate(
                  threshold: _threshold,
                  attackTime: _attackTime,
                  releaseTime: _releaseTime,
                );
              });
            },
          ),
          // Attack Time Slider
          Slider(
            value: _attackTime,
            min: 0.001,
            max: 0.1,
            label: 'Attack Time: ${(_attackTime * 1000).toStringAsFixed(2)}ms',
            onChanged: (value) {
              setState(() {
                _attackTime = value;
                _noiseGate = NoiseGate(
                  threshold: _threshold,
                  attackTime: _attackTime,
                  releaseTime: _releaseTime,
                );
              });
            },
          ),
          // Release Time Slider
          Slider(
            value: _releaseTime,
            min: 0.01,
            max: 0.5,
            label: 'Release Time: ${(_releaseTime * 1000).toStringAsFixed(2)}ms',
            onChanged: (value) {
              setState(() {
                _releaseTime = value;
                _noiseGate = NoiseGate(
                  threshold: _threshold,
                  attackTime: _attackTime,
                  releaseTime: _releaseTime,
                );
              });
            },
          ),
        ],
      ),
    );
  }
}