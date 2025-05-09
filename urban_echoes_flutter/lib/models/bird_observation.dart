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

  // Create a copy of this BirdObservation with the given fields replaced
  BirdObservation copyWith({
    int? id,
    String? birdName,
    String? scientificName,
    String? soundDirectory,
    double? latitude,
    double? longitude,
    DateTime? observationDate,
    String? observationTime,
    int? observerId,
    int? quantity,
    bool? isTestData,
    int? testBatchId,
    String? sourceId,
  }) {
    return BirdObservation(
      id: id ?? this.id,
      birdName: birdName ?? this.birdName,
      scientificName: scientificName ?? this.scientificName,
      soundDirectory: soundDirectory ?? this.soundDirectory,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      observationDate: observationDate ?? this.observationDate,
      observationTime: observationTime ?? this.observationTime,
      observerId: observerId ?? this.observerId,
      quantity: quantity ?? this.quantity,
      isTestData: isTestData ?? this.isTestData,
      testBatchId: testBatchId ?? this.testBatchId,
      sourceId: sourceId ?? this.sourceId,
    );
  }

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
  
  @override
  String toString() {
    return 'BirdObservation(id: $id, birdName: $birdName, location: $latitude, $longitude, date: $observationDate)';
  }
}