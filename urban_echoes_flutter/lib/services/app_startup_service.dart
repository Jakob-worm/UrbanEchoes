import 'package:flutter/material.dart';
import 'package:urban_echoes/services/ebird_service.dart';

/// Service to handle tasks that need to run when the app starts
class AppStartupService {
  final EBirdService _eBirdService = EBirdService();
  bool _isSyncing = false;

  // Singleton pattern
  static final AppStartupService _instance = AppStartupService._internal();

  factory AppStartupService() {
    return _instance;
  }

  AppStartupService._internal();

  /// Run all startup tasks
  Future<void> runStartupTasks() async {
    debugPrint('Running app startup tasks...');

    // Sync eBird observations
    await syncEBirdObservations();

    // Add any other startup tasks here
  }

  /// Sync eBird observations from Denmark
  Future<void> syncEBirdObservations() async {
    // Prevent multiple syncs from running simultaneously
    if (_isSyncing) {
      debugPrint('eBird sync already in progress, skipping');
      return;
    }

    _isSyncing = true;

    try {
      debugPrint('Starting eBird observations sync for Denmark...');

      final count = await _eBirdService.syncNewObservationsOnStartup();

      if (count > 0) {
        debugPrint('Successfully imported $count new eBird observations');
      } else {
        debugPrint('No new eBird observations to import');
      }
    } catch (e) {
      debugPrint('Error syncing eBird observations: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
