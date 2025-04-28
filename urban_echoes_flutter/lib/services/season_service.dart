import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_echoes/models/season.dart';

class SeasonService extends ChangeNotifier {
  static const String _selectedSeasonKey = 'selected_season';

  // Default to showing all seasons
  Season _currentSeason = Season.all;

  // Define months for each season in the Northern Hemisphere (Denmark)
  // These are 1-based (January = 1, December = 12)
  static const List<int> _springMonths = [3, 4, 5]; // March, April, May
  static const List<int> _summerMonths = [6, 7, 8]; // June, July, August
  static const List<int> _autumnMonths = [
    9,
    10,
    11
  ]; // September, October, November
  static const List<int> _winterMonths = [
    12,
    1,
    2
  ]; // December, January, February

  // Singleton pattern
  static final SeasonService _instance = SeasonService._internal();

  factory SeasonService() {
    return _instance;
  }

  SeasonService._internal() {
    _loadSelectedSeason();
  }

  /// Get the currently selected season
  Season get currentSeason => _currentSeason;

  /// Set a new season filter
  Future<void> setCurrentSeason(Season season) async {
    if (_currentSeason != season) {
      _currentSeason = season;
      await _saveSelectedSeason();
      notifyListeners();
    }
  }

  /// Determine the current season based on the current date
  Season getCurrentSeasonForDate([DateTime? date]) {
    final now = date ?? DateTime.now();
    final month = now.month;

    if (_springMonths.contains(month)) {
      return Season.spring;
    } else if (_summerMonths.contains(month)) {
      return Season.summer;
    } else if (_autumnMonths.contains(month)) {
      return Season.autumn;
    } else {
      return Season.winter;
    }
  }

  /// Check if a date is in the current selected season
  bool isDateInSelectedSeason(DateTime date) {
    // If all seasons are selected, return true
    if (_currentSeason == Season.all) {
      return true;
    }

    // Get the season for the given date
    final dateSeason = getCurrentSeasonForDate(date);

    // Check if the date's season matches the selected season
    return dateSeason == _currentSeason;
  }

  /// Get month numbers for a specific season
  List<int> getMonthsForSeason(Season season) {
    switch (season) {
      case Season.spring:
        return _springMonths;
      case Season.summer:
        return _summerMonths;
      case Season.autumn:
        return _autumnMonths;
      case Season.winter:
        return _winterMonths;
      case Season.all:
        return List.generate(12, (index) => index + 1); // All months
    }
  }

  // Load the previously selected season from SharedPreferences
  Future<void> _loadSelectedSeason() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSeasonIndex = prefs.getInt(_selectedSeasonKey);

      if (savedSeasonIndex != null) {
        _currentSeason = Season.values[savedSeasonIndex];
      } else {
        // If no saved season, default to current season based on date
        _currentSeason = getCurrentSeasonForDate();
      }
    } catch (e) {
      debugPrint('Error loading season preference: $e');
      // Default to current season if there's an error
      _currentSeason = getCurrentSeasonForDate();
    }
  }

  // Save the current season selection to SharedPreferences
  Future<void> _saveSelectedSeason() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedSeasonKey, _currentSeason.index);
    } catch (e) {
      debugPrint('Error saving season preference: $e');
    }
  }
}
