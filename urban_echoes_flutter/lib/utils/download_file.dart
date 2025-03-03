import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
class DownloadFile {
  Future<String?> getXenoCantoDownloadUrl(String scientificName) async {
  try {
    final query = Uri.encodeComponent('$scientificName q:A');
    final apiUrl = 'https://xeno-canto.org/api/2/recordings?query=$query';
    debugPrint('Fetching from Xeno-Canto API: $apiUrl');
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

        debugPrint(
            'Found recording: ${recording['id']} - Quality: ${recording['q']}');
        debugPrint('Constructed download URL: $fileUrl');
        return fileUrl;
      } else {
        debugPrint('No recordings found for $scientificName');
        return null;
      }
    } else {
      debugPrint('API request failed: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('Error fetching from Xeno-Canto API: $e');
    return null;
  }
}

Future<File> downloadFileWithDio(String url, String fileName) async {
  try {
    debugPrint('Downloading file: $url');
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
    debugPrint('File saved to: $filePath');
    return File(filePath);
  } catch (e) {
    debugPrint('Download error: $e');
    throw Exception('Download failed');
  }
}

Future<File> downloadFile(String url, String fileName) async {
  try {
    debugPrint('Attempting to download file from URL: $url');
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

    debugPrint('Response status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      debugPrint('File downloaded to: ${file.path}');
      return file;
    } else {
      throw Exception('Failed to download file: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error downloading file: $e');
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
              debugPrint('Cleaned up file: ${file.path}');
            }
          } catch (e) {
            debugPrint('Error cleaning up file: $e');
          }
        });
      }
    } else {
      debugPrint('No download URL found for $scientificName');
    }
  } catch (e) {
    debugPrint('Error in playBirdSound: $e');
  }
}
}
