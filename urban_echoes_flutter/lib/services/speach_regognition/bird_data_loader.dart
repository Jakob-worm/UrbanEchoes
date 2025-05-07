import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BirdDataLoader {
  factory BirdDataLoader() => _instance;

  BirdDataLoader._internal();

  // Singleton pattern
  static final BirdDataLoader _instance = BirdDataLoader._internal();

  // Bird data
  List<String> _danishBirdNames = [];

  bool _isLoaded = false;

  // Getters
  List<String> get danishBirdNames => _danishBirdNames;

  bool get isLoaded => _isLoaded;

  // Load the bird names from assets
  Future<List<String>> loadBirdNames() async {
    if (_isLoaded) return _danishBirdNames;
    
    try {
      // Try to load from assets first (production approach)
      try {
        String data = await rootBundle.loadString('assets/all_danish_bird_names.txt');
        _loadFromString(data);
      } catch (e) {
        debugPrint('Could not load bird names from assets: $e');
        // Fall back to hardcoded list from paste.txt
        _loadHardcodedBirdNames();
      }
      
      _isLoaded = true;
      return _danishBirdNames;
    } catch (e) {
      debugPrint('Error loading bird names: $e');
      return [];
    }
  }

  // Search for birds by partial name
  List<String> searchBirds(String query) {
    if (!_isLoaded) {
      debugPrint('Warning: Attempting to search before birds are loaded');
      return [];
    }
    
    if (query.isEmpty) {
      return _danishBirdNames;
    }
    
    final lowercaseQuery = query.toLowerCase();
    return _danishBirdNames
        .where((name) => name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  // Get a random bird name
  String getRandomBirdName() {
    if (!_isLoaded || _danishBirdNames.isEmpty) {
      debugPrint('Warning: Attempting to get random bird before birds are loaded');
      return '';
    }
    
    final random = DateTime.now().millisecondsSinceEpoch % _danishBirdNames.length;
    return _danishBirdNames[random];
  }

  // Get birds sorted alphabetically
  List<String> getSortedBirdNames() {
    if (!_isLoaded) {
      debugPrint('Warning: Attempting to sort before birds are loaded');
      return [];
    }
    
    final sortedList = List<String>.from(_danishBirdNames);
    sortedList.sort();
    return sortedList;
  }

  // Clear the loaded data (useful for testing)
  void clearData() {
    _danishBirdNames = [];
    _isLoaded = false;
    debugPrint('Bird data cleared');
  }

  // Export the bird names to a string format
  String exportBirdNamesToString() {
    return _danishBirdNames.join('\n');
  }

  // Get statistics about the bird names
  Map<String, dynamic> getBirdNameStatistics() {
    if (!_isLoaded) {
      debugPrint('Warning: Attempting to get statistics before birds are loaded');
      return {};
    }
    
    // Get the first letter distribution
    final Map<String, int> firstLetterCount = {};
    for (final name in _danishBirdNames) {
      if (name.isNotEmpty) {
        final firstLetter = name[0].toUpperCase();
        firstLetterCount[firstLetter] = (firstLetterCount[firstLetter] ?? 0) + 1;
      }
    }
    
    // Get the length statistics
    final lengths = _danishBirdNames.map((name) => name.length).toList();
    lengths.sort();
    
    final int totalBirds = _danishBirdNames.length;
    final double averageLength = totalBirds > 0 
        ? lengths.reduce((a, b) => a + b) / totalBirds 
        : 0;
    
    final int shortestLength = lengths.isNotEmpty ? lengths.first : 0;
    final int longestLength = lengths.isNotEmpty ? lengths.last : 0;
    
    // Find shortest and longest bird names
    String shortestBird = '';
    String longestBird = '';
    
    for (final name in _danishBirdNames) {
      if (name.length == shortestLength && (shortestBird.isEmpty || name.compareTo(shortestBird) < 0)) {
        shortestBird = name;
      }
      if (name.length == longestLength && (longestBird.isEmpty || name.compareTo(longestBird) < 0)) {
        longestBird = name;
      }
    }
    
    return {
      'totalBirds': totalBirds,
      'averageNameLength': averageLength,
      'shortestName': shortestBird,
      'shortestLength': shortestLength,
      'longestName': longestBird,
      'longestLength': longestLength,
      'firstLetterDistribution': firstLetterCount,
    };
  }

  // Parse bird names from a string
  void _loadFromString(String data) {
    _danishBirdNames = data
        .split('\n')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    
    debugPrint('Loaded ${_danishBirdNames.length} Danish bird names');
  }

  // Fallback method - load from hardcoded list
  void _loadHardcodedBirdNames() {
    _danishBirdNames = [
      'Aftenfalk', 'Agerhøne', 'Alexanderparakit', 'Alk', 'Allike',
      'Almindelig Kjove', 'Almindelig Ryle', 'Almindelig Skråpe',
      'Amerikansk Krikand', 'Amerikansk Skarveand', 'Amerikansk Sortand',
      'Atlingand', 'Biæder', 'Bjergand', 'Bjergirisk', 'Bjerglærke',
      'Bjergpiber', 'Bjergvipstjert', 'Blisgås', 'Blishøne', 'Blå Kærhøg',
      'Blåhals', 'Blåmejse', 'Bogfinke', 'Bomlærke', 'Bramgås', 'Brilleand',
      'Broget Fluesnapper', 'Brun Løvsanger', 'Brushane', 'Buskrørsanger',
      'Bynkefugl', 'Bysvale', 'Canadagås', 'Citronvipstjert', 'Damklire',
      'Digesvale', 'Dobbeltbekkasin', 'Dompap', 'Drosselrørsanger', 'Duehøg',
      'Dværgfalk', 'Dværggås', 'Dværgmåge', 'Dværgryle', 'Dværgterne',
      'Dværgværling', 'Ederfugl', 'Ellekrage', 'Engpiber', 'Engsnarre',
      'Enkeltbekkasin', 'Fasan', 'Fiskehejre', 'Fiskeørn', 'Fjeldvåge',
      'Fjordterne', 'Flodsanger', 'Fløjlsand', 'Fuglekonge', 'Fuglekongesanger',
      'Fyrremejse', 'Gransanger', 'Gravand', 'Græshoppesanger', 'Grønirisk',
      'Grønsisken', 'Grønspætte', 'Grå Fluesnapper', 'Gråand', 'Grågås',
      'Gråkrage', 'Gråmåge', 'Gråspurv', 'Gråstrubet Lappedykker', 'Gul Vipstjert',
      'Gulbug', 'Gulirisk', 'Gulspurv', 'Gærdesanger', 'Gærdesmutte', 'Gøg',
      'Halemejse', 'Havesanger', 'Havlit', 'Havterne', 'Havørn', 'Hedehøg',
      'Hedelærke', 'Hjejle', 'Hortulan', 'Huldue', 'Husrødstjert', 'Husskade',
      'Hvepsevåge', 'Hvid Stork', 'Hvid Vipstjert', 'Hvidbrynet Løvsanger',
      'Hvidbrystet Præstekrave', 'Hvidhalset Fluesnapper', 'Hvidklire',
      'Hvidnæbbet Lom', 'Hvidsisken', 'Hvidvinget Korsnæb', 'Hvidvinget Måge',
      'Hvidvinget Terne', 'Hvidøjet And', 'Hvinand', 'Hærfugl', 'Hættemåge',
      'Høgesanger', 'Høgeugle', 'Indisk Gås', 'Isfugl', 'Islandsk Ryle', 'Islom',
      'Jagtfalk', 'Jernspurv', 'Karmindompap', 'Kaspisk Måge', 'Kernebider',
      'Kirkeugle', 'Klippedue', 'Klyde', 'Knarand', 'Knopsvane', 'Knortegås',
      'Kohejre', 'Kongeederfugl', 'Kongeørn', 'Kortnæbbet Gås', 'Korttået Træløber',
      'Krikand', 'Krognæb', 'Krumnæbbet Ryle', 'Kvækerfinke', 'Kærløber',
      'Kærsanger', 'Landsvale', 'Lapværling', 'Lille Flagspætte', 'Lille Fluesnapper',
      'Lille Gråsisken', 'Lille Kjove', 'Lille Kobbersneppe', 'Lille Korsnæb',
      'Lille Lappedykker', 'Lille Præstekrave', 'Lille Skallesluger', 'Lille Skrigeørn',
      'Lille Stormsvale', 'Lomvie', 'Lunde', 'Lundsanger', 'Lærkefalk', 'Løvsanger',
      'Mallemuk', 'Mandarinand', 'Markpiber', 'Mellemflagspætte', 'Mellemkjove',
      'Middelhavssølvmåge', 'Misteldrossel', 'Mosehornugle', 'Mudderklire', 'Munk',
      'Mursejler', 'Musvit', 'Musvåge', 'Nathejre', 'Natravn', 'Nattergal', 'Natugle',
      'Nilgås', 'Nordisk Lappedykker', 'Nordlig Gråsisken', 'Nøddekrige', 'Odinshane',
      'Perleugle', 'Pibeand', 'Pibesvane', 'Pirol', 'Plettet Rørvagtel', 'Pomeransfugl',
      'Pungmejse', 'Ravn', 'Ride', 'Ringdrossel', 'Ringdue', 'Rosenbrystet Tornskade',
      'Rosenstær', 'Rovterne', 'Rustand', 'Rød Glente', 'Rødben', 'Rødhals',
      'Rødhalset Gås', 'Rødhovedet And', 'Rødhovedet Tornskade', 'Rødhøne',
      'Rødrygget Svale', 'Rødrygget Tornskade', 'Rødstjert', 'Rødstrubet Lom',
      'Rødstrubet Piber', 'Rødtoppet Fuglekonge', 'Rørdrum', 'Rørhøg',
      'Rørhøne', 'Rørsanger', 'Rørspurv', 'Råge', 'Sabinemåge', 'Sandløber',
      'Sandterne', 'Sangdrossel', 'Sanglærke', 'Sangsvane', 'Savisanger',
      'Sildemåge', 'Silkehale', 'Silkehejre', 'Sivsanger', 'Sjagger', 'Skarv',
      'Skeand', 'Skestork', 'Skovhornugle', 'Skovpiber', 'Skovsanger', 'Skovskade',
      'Skovsneppe', 'Skovspurv', 'Skægmejse', 'Skærpiber', 'Slangeørn', 'Slørugle',
      'Småspove', 'Snegås', 'Snespurv', 'Sneugle', 'Sodfarvet Skråpe', 'Solsort',
      'Sort Glente', 'Sort Ibis', 'Sort Stork', 'Sortand', 'Sortgrå Ryle',
      'Sorthalset Lappedykker', 'Sorthovedet Måge', 'Sortklire', 'Sortkrage',
      'Sortmejse', 'Sortspætte', 'Sortstrubet Bynkefugl', 'Sortstrubet Lom',
      'Sortsvane', 'Sortterne', 'Spidsand', 'Splitterne', 'Spurvehøg', 'Spurveugle',
      'Spætmejse', 'Stellersand', 'Stenpikker', 'Stenvender', 'Steppehøg', 'Stillits',
      'Stor Flagspætte', 'Stor Hornugle', 'Stor Kobbersneppe', 'Stor Korsnæb',
      'Stor Præstekrave', 'Stor Skallesluger', 'Stor Skrigeørn', 'Stor Stormsvale',
      'Stor Tornskade', 'Storkjove', 'Stormmåge', 'Storpiber', 'Storspove',
      'Strandhjejle', 'Strandskade', 'Stribet Ryle', 'Stylteløber', 'Stær',
      'Sule', 'Sumpmejse', 'Svaleklire', 'Svartbag', 'Sydlig Nattergal', 'Søkonge',
      'Sølvhejre', 'Sølvmåge', 'Taffeland', 'Tajgasædgås', 'Tejst', 'Temmincksryle',
      'Terekklire', 'Thorshane', 'Tinksmed', 'Toplærke', 'Topmejse',
      'Toppet Lappedykker', 'Toppet Skallesluger', 'Topskarv', 'Tornirisk',
      'Tornsanger', 'Trane', 'Tredækker', 'Triel', 'Troldand', 'Træløber',
      'Tundrasædgås', 'Turteldue', 'Tyrkerdue', 'Tårnfalk', 'Urfugl', 'Vagtel',
      'Vandrefalk', 'Vandrikse', 'Vandsanger', 'Vandstær', 'Vendehals', 'Vibe',
      'Vindrossel', 'Urfugl', 'Vagtel', 'Sortsvane', 'Pibesvane', 'Sangsvane', 'Nilgås', 'Rustand',
      'Mandarinand', 'Sibirisk Krikand', 'Blåvinget And', 'Skeand', 'Pibeand',
      'Amerikansk Pibeand', 'Sortbrun And', 'Spidsand', 'Krikand',
      'Rødhovedet And', 'Taffeland', 'Halsbåndstroldand', 'Troldand',
      'Lille Bjergand', 'Stellersand', 'Amerikansk Fløjlsand',
      'Sibirisk Fløjlsand', 'Sortand', 'Amerikansk Sortand', 'Lille Skallesluger',
      'Stor Skallesluger', 'Toppet Skallesluger', 'Amerikansk Skarveand',
      'Hvidhovedet And', 'Natravn', 'Ørkennatravn', 'Tornhalesejler',
      'Alpesejler', 'Mursejler', 'Gråsejler', 'Orientsejler', 'Lille Sejler',
      'Kaffersejler', 'Stortrappe', 'Østlig Kravetrappe', 'Dværgtrappe',
    ];
    
    debugPrint('Loaded ${_danishBirdNames.length} Danish bird names from hardcoded list');
  }
}