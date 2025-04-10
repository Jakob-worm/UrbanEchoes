import 'package:azblob/azblob.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

main() async {
  final connectionString = dotenv.env['AZURE_STORAGE_CONNECTION_STRING'] ?? '';

  var storage = AzureStorage.parse(connectionString);

  storage.getBlob('bird-sounds');
}
