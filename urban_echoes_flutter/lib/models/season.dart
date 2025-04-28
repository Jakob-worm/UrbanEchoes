enum Season {
  spring,
  summer,
  autumn,
  winter,
  all;

  @override
  String toString() {
    switch (this) {
      case Season.spring:
        return 'Spring';
      case Season.summer:
        return 'Summer';
      case Season.autumn:
        return 'Autumn';
      case Season.winter:
        return 'Winter';
      case Season.all:
        return 'All Seasons';
    }
  }

  /// Returns a localized Danish name for the season
  String toDanishString() {
    switch (this) {
      case Season.spring:
        return 'Forår';
      case Season.summer:
        return 'Sommer';
      case Season.autumn:
        return 'Efterår';
      case Season.winter:
        return 'Vinter';
      case Season.all:
        return 'Alle årstider';
    }
  }
}
