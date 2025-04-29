class BirdObservation {
  final int? id; // Database ID (null for new observations)
  final String birdName;
  final String scientificName;
  final String soundDirectory;
  final double latitude;
  final double longitude;
  final DateTime observationDate;
  final String observationTime;
  final int observerId;
  final int quantity;
  final bool isTestData;
  final int testBatchId;
  final String? sourceId; // New field to store eBird's subId

  BirdObservation({
    this.id,
    required this.birdName,
    required this.scientificName,
    required this.soundDirectory,
    required this.latitude,
    required this.longitude,
    required this.observationDate,
    required this.observationTime,
    required this.observerId,
    required this.quantity,
    required this.isTestData,
    required this.testBatchId,
    this.sourceId, // Optional for compatibility with existing code
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bird_name': birdName,
      'scientific_name': scientificName,
      'sound_directory': soundDirectory,
      'latitude': latitude,
      'longitude': longitude,
      'observation_date': observationDate.toIso8601String(),
      'observation_time': observationTime,
      'observer_id': observerId,
      'quantity': quantity,
      'is_test_data': isTestData,
      'test_batch_id': testBatchId,
      'source_id': sourceId,
    };
  }

  factory BirdObservation.fromMap(Map<String, dynamic> map) {
    return BirdObservation(
      id: map['id'],
      birdName: map['bird_name'],
      scientificName: map['scientific_name'],
      soundDirectory: map['sound_directory'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      observationDate: DateTime.parse(map['observation_date']),
      observationTime: map['observation_time'],
      observerId: map['observer_id'],
      quantity: map['quantity'],
      isTestData: map['is_test_data'],
      testBatchId: map['test_batch_id'],
      sourceId: map['source_id'],
    );
  }
}