import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<File> downloadFile(String url, String fileName) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      print('File downloaded to: ${file.path}');
      return file;
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error downloading file: $e');
  }
}
