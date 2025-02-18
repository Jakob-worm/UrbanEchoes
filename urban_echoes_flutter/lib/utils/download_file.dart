import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<File> downloadFile(String url, String fileName) async {
  try {
    print('Attempting to download file from URL: $url');
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
        'Referer': 'https://www.xeno-canto.org/', // Set referer to Xeno-Canto
        'Accept': '*/*',
      },
    );
    print('Response status code: ${response.statusCode}');
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
    print('Error downloading file: $e');
    throw Exception('Error downloading file: $e');
  }
}
