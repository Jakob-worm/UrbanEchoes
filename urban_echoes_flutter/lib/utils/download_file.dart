import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
class DownloadFile {
  Future<String?> getXenoCantoDownloadUrl(String scientificName) async {
  try {
    final query = Uri.encodeComponent('$scientificName q:A');
    final apiUrl = 'https://xeno-canto.org/api/2/recordings?query=$query';
    print('Fetching from Xeno-Canto API: $apiUrl');
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['numRecordings'] != '0' && data['recordings'].isNotEmpty) {
        final recording = data['recordings'][0];
        // Remove any extra 'https:' prefix and ensure proper URL format
        String fileUrl = recording['file'].toString();
        if (fileUrl.startsWith('//')) {
          fileUrl = 'https:$fileUrl';
        } else if (fileUrl.startsWith('https:https://')) {
          fileUrl = fileUrl.replaceFirst('https:https://', 'https://');
        }

        print(
            'Found recording: ${recording['id']} - Quality: ${recording['q']}');
        print('Constructed download URL: $fileUrl');
        return fileUrl;
      } else {
        print('No recordings found for $scientificName');
        return null;
      }
    } else {
      print('API request failed: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error fetching from Xeno-Canto API: $e');
    return null;
  }
}

Future<File> downloadFileWithDio(String url, String fileName) async {
  try {
    print('Downloading file: $url');
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/$fileName';

    Dio dio = Dio();
    await dio.download(
      url,
      filePath,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.81 Safari/537.36',
        },
      ),
    );
    print('File saved to: $filePath');
    return File(filePath);
  } catch (e) {
    print('Download error: $e');
    throw Exception('Download failed');
  }
}

Future<File> downloadFile(String url, String fileName) async {
  try {
    print('Attempting to download file from URL: $url');
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll({
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/94.0.4606.81 Safari/537.36',
        'Accept': '*/*',
        'Referer': 'https://xeno-canto.org/'
      });

    final streamedResponse = await client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

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

// Helper function to play the sound
Future<void> playBirdSound(
    String scientificName, AudioPlayer audioPlayer) async {
  try {
    await audioPlayer.stop(); // Stop any currently playing sound
    final downloadUrl = await getXenoCantoDownloadUrl(scientificName);
    if (downloadUrl != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${scientificName}_$timestamp.mp3';
      final file = await downloadFileWithDio(downloadUrl, filename);
      if (await file.exists()) {
        await audioPlayer.play(DeviceFileSource(file.path));
        // Set up cleanup after playback
        audioPlayer.onPlayerComplete.listen((_) async {
          try {
            if (await file.exists()) {
              await file.delete();
              print('Cleaned up file: ${file.path}');
            }
          } catch (e) {
            print('Error cleaning up file: $e');
          }
        });
      }
    } else {
      print('No download URL found for $scientificName');
    }
  } catch (e) {
    print('Error in playBirdSound: $e');
  }
}
}
