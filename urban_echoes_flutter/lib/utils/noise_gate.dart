import 'dart:typed_data';

class NoiseGate {
  final double threshold;
  final double attackTime;
  final double releaseTime;
  final double sampleRate;

  NoiseGate({
    this.threshold = 0.1,
    this.attackTime = 0.01,
    this.releaseTime = 0.1,
    this.sampleRate = 44100.0,
  });

  // Simplified noise gate processing for byte data
  Uint8List processAudioBytes(Uint8List inputBytes) {
    // Convert byte data to Float32List
    Float32List samples = _convertBytesToFloat32(inputBytes);
    
    // Process samples
    Float32List processedSamples = _processSamples(samples);
    
    // Convert back to byte data
    return _convertFloat32ToBytes(processedSamples);
  }

  Float32List _processSamples(Float32List inputSamples) {
    Float32List outputSamples = Float32List.fromList(inputSamples);
    
    for (int i = 0; i < inputSamples.length; i++) {
      // Simple threshold-based noise reduction
      if (inputSamples[i].abs() < threshold) {
        outputSamples[i] = 0.0;
      }
    }
    
    return outputSamples;
  }

  // Utility methods for byte conversion
  Float32List _convertBytesToFloat32(Uint8List bytes) {
    // Assumes 16-bit PCM audio
    Float32List floats = Float32List(bytes.length ~/ 2);
    for (int i = 0; i < floats.length; i++) {
      // Convert 16-bit signed integer to float
      int sample = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;
      floats[i] = sample / 32768.0;
    }
    return floats;
  }

  Uint8List _convertFloat32ToBytes(Float32List floats) {
    Uint8List bytes = Uint8List(floats.length * 2);
    for (int i = 0; i < floats.length; i++) {
      // Convert float back to 16-bit PCM
      int sample = (floats[i] * 32767).toInt();
      bytes[i * 2] = sample & 0xFF;
      bytes[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    return bytes;
  }
}