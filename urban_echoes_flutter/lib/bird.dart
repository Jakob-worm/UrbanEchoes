class Bird {
  final String danishName;
  final String scientificName;
  final String observationDate;
  final String location;
  final String speciesCode;

  Bird({
    required this.danishName,
    required this.scientificName,
    required this.observationDate,
    required this.location,
    required this.speciesCode,
  });

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      danishName: json['danishName'] ?? "Unknown",
      scientificName: json['scientificName'] ?? "Unknown",
      observationDate: json['observationDate'] ?? "",
      location: json['location'] ?? "Unknown",
      speciesCode: json['speciesCode'] ?? "",
    );
  }
}
