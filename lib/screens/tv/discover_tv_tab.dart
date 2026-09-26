import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/api_constants.dart';
import '../../models/dropdown_select.dart';
import '../../ui_components/app_ui_components.dart';
import 'discover_tv_result.dart';

class DiscoverTVTab extends StatefulWidget {
  const DiscoverTVTab({super.key});

  @override
  State<DiscoverTVTab> createState() => _DiscoverTVTabState();
}

class _DiscoverTVTabState extends State<DiscoverTVTab> {
  final YearDropdownData _years = YearDropdownData();
  int _sortIndex = 0;
  int _statusIndex = 0;
  String _firstAirYear = '';
  double _minimumRatings = 0;
  bool _useMinimumRatings = false;
  final Set<String> _genreIds = {};
  final Set<String> _providerIds = {};

  List<({String label, String value})> _sortOptions() => [
        (label: tr('popularity_descending'), value: 'popularity.desc'),
        (label: tr('popularity_ascending'), value: 'popularity.asc'),
        (label: tr('average_vote_descending'), value: 'vote_average.desc'),
        (label: tr('average_vote_ascending'), value: 'vote_average.asc'),
      ];

  List<({String label, String value})> _statusOptions() => [
        (label: tr('any'), value: ''),
        (label: tr('returning_series'), value: '0'),
        (label: tr('planned'), value: '1'),
        (label: tr('in_production'), value: '2'),
        (label: tr('ended'), value: '3'),
        (label: tr('cancelled'), value: '4'),
        (label: tr('pilot'), value: '5'),
      ];

  List<({String label, String value})> _genres() => [
        (label: tr('action_and_adventure'), value: '10759'),
        (label: tr('animation'), value: '16'),
        (label: tr('comedy'), value: '35'),
        (label: tr('crime'), value: '80'),
        (label: tr('documentary'), value: '99'),
        (label: tr('drama'), value: '18'),
        (label: tr('family'), value: '10751'),
        (label: tr('kids'), value: '10762'),
        (label: tr('mystery'), value: '9648'),
        (label: tr('news'), value: '10763'),
        (label: tr('reality'), value: '10764'),
        (label: tr('scifi_and_fantasy'), value: '10765'),
        (label: tr('soap'), value: '10766'),
        (label: tr('talk'), value: '10767'),
        (label: tr('war_and_politics'), value: '10768'),
        (label: tr('western'), value: '37'),
      ];

  static const _providers = [
    (label: 'Netflix', value: '8'),
    (label: 'Prime Video', value: '9'),
    (label: 'Disney+', value: '337'),
    (label: 'Hulu', value: '15'),
    (label: 'Max', value: '384'),
    (label: 'Apple TV+', value: '350'),
    (label: 'Peacock', value: '387'),
    (label: 'iTunes', value: '2'),
    (label: 'YouTube', value: '188'),
    (label: 'Paramount+', value: '531'),
    (label: 'Netflix Kids', value: '175'),
  ];

  @override
  Widget build(BuildContext context) {
    final sortOptions = _sortOptions();
    final statusOptions = _statusOptions();
    final genres = _genres();
    final activeFilters = _genreIds.length +
        _providerIds.length +
        (_statusIndex == 0 ? 0 : 1) +
        (_firstAirYear.isEmpty ? 0 : 1) +
        (_useMinimumRatings ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 120),
      child: AppResponsiveContent(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(PhosphorIcons.sliders(),
                      color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tr('sort_by')} & ${tr('discover')}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeFilters == 0
                            ? tr('any')
                            : '$activeFilters selected',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            AppFilterSection(
              title: tr('sort_by'),
              child: AppFilterRail(
                children: [
                  for (var i = 0; i < sortOptions.length; i++)
                    AppFilterPill(
                      label: sortOptions[i].label,
                      selected: _sortIndex == i,
                      onPressed: () => setState(() => _sortIndex = i),
                    ),
                ],
              ),
            ),
            AppFilterSection(
              title: tr('tv_series_status'),
              child: AppFilterRail(
                children: [
                  for (var i = 0; i < statusOptions.length; i++)
                    AppFilterPill(
                      label: statusOptions[i].label,
                      selected: _statusIndex == i,
                      onPressed: () => setState(() => _statusIndex = i),
                    ),
                ],
              ),
            ),
            AppFilterSection(
              title: tr('release_year'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(_firstAirYear),
                initialValue: _firstAirYear,
                isExpanded: true,
                decoration: InputDecoration(
                    prefixIcon: Icon(PhosphorIcons.calendar())),
                items: [
                  for (final year in _years.yearsList)
                    DropdownMenuItem(
                      value: year,
                      child: Text(year.isEmpty ? tr('any') : year),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _firstAirYear = value ?? ''),
              ),
            ),
            AppFilterSection(
              title: tr('total_ratings'),
              trailing: Switch.adaptive(
                value: _useMinimumRatings,
                onChanged: (value) =>
                    setState(() => _useMinimumRatings = value),
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.users(),
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr('ratings_count', namedArgs: {
                                'r': _minimumRatings.round().toString()
                              }),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _minimumRatings,
                        min: 0,
                        max: 30000,
                        divisions: 30,
                        onChanged: _useMinimumRatings
                            ? (value) => setState(() => _minimumRatings = value)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AppFilterSection(
              title: tr('with_genres'),
              child: AppFilterRail(
                children: [
                  for (final genre in genres)
                    AppFilterPill(
                      label: genre.label,
                      selected: _genreIds.contains(genre.value),
                      onPressed: () => _toggle(_genreIds, genre.value),
                    ),
                ],
              ),
            ),
            AppFilterSection(
              title: tr('with_streaming_services'),
              child: AppFilterRail(
                children: [
                  for (final provider in _providers)
                    AppFilterPill(
                      label: provider.label,
                      selected: _providerIds.contains(provider.value),
                      onPressed: () => _toggle(_providerIds, provider.value),
                    ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 18),
            AppFilterActions(
              resetLabel: tr('clear'),
              applyLabel: tr('apply'),
              onReset: _reset,
              onApply: () => _apply(
                sort: sortOptions[_sortIndex].value,
                status: statusOptions[_statusIndex].value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(Set<String> values, String value) {
    setState(() {
      values.contains(value) ? values.remove(value) : values.add(value);
    });
  }

  void _reset() {
    setState(() {
      _sortIndex = 0;
      _statusIndex = 0;
      _firstAirYear = '';
      _minimumRatings = 0;
      _useMinimumRatings = false;
      _genreIds.clear();
      _providerIds.clear();
    });
  }

  void _apply({required String sort, required String status}) {
    final api =
        '$TMDB_API_BASE_URL/discover/tv?api_key=$TMDB_API_KEY&sort_by=$sort&watch_region=US&with_status=$status&first_air_date_year=$_firstAirYear&vote_count.gte=${_useMinimumRatings ? _minimumRatings.round() : 0}&with_genres=${_genreIds.join(',')}&with_watch_providers=${_providerIds.join(',')}';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DiscoverTVResult(api: api, page: 1)),
    );
  }
}
