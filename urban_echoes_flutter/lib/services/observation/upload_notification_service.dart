// lib/services/upload_notification_service.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/models/bird_observation.dart';

class UploadNotificationService extends ChangeNotifier {
  bool _isShowing = false;
  BirdObservation? _lastUploadedObservation;
  String? _errorMessage;
  
  // Getters
  bool get isShowing => _isShowing;
  BirdObservation? get lastUploadedObservation => _lastUploadedObservation;
  String? get errorMessage => _errorMessage;
  
  // Show success notification
  void showSuccessNotification(BirdObservation observation) {
    _lastUploadedObservation = observation;
    _errorMessage = null;
    _isShowing = true;
    notifyListeners();
    
    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_isShowing) {
        hideNotification();
      }
    });
  }
  
  // Show error notification
  void showErrorNotification(String message) {
    _errorMessage = message;
    _isShowing = true;
    notifyListeners();
    
    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_isShowing) {
        hideNotification();
      }
    });
  }
  
  // Hide notification
  void hideNotification() {
    _isShowing = false;
    notifyListeners();
  }
}

// Widget to display the notification
class UploadNotificationWidget extends StatelessWidget {
  const UploadNotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadNotificationService>(
      builder: (context, notificationService, child) {
        if (!notificationService.isShowing) {
          return const SizedBox.shrink();
        }
        
        // Error notification
        if (notificationService.errorMessage != null) {
          return _buildErrorNotification(context, notificationService);
        }
        
        // Success notification
        if (notificationService.lastUploadedObservation != null) {
          return _buildSuccessNotification(context, notificationService);
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  Widget _buildSuccessNotification(BuildContext context, UploadNotificationService service) {
    final observation = service.lastUploadedObservation!;
    
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.green[100],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green[700]!, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Observation Uploaded',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => service.hideNotification(),
                    color: Colors.grey[700],
                    iconSize: 20,
                  ),
                ],
              ),
              const Divider(),
              _detailRow('Bird', observation.birdName),
              if (observation.scientificName.isNotEmpty) 
                _detailRow('Scientific Name', observation.scientificName),
              _detailRow('Date', 
                '${observation.observationDate.day}/${observation.observationDate.month}/${observation.observationDate.year}'),
              _detailRow('Time', observation.observationTime),
              _detailRow('Location', 
                '${observation.latitude.toStringAsFixed(6)}, ${observation.longitude.toStringAsFixed(6)}'),
              _detailRow('Quantity', observation.quantity.toString()),
              if (observation.sourceId != null)
                _detailRow('Source ID', observation.sourceId!),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorNotification(BuildContext context, UploadNotificationService service) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.red[100],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red[700]!, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Upload Failed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => service.hideNotification(),
                    color: Colors.grey[700],
                    iconSize: 20,
                  ),
                ],
              ),
              const Divider(),
              Text(
                service.errorMessage ?? 'Unknown error',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red[900],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}