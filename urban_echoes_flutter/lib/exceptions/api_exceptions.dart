// Custom exception class
class BirdSearchException implements Exception {
  final String message;
  final int? statusCode;

  BirdSearchException(this.message, {this.statusCode});

  @override
  String toString() =>
      'BirdSearchException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}
