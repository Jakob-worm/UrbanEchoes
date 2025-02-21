// Bird data model
class Bird {
  final String commonName;
  final String scientificName;

  Bird({required this.commonName, required this.scientificName});

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      commonName: json['common_name'] as String? ?? '',
      scientificName: json['scientificName'] as String? ?? '',
    );
  }

  Map<String, String> toMap() {
    return {
      'common_name': commonName,
      'scientificName': scientificName,
    };
  }
}
