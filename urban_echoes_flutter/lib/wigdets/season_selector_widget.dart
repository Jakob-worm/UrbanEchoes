import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/models/season.dart';
import 'package:urban_echoes/services/season_service.dart';

class SeasonSelectorWidget extends StatelessWidget {
  // Callback that can be triggered when season changes (optional)
  final Function(Season)? onSeasonChanged;
  // Whether to show the "All Seasons" option
  final bool showAllOption;
  // Whether to use Danish names
  final bool useDanishNames;

  const SeasonSelectorWidget({
    Key? key,
    this.onSeasonChanged,
    this.showAllOption = true,
    this.useDanishNames = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SeasonService>(
      builder: (context, seasonService, child) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  useDanishNames ? 'Vælg årstid' : 'Select Season',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 8.0,
                  children: _buildSeasonChips(context, seasonService),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildSeasonChips(
      BuildContext context, SeasonService seasonService) {
    final List<Season> seasons = [
      Season.spring,
      Season.summer,
      Season.autumn,
      Season.winter,
    ];

    if (showAllOption) {
      seasons.add(Season.all);
    }

    return seasons.map((season) {
      final isSelected = seasonService.currentSeason == season;

      return FilterChip(
        selected: isSelected,
        label: Text(
          useDanishNames ? season.toDanishString() : season.toString(),
          style: TextStyle(
            color: isSelected ? Colors.white : null,
          ),
        ),
        onSelected: (selected) {
          if (selected) {
            seasonService.setCurrentSeason(season);
            if (onSeasonChanged != null) {
              onSeasonChanged!(season);
            }
          }
        },
        selectedColor: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).cardColor,
        checkmarkColor: Colors.white,
      );
    }).toList();
  }
}
