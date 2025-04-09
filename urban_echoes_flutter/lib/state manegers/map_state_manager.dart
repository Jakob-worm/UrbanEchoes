import 'package:flutter/material.dart';

// Define all possible map states
enum MapState {
  initializing,  // Starting state when the page is first loaded
  loadingData,   // Loading observations and other data
  waitingForLocation, // Waiting for location permission or first fix
  ready,         // Map is fully loaded and ready
  error,         // An error occurred
}

class MapStateManager extends ChangeNotifier {
  // Current state
  MapState _state = MapState.initializing;
  MapState get state => _state;
  
  // Error information
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // Additional state information
  bool _isLocationLoaded = false;
  bool _isDataLoaded = false;
  bool _isMapReady = false;
  
  // Status getters
  bool get isMapFullyLoaded => _state == MapState.ready;
  bool get isLoading => _state == MapState.initializing || 
                        _state == MapState.loadingData || 
                        _state == MapState.waitingForLocation;
  bool get hasError => _state == MapState.error;
  
  // Initialize the state manager
  void initialize() {
    _state = MapState.initializing;
    notifyListeners();
  }
  
  // Transition to loadingData state
  void startLoadingData() {
    if (_state == MapState.initializing) {
      _state = MapState.loadingData;
      notifyListeners();
    }
  }
  
  // Handle location state
  void setLocationLoaded(bool loaded) {
    _isLocationLoaded = loaded;
    _checkIfReady();
  }
  
  // Handle data loading state
  void setDataLoaded(bool loaded) {
    _isDataLoaded = loaded;
    _checkIfReady();
  }
  
  // Handle map ready state
  void setMapReady(bool ready) {
    _isMapReady = ready;
    _checkIfReady();
  }
  
  // Transition to waitingForLocation state
  void waitForLocation() {
    if (_state != MapState.error) {
      _state = MapState.waitingForLocation;
      notifyListeners();
    }
  }
  
  // Set error state with message
  void setError(String message) {
    _errorMessage = message;
    _state = MapState.error;
    notifyListeners();
  }
  
  // Force the map to ready state even if conditions aren't met
  void forceReady() {
    _state = MapState.ready;
    notifyListeners();
  }
  
  // Check if all conditions are met to transition to ready state
  void _checkIfReady() {
    if (_isLocationLoaded && _isDataLoaded && _isMapReady && 
        (_state == MapState.loadingData || _state == MapState.waitingForLocation)) {
      _state = MapState.ready;
      notifyListeners();
    }
  }
  
  // Reset error and try again
  void retry() {
    _errorMessage = null;
    _state = MapState.initializing;
    notifyListeners();
    
    // Start the loading process again
    initialize();
  }
}