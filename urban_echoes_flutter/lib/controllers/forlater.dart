// Helper function to upload a new sound file
Future<String?> _uploadSoundFile(
    AzureStorage storage, 
    String folderPath, 
    String baseUrl, 
    File soundFile) async {
  try {
    debugPrint('Uploading new sound file...');
    
    // Create a unique filename with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = soundFile.path.split('.').last.toLowerCase();
    final blobName = '$folderPath/${timestamp}.$extension';
    
    // Read the file as bytes
    final bytes = await soundFile.readAsBytes();
    
    // Upload the file to Azure
    final contentType = 'audio/$extension';
    final uploadResponse = await storage.putBlob(
      blobName,
      bodyBytes: bytes,
      contentType: contentType,
    );
    
    // Check response and return URL if successful
    if (uploadResponse.statusCode >= 200 && uploadResponse.statusCode < 300) {
      final blobUrl = "$baseUrl/$blobName";
      debugPrint('Successfully uploaded sound file: $blobUrl');
      return blobUrl;
    } else {
      debugPrint('Failed to upload sound file. Status: ${uploadResponse.statusCode}');
    }
  } catch (e) {
    debugPrint('Error uploading sound file: $e');
  }
  
  return null;
}