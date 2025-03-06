import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  // Cross-platform audio byte processing
  Uint8List processAudioBytes(Uint8List inputBytes) {
    try {
      // Detect input audio format
      AudioFormat format = _detectAudioFormat(inputBytes);

      // Convert bytes to float samples based on format
      Float32List samples = _convertBytesToFloat32(inputBytes, format);

      // Process samples with noise gate
      Float32List processedSamples = _processSamples(samples);

      // Convert back to original format
      return _convertFloat32ToBytes(processedSamples, format);
    } catch (e) {
      debugPrint('Noise gate processing error: $e');
      return inputBytes; // Return original if processing fails
    }
  }

  // Enhanced sample processing with soft knee and envelope detection
  Float32List _processSamples(Float32List inputSamples) {
    Float32List outputSamples = Float32List.fromList(inputSamples);
    double envelopeFollower = 0.0;

    for (int i = 0; i < inputSamples.length; i++) {
      double absSample = inputSamples[i].abs();

      // Soft knee noise gate
      if (absSample < threshold) {
        // Soft fade out below threshold
        double attenuation = _softKnee(absSample);
        outputSamples[i] *= attenuation;
      }
    }

    return outputSamples;
  }

  // Soft knee reduction for smoother noise gating
  double _softKnee(double sample) {
    // Smooth transition around threshold
    if (sample < threshold * 0.5) {
      return 0.0; // Complete silence for very low levels
    }

    // Gradual reduction near threshold
    return (sample - threshold) / (1.0 - threshold);
  }

  // Detect audio format
  AudioFormat _detectAudioFormat(Uint8List bytes) {
    // Simple detection based on byte length and common formats
    if (bytes.length % 2 == 0) {
      return AudioFormat.pcm16Bit;
    } else if (bytes.length % 4 == 0) {
      return AudioFormat.pcm32Bit;
    } else if (bytes.length % 3 == 0) {
      return AudioFormat.pcm24Bit;
    }

    // Default fallback
    return AudioFormat.pcm16Bit;
  }

  // Flexible bytes to float conversion
  Float32List _convertBytesToFloat32(Uint8List bytes, AudioFormat format) {
    switch (format) {
      case AudioFormat.pcm16Bit:
        return _convertPcm16ToFloat32(bytes);
      case AudioFormat.pcm24Bit:
        return _convertPcm24ToFloat32(bytes);
      case AudioFormat.pcm32Bit:
        return _convertPcm32ToFloat32(bytes);
      default:
        return _convertPcm16ToFloat32(bytes);
    }
  }

  // 16-bit PCM to float conversion
  Float32List _convertPcm16ToFloat32(Uint8List bytes) {
    Float32List floats = Float32List(bytes.length ~/ 2);
    for (int i = 0; i < floats.length; i++) {
      int sample = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;
      floats[i] = sample / 32768.0;
    }
    return floats;
  }

  // 24-bit PCM to float conversion (less common, but more precise)
  Float32List _convertPcm24ToFloat32(Uint8List bytes) {
    Float32List floats = Float32List(bytes.length ~/ 3);
    for (int i = 0; i < floats.length; i++) {
      int sample =
          bytes[i * 3] | (bytes[i * 3 + 1] << 8) | (bytes[i * 3 + 2] << 16);
      if (sample > 8388607) sample -= 16777216;
      floats[i] = sample / 8388608.0;
    }
    return floats;
  }

  // 32-bit PCM to float conversion
  Float32List _convertPcm32ToFloat32(Uint8List bytes) {
    Float32List floats = Float32List(bytes.length ~/ 4);
    ByteData byteData = ByteData.sublistView(bytes);

    for (int i = 0; i < floats.length; i++) {
      int sample = byteData.getInt32(i * 4, Endian.little);
      floats[i] = sample / 2147483648.0;
    }
    return floats;
  }

  // Flexible float to bytes conversion
  Uint8List _convertFloat32ToBytes(Float32List floats, AudioFormat format) {
    switch (format) {
      case AudioFormat.pcm16Bit:
        return _convertFloat32ToPcm16(floats);
      case AudioFormat.pcm24Bit:
        return _convertFloat32ToPcm24(floats);
      case AudioFormat.pcm32Bit:
        return _convertFloat32ToPcm32(floats);
      default:
        return _convertFloat32ToPcm16(floats);
    }
  }

  // Float to 16-bit PCM conversion
  Uint8List _convertFloat32ToPcm16(Float32List floats) {
    Uint8List bytes = Uint8List(floats.length * 2);
    for (int i = 0; i < floats.length; i++) {
      int sample = (floats[i] * 32767).toInt();
      bytes[i * 2] = sample & 0xFF;
      bytes[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    return bytes;
  }

  // Float to 24-bit PCM conversion
  Uint8List _convertFloat32ToPcm24(Float32List floats) {
    Uint8List bytes = Uint8List(floats.length * 3);
    for (int i = 0; i < floats.length; i++) {
      int sample = (floats[i] * 8388607).toInt();
      bytes[i * 3] = sample & 0xFF;
      bytes[i * 3 + 1] = (sample >> 8) & 0xFF;
      bytes[i * 3 + 2] = (sample >> 16) & 0xFF;
    }
    return bytes;
  }

  // Float to 32-bit PCM conversion
  Uint8List _convertFloat32ToPcm32(Float32List floats) {
    Uint8List bytes = Uint8List(floats.length * 4);
    ByteData byteData = ByteData.sublistView(bytes);

    for (int i = 0; i < floats.length; i++) {
      int sample = (floats[i] * 2147483647).toInt();
      byteData.setInt32(i * 4, sample, Endian.little);
    }
    return bytes;
  }
}

// Supported audio format enumeration
enum AudioFormat {
  pcm16Bit,
  pcm24Bit,
  pcm32Bit,
}
