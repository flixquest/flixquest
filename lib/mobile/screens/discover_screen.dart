import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/discover_query.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../widgets/common_widgets.dart' show appStreamingServices;
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import 'collection_screen.dart';

/// Counts what a discover request would find; null when it can't tell.
typedef DiscoverCounter = Future<int?> Function(String url);

/// Browse with filters: FlixQuest's Discover for movies or series, laid out
/// as choices to tap rather than form controls, with a button that says how
/// many titles the choices find.
///
/// Each kind keeps its own choices, so switching between them and back
/// loses nothing; so does coming back from the results.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({this.openResults, this.countResults, super.key});

  /// Shows the results; the paged grid by default.
  final void Function(BuildContext context, MediaCollection results)?
      openResults;

  /// How many titles a request finds; TMDB's count by default.
  final DiscoverCounter? countResults;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final Map<MediaKind, DiscoverQuery> _queries = <MediaKind, DiscoverQuery>{
    MediaKind.movie: DiscoverQuery(MediaKind.movie),
    MediaKind.series: DiscoverQuery(MediaKind.series),
  };
  MediaKind _kind = MediaKind.movie;

  /// What each set of choices finds, by request; kept so going back to a
  /// set of choices shows its count at once.
  final Map<String, int?> _counts = <String, int?>{};
  Timer? _countTimer;
  bool _started = false;

  DiscoverQuery get _query => _queries[_kind]!;

  String get _url {
    final settings = context.read<SettingsProvider>();
    return _query.url(settings.appLanguage, includeAdult: settings.isAdult);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _count();
    }
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    super.dispose();
  }

  void _change(void Function(DiscoverQuery query) edit) {
    HapticFeedback.selectionClick();
    setState(() => edit(_query));
    _count();
  }

  void _toggle(Set<String> values, String value) => _change(
        (_) =>
            values.contains(value) ? values.remove(value) : values.add(value),
      );

  void _switchKind(MediaKind kind) {
    if (kind == _kind) return;
    HapticFeedback.selectionClick();
    setState(() => _kind = kind);
    _count();
  }

  /// Asks, once the choices settle, how many titles they find. Each answer
  /// is filed under its own request, so a late one can't label the wrong
  /// choices.
  void _count() {
    _countTimer?.cancel();
    final url = _url;
    if (_counts.containsKey(url)) return;
    final counter = widget.countResults ??
        (url) {
          final settings = context.read<SettingsProvider>();
          final dependencies = context.read<AppDependencyProvider>();
          return fetchDiscoverTotal(
            url,
            proxyEnabled: settings.enableProxy,
            proxyUrl: dependencies.tmdbProxy,
          );
        };
    _countTimer = Timer(const Duration(milliseconds: 450), () async {
      final count = await counter(url);
      if (mounted) setState(() => _counts[url] = count);
    });
  }

  void _showResults() {
    final query = _query;
    final movie = query.kind == MediaKind.movie;
    final results = const CatalogController().listCollection(
      id: 'discover-${query.kind.name}-${query.url('')}',
      kind: query.kind,
      url: _url,
      title: tr(movie ? 'discover_movies' : 'discover_tv_series'),
      kicker: tr('browse_with_filters').toUpperCase(),
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
      // The placements the old Discover results pages reported.
      adPlacement: movie ? 'discover_movies' : 'discover_tv',
    );
    final open = widget.openResults;
    if (open != null) return open(context, results);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionScreen(collection: results),
      ),
    );
  }

  String _ratingsLabel(int threshold) => tr(
        'ratings_at_least',
        namedArgs: <String, String>{
          'n': NumberFormat.compact(
            locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
          ).format(threshold),
        },
      );

  /// The choices made, each with a way to take it back.
  List<(String, VoidCallback)> _active(DiscoverQuery query) {
    String genreName(String id) => tr(
          query.genreOptions.firstWhere((genre) => genre.value == id).label,
        );
    String serviceName(String id) => DiscoverQuery.services
        .firstWhere((service) => service.value == id)
        .label;
    return <(String, VoidCallback)>[
      for (final id in query.genres)
        (genreName(id), () => _toggle(query.genres, id)),
      for (final id in query.providers)
        (serviceName(id), () => _toggle(query.providers, id)),
      if (query.year.isNotEmpty)
        (query.year, () => _change((query) => query.year = '')),
      if (query.minimumRatings > 0)
        (
          _ratingsLabel(query.minimumRatings),
          () => _change((query) => query.minimumRatings = 0),
        ),
      if (query.kind == MediaKind.series && query.status != 0)
        (
          tr(DiscoverQuery.seriesStatuses[query.status].label),
          () => _change((query) => query.status = 0),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final query = _query;
    final movie = query.kind == MediaKind.movie;
    final active = _active(query);
    final url = _url;
    final changed = active.isNotEmpty || query.sort != 0;

    return Scaffold(
      backgroundColor: palette.page,
      appBar: AppBar(
        backgroundColor: palette.page,
        surfaceTintColor: Colors.transparent,
        title: Text(
          tr('browse_with_filters'),
          style: AppType.sectionHeader.copyWith(
            fontFamily: AppType.bold,
            color: palette.foreground,
          ),
        ),
        actions: <Widget>[
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: changed ? 1 : 0,
            child: TextButton(
              onPressed:
                  changed ? () => _change((query) => query.clear()) : null,
              style: TextButton.styleFrom(foregroundColor: palette.foreground),
              child: Text(tr('clear_all')),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
            child: SegmentSwitch<MediaKind>(
              segments: <Segment<MediaKind>>[
                Segment(
                  MediaKind.movie,
                  tr('movies'),
                  icon: PhosphorIcons.filmSlate(),
                ),
                Segment(
                  MediaKind.series,
                  tr('series'),
                  icon: PhosphorIcons.television(),
                ),
              ],
              selected: _kind,
              onChanged: _switchKind,
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          if (active.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              sliver: SliverToBoxAdapter(
                child: _ActiveFilters(filters: active),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            sliver: SliverList.list(
              children: <Widget>[
                _Section(
                  title: tr('sort_by'),
                  child: _SortGrid(
                    selected: query.sort,
                    onSelect: (index) => _change((query) => query.sort = index),
                  ),
                ),
                _Section(
                  title: tr('genres'),
                  child: Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: <Widget>[
                      for (final genre in query.genreOptions)
                        TogglePill(
                          label: tr(genre.label),
                          selected: query.genres.contains(genre.value),
                          onTap: () => _toggle(query.genres, genre.value),
                        ),
                    ],
                  ),
                ),
                _Section(
                  title: tr('streaming_on'),
                  child: _ServiceGrid(
                    selected: query.providers,
                    onToggle: (id) => _toggle(query.providers, id),
                  ),
                ),
                _Section(
                  title: tr('year'),
                  padded: false,
                  child: _YearRail(
                    selected: query.year,
                    onSelect: (year) => _change((query) => query.year = year),
                  ),
                ),
                _Section(
                  title: tr('minimum_ratings'),
                  child: Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: <Widget>[
                      for (final threshold in DiscoverQuery.ratingThresholds)
                        TogglePill(
                          label: threshold == 0
                              ? tr('any')
                              : _ratingsLabel(threshold),
                          selected: query.minimumRatings == threshold,
                          onTap: () => _change(
                            (query) => query.minimumRatings = threshold,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!movie)
                  _Section(
                    title: tr('tv_series_status'),
                    child: Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: <Widget>[
                        for (var i = 0;
                            i < DiscoverQuery.seriesStatuses.length;
                            i++)
                          TogglePill(
                            label: tr(DiscoverQuery.seriesStatuses[i].label),
                            selected: query.status == i,
                            onTap: () => _change((query) => query.status = i),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ShowResultsBar(
        counting: !_counts.containsKey(url),
        count: _counts[url],
        onShow: _showResults,
      ),
    );
  }
}


/// The choices made so far, each with an × to take it back.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filters});

  final List<(String, VoidCallback)> filters;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, index) {
          final (label, remove) = filters[index];
          return Semantics(
            button: true,
            child: Material(
              color: palette.raisedSurface,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: remove,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 10, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        style: AppType.cardTitle.copyWith(
                          fontSize: 13,
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        PhosphorIcons.x(),
                        size: 13,
                        color: palette.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.padded = true,
  });

  final String title;
  final Widget child;

  /// Whether [child] sits within the page's margins; a rail that scrolls
  /// to the edges doesn't.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: AppType.kicker.copyWith(color: palette.mutedText),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          if (padded)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: child,
            )
          else
            child,
        ],
      ),
    );
  }
}


/// The four orders as tiles, each with a mark for what it does.
class _SortGrid extends StatelessWidget {
  const _SortGrid({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final options = <(String, IconData)>[
      ('most_popular', PhosphorIcons.fire()),
      ('least_popular', PhosphorIcons.trendDown()),
      ('highest_rated', PhosphorIcons.star()),
      ('lowest_rated', PhosphorIcons.starHalf()),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpace.sm) / 2;
        return Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: <Widget>[
            for (var i = 0; i < options.length; i++)
              SizedBox(
                width: width,
                height: 56,
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  child: Material(
                    color: i == selected ? palette.focusFill : palette.surface,
                    borderRadius: BorderRadius.circular(AppRadii.hero),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              options[i].$2,
                              size: 20,
                              color: i == selected
                                  ? palette.onFocus
                                  : palette.secondaryText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr(options[i].$1),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.cardTitle.copyWith(
                                  color: i == selected
                                      ? palette.onFocus
                                      : palette.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The services as their logos on dark plates; a chosen one gets an ink ring
/// and a check.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
    final columns = wide ? 5 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final service in DiscoverQuery.services)
              _ServiceTile(
                width: width,
                name: service.label,
                logo: appStreamingServices
                    .where((known) => known.name == service.label)
                    .firstOrNull
                    ?.imagePath,
                selected: selected.contains(service.value),
                ring: palette.foreground,
                onTap: () => onToggle(service.value),
              ),
          ],
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.width,
    required this.name,
    required this.logo,
    required this.selected,
    required this.ring,
    required this.onTap,
  });

  final double width;
  final String name;
  final String? logo;
  final bool selected;
  final Color ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final logo = this.logo;
    const ink = Color(0xFF141516);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // The ring sits outside the plate with a gap, so it reads against
        // the page in every theme, light plate or not.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          height: width * .58,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card + 3),
            border: Border.all(
              color: selected ? ring : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // A fixed light plate: the logos are app icons.
              color: AppPalette.logoPlate,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: logo == null
                        ? Center(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: AppType.cardTitle.copyWith(color: ink),
                            ),
                          )
                        : Image.asset(logo, fit: BoxFit.contain),
                  ),
                ),
                if (name.endsWith('Kids'))
                  const PositionedDirectional(
                    start: 6,
                    bottom: 5,
                    child: Text(
                      'KIDS',
                      style: TextStyle(
                        color: ink,
                        fontFamily: AppType.bold,
                        fontSize: 9,
                        height: 1,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                if (selected)
                  PositionedDirectional(
                    top: 4,
                    end: 4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: ink,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.check(PhosphorIconsStyle.bold),
                        size: 11,
                        color: const Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Any, then this year back to 1950, as a rail to swipe along.
class _YearRail extends StatelessWidget {
  const _YearRail({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final years = <String>['', ...DiscoverQuery.years()];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, index) {
          final year = years[index];
          return TogglePill(
            label: year.isEmpty ? tr('any') : year,
            selected: year == selected,
            onTap: () => onSelect(year),
          );
        },
      ),
    );
  }
}

/// The one action: show what the choices find, saying how much that is.
class _ShowResultsBar extends StatelessWidget {
  const _ShowResultsBar({
    required this.counting,
    required this.count,
    required this.onShow,
  });

  final bool counting;
  final int? count;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final count = this.count;
    final none = !counting && count == 0;
    final label = none
        ? tr('no_titles_match')
        : count == null
            ? tr('show_results')
            : tr(
                'show_titles',
                namedArgs: <String, String>{
                  'n': NumberFormat.decimalPattern(
                    Localizations.maybeLocaleOf(context)?.toLanguageTag(),
                  ).format(count),
                },
              );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.page,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12),
          child: PillButton(
            primary: true,
            height: 50,
            busy: counting,
            icon: PhosphorIcons.arrowRight(),
            label: label,
            onPressed: none ? null : onShow,
          ),
        ),
      ),
    );
  }
}
