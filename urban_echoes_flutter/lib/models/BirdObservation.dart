import 'package:flutter/material.dart';

class BirdObservation {
  final int? id; // null for new records
  final String birdName;
  final String scientificName;
  final String? soundUrl;
  final double latitude;
  final double longitude;
  final DateTime observationDate;
  final String observationTime; // Using String to handle the TIME data type
  final int? observerId;
  final int quantity;

  BirdObservation({
    this.id,
    required this.birdName,
    required this.scientificName,
    this.soundUrl,
    required this.latitude,
    required this.longitude,
    required this.observationDate,
    required this.observationTime,
    this.observerId,
    required this.quantity,
  });

  // Create a copy of this observation with optional changes
  BirdObservation copyWith({
    int? id,
    String? birdName,
    String? scientificName,
    String? soundUrl,
    double? latitude,
    double? longitude,
    DateTime? observationDate,
    String? observationTime,
    int? observerId,
    int? quantity,
  }) {
    return BirdObservation(
      id: id ?? this.id,
      birdName: birdName ?? this.birdName,
      scientificName: scientificName ?? this.scientificName,
      soundUrl: soundUrl ?? this.soundUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      observationDate: observationDate ?? this.observationDate,
      observationTime: observationTime ?? this.observationTime,
      observerId: observerId ?? this.observerId,
      quantity: quantity ?? this.quantity,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'birdName': birdName,
      'scientificName': scientificName,
      'soundUrl': soundUrl,
      'latitude': latitude,
      'longitude': longitude,
      'observationDate': observationDate.toIso8601String(),
      'observationTime': observationTime,
      'observerId': observerId,
      'quantity': quantity,
    };
  }

  // Create from JSON
  factory BirdObservation.fromJson(Map<String, dynamic> json) {
    return BirdObservation(
      id: json['id'],
      birdName: json['birdName'],
      scientificName: json['scientificName'],
      soundUrl: json['soundUrl'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      observationDate: DateTime.parse(json['observationDate']),
      observationTime: json['observationTime'],
      observerId: json['observerId'],
      quantity: json['quantity'],
    );
  }
}
