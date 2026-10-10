import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../widgets/playback_action.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/media_item.dart';
import '../../catalog/media_search.dart';
import '../../constants/app_constants.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../models/genres.dart';
import '../../models/person.dart';
import '../../preferences/setting_preferences.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/person/searchedperson.dart';
import '../app/mobile_tabs.dart';
import '../collections.dart';
import '../playback.dart';
import 'discover_screen.dart';
import '../widgets/category_section.dart';
import '../widgets/filter_chips.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_header.dart';
import '../widgets/title_sheet.dart';

/// Which kinds of result Search shows.
enum SearchFilter { all, movies, series, people }

/// The Search tab: a field at the top; recent and top searches, genres and
/// the filtered browser before anything is typed; every kind of result, each
/// in its own section, once something is.
///
/// A query goes out once typing pauses, and only an answer to the latest
/// query is shown; the previous results stay up while it's on its way. A
/// query is remembered only when it's submitted or one of its results
/// opened, not for every word on the way.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    this.source,
    this.loadSuggestions,
    this.preferences,
    this.openTitle,
    super.key,
  });

  /// Where results come from; TMDB by default.
  final SearchSource? source;

  /// Top searches and genres, before anything is typed.
  final Future<SearchSuggestions> Function()? loadSuggestions;

  /// Where recent searches are kept.
  final SettingsPreferences? preferences;

  /// Opens a result; its details page by default.
  final void Function(BuildContext context, MediaItem item)? openTitle;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _field = FocusNode(debugLabel: 'Search field');
  late final SettingsPreferences _preferences =
      widget.preferences ?? SettingsPreferences();

  Timer? _debounce;

  /// Bumped for every query sent or abandoned; an answer carrying an older
  /// number is for a query the viewer has moved on from.
  int _generation = 0;
  SearchResults? _results;
  bool _searching = false;
  SearchFilter _filter = SearchFilter.all;
  List<String> _recents = const <String>[];
  Future<SearchSuggestions>? _suggestions;

  MobileTabController? _tabs;
  MobileTab? _lastTab;

  String get _text => _query.text.trim();

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs?.removeListener(_onTab);
      _tabs?.removeResetListener(MobileTab.search, _clear);
      _tabs = tabs
        ?..addListener(_onTab)
        ..addResetListener(MobileTab.search, _clear);
      _lastTab = tabs?.current;
      // Built by the switch to this tab (it's built on first visit), so
      // that switch is one to answer.
      if (tabs != null &&
          tabs.current == MobileTab.search &&
          tabs.switches > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _field.requestFocus();
        });
      }
    }
    _suggestions ??= widget.loadSuggestions?.call() ??
        const CatalogController().loadSearchSuggestions(
          settings: context.read<SettingsProvider>(),
          dependencies: context.read<AppDependencyProvider>(),
        );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs?.removeListener(_onTab);
    _tabs?.removeResetListener(MobileTab.search, _clear);
    _query.dispose();
    _field.dispose();
    super.dispose();
  }

  /// Arriving on the tab puts the cursor in the field; opening the app on it
  /// doesn't, so the keyboard doesn't cover the page at launch.
  void _onTab() {
    final current = _tabs?.current;
    if (current == MobileTab.search && _lastTab != MobileTab.search) {
      _field.requestFocus();
    } else if (current != MobileTab.search) {
      _field.unfocus();
    }
    _lastTab = current;
  }

  Future<void> _loadRecents() async {
    final recents = await _preferences.getRecentSearches();
    if (mounted) setState(() => _recents = recents);
  }

  Future<void> _remember(String query) async {
    if (!MediaSearch.searchable(query)) return;
    await _preferences.addRecentSearch(query.trim());
    await _loadRecents();
  }

  Future<void> _forget(String query) async {
    await _preferences.removeRecentSearch(query);
    await _loadRecents();
  }

  Future<void> _forgetAll() async {
    await _preferences.clearRecentSearches();
    await _loadRecents();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    final query = _text;
    if (!MediaSearch.searchable(query)) {
      _generation++;
      setState(() {
        _searching = false;
        if (query.isEmpty) _results = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(MediaSearch.debounce, () => _search(query));
  }

  void _onSubmitted(String _) {
    final query = _text;
    if (!MediaSearch.searchable(query)) return;
    _remember(query);
    // Searching now rather than waiting out the pause.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _search(query);
    }
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    context.read<SettingsProvider>().analytics.trackSearch(query);
    final source = widget.source ??
        TmdbSearchSource(
          settings: context.read<SettingsProvider>(),
          dependencies: context.read<AppDependencyProvider>(),
        );
    final results = await MediaSearch.run(source, query);
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  /// Puts [query] in the field and searches for it, as tapping a recent
  /// search does.
  void _fill(String query) {
    _query.text = query;
    _query.selection = TextSelection.collapsed(offset: query.length);
    _onChanged(query);
  }

  /// Back to how the tab started: nothing typed, the field closed.
  void _clear() {
    _debounce?.cancel();
    _generation++;
    _query.clear();
    _field.unfocus();
    setState(() {
      _results = null;
      _searching = false;
      _filter = SearchFilter.all;
    });
  }

  /// Opening a result remembers what found it.
  void _open(MediaItem item) {
    _remember(_text);
    (widget.openTitle ?? MobilePlayback.openDetails)(context, item);
  }

  void _openPerson(Person person) {
    _remember(_text);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SearchedPersonDetailPage(
          person: person,
          heroId: 'search-person-${person.id}',
        ),
      ),
    );
  }

  /// Discover's tab where there is one; its page pushed over Search
  /// otherwise.
  void _openFilters() {
    final tabs = _tabs;
    if (tabs != null) return tabs.select(MobileTab.discover);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const DiscoverScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final media = MediaQuery.of(context);
    final results = _results;
    final typed = MediaSearch.searchable(_text);
    final showResults = typed && results != null;

    final List<Widget> content;
    if (!typed) {
      content = _startSlivers(context);
    } else if (results == null) {
      // The first answer is on its way: its shape, pulsing.
      content = const <Widget>[
        SliverToBoxAdapter(child: _ResultsSkeleton()),
      ];
    } else if (results.isEmpty) {
      content = _noMatchSlivers(context, results.query);
    } else {
      content = _resultSlivers(context, results);
    }

    return ColoredBox(
      color: palette.page,
      child: CustomScrollView(
        controller: _tabs?.scrollController(MobileTab.search),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchHeaderDelegate(
              topInset: media.padding.top,
              palette: palette,
              chips: showResults && !results.isEmpty ? _chips() : null,
              field: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.gutter(context),
                ),
                child: SearchPill(
                  controller: _query,
                  focusNode: _field,
                  hint: tr('search_hint'),
                  searching: _searching,
                  onChanged: _onChanged,
                  onSubmitted: _onSubmitted,
                  onClear: _field.requestFocus,
                ),
              ),
            ),
          ),
          ...content,
          SliverToBoxAdapter(
            child: SizedBox(height: media.padding.bottom + AppSpace.xxl),
          ),
        ],
      ),
    );
  }

  List<FilterChipSpec> _chips() => <FilterChipSpec>[
        for (final (filter, label) in <(SearchFilter, String)>[
          (SearchFilter.all, tr('filter_all')),
          (SearchFilter.movies, tr('movies')),
          (SearchFilter.series, tr('series')),
          (SearchFilter.people, tr('people')),
        ])
          FilterChipSpec(
            label: label,
            selected: _filter == filter,
            onTap: () => setState(() => _filter = filter),
          ),
      ];

  // Before anything is typed.

  List<Widget> _startSlivers(BuildContext context) => <Widget>[
        if (_recents.isNotEmpty)
          SliverToBoxAdapter(
            child: _RecentSearches(
              searches: _recents,
              onSearch: (query) {
                _fill(query);
                _remember(query);
              },
              onRemove: _forget,
              onClear: _forgetAll,
            ),
          ),
        SliverToBoxAdapter(child: _BrowseWithFilters(onTap: _openFilters)),
        ..._suggestionSlivers(context, withGenres: true),
      ];

  List<Widget> _suggestionSlivers(
    BuildContext context, {
    required bool withGenres,
  }) =>
      <Widget>[
        SliverToBoxAdapter(
          child: FutureBuilder<SearchSuggestions>(
            future: _suggestions,
            builder: (context, snapshot) {
              final suggestions = snapshot.data ?? SearchSuggestions.empty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (suggestions.topSearches.isNotEmpty)
                    _TopSearches(items: suggestions.topSearches),
                  if (withGenres) ...<Widget>[
                    if (suggestions.movieGenres.isNotEmpty)
                      _GenreTiles(
                        title: tr('movie_genres'),
                        kind: MediaKind.movie,
                        genres: suggestions.movieGenres,
                      ),
                    if (suggestions.seriesGenres.isNotEmpty)
                      _GenreTiles(
                        title: tr('series_genres'),
                        kind: MediaKind.series,
                        genres: suggestions.seriesGenres,
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ];

  // Nothing found.

  List<Widget> _noMatchSlivers(BuildContext context, String query) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return <Widget>[
      SliverToBoxAdapter(
        child: FutureBuilder<SearchSuggestions>(
          future: _suggestions,
          builder: (context, snapshot) {
            final suggestions = snapshot.data ?? SearchSuggestions.empty;
            final wanted = MediaSearch.normalize(query);
            // Genres whose names hold what was typed: "com" finds Comedy.
            final tries = <(MediaKind, Genres)>[
              for (final genre in suggestions.movieGenres)
                if (MediaSearch.normalize(genre.genreName!).contains(wanted))
                  (MediaKind.movie, genre),
              for (final genre in suggestions.seriesGenres)
                if (MediaSearch.normalize(genre.genreName!).contains(wanted))
                  (MediaKind.series, genre),
            ];
            return Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpace.xl, gutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr(
                      'no_matches_for',
                      namedArgs: <String, String>{'query': query},
                    ),
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                  if (tries.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpace.md),
                    Text(
                      tr('try_searching'),
                      style: AppType.metadata.copyWith(
                        color: palette.mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: <Widget>[
                        for (final (kind, genre) in tries)
                          _Pill(
                            icon: PhosphorIcons.squaresFour(),
                            label: '${genre.genreName} · '
                                '${tr(kind == MediaKind.movie ? 'movies' : 'series')}',
                            onTap: () =>
                                openGenreCollection(context, kind, genre),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                ],
              ),
            );
          },
        ),
      ),
      ..._suggestionSlivers(context, withGenres: false),
    ];
  }

  // Results.

  List<Widget> _resultSlivers(BuildContext context, SearchResults results) {
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppBreakpoints.tablet ? 5 : 3;
    bool shows(SearchFilter filter) =>
        _filter == SearchFilter.all || _filter == filter;
    final top = results.topResult;

    Widget grid(List<MediaItem> items) => SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.rowGap),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: PosterCard.aspectRatio,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => LayoutBuilder(
              builder: (context, constraints) => PosterCard(
                item: items[index],
                width: constraints.maxWidth,
                onTap: () => _open(items[index]),
              ),
            ),
          ),
        );
    Widget header(String title) => SliverToBoxAdapter(
          child: SectionHeader(title: title),
        );

    final movies = results.movies;
    final series = results.series;
    final nothingHere = (_filter == SearchFilter.movies && movies.isEmpty) ||
        (_filter == SearchFilter.series && series.isEmpty) ||
        (_filter == SearchFilter.people && results.people.isEmpty);
    return <Widget>[
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.sm)),
      if (top != null && _filter == SearchFilter.all) ...<Widget>[
        header(tr('top_result')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
            child: FeatureCard(item: top, onTap: () => _open(top)),
          ),
        ),
      ],
      if (shows(SearchFilter.movies) && movies.isNotEmpty) ...<Widget>[
        header(tr('movies')),
        grid(movies),
      ],
      if (shows(SearchFilter.series) && series.isNotEmpty) ...<Widget>[
        header(tr('series')),
        grid(series),
      ],
      if (shows(SearchFilter.people) && results.people.isNotEmpty) ...<Widget>[
        header(tr('people')),
        SliverToBoxAdapter(
          child: _People(people: results.people, onOpen: _openPerson),
        ),
      ],
      if (nothingHere)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(gutter),
            child: Text(
              tr('no_matches_for', namedArgs: <String, String>{
                'query': results.query,
              }),
              style: AppType.body.copyWith(
                color: AppPalette.of(context).mutedText,
              ),
            ),
          ),
        ),
    ];
  }
}

/// The field, pinned, and the result filters under it once there are
/// results; it takes on the page colour so results pass cleanly beneath.
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchHeaderDelegate({
    required this.topInset,
    required this.palette,
    required this.field,
    this.chips,
  });

  final double topInset;
  final AppPalette palette;
  final Widget field;
  final List<FilterChipSpec>? chips;

  static const _fieldRow = 64.0;
  static const _chipRow = FilterChips.height + 12;

  @override
  double get maxExtent => topInset + _fieldRow + (chips == null ? 0 : _chipRow);

  @override
  double get minExtent => maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final chips = this.chips;
    return ColoredBox(
      color: palette.page,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Column(
          children: <Widget>[
            SizedBox(height: _fieldRow, child: Center(child: field)),
            if (chips != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilterChips(chips: chips),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchHeaderDelegate oldDelegate) => true;
}

/// Recent searches as chips: tap to search again, long press to forget one,
/// Clear to forget them all.
class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.onSearch,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> searches;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter - 8, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    tr('recent_searches'),
                    style: AppType.sectionHeader.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.mutedText,
                  ),
                  child: Text(tr('clear')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: <Widget>[
                for (final search in searches)
                  _Pill(
                    icon: PhosphorIcons.clockCounterClockwise(),
                    label: search,
                    onTap: () => onSearch(search),
                    onLongPress: () => onRemove(search),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft pill with an icon: a recent search, a genre to try.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.idleFill,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: palette.mutedText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(color: palette.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseWithFilters extends StatelessWidget {
  const _BrowseWithFilters({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.rowGap),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.hero),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(
                  PhosphorIcons.slidersHorizontal(),
                  size: 24,
                  color: palette.foreground,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tr('browse_with_filters'),
                        style: AppType.cardTitle.copyWith(
                          fontSize: 15,
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('browse_with_filters_hint'),
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? PhosphorIcons.caretLeft()
                      : PhosphorIcons.caretRight(),
                  size: 18,
                  color: palette.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's most watched as a list, each saying whether it's a movie or a
/// series; tap for details, the play mark to start it.
class _TopSearches extends StatelessWidget {
  const _TopSearches({required this.items});

  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final canPlay = MobilePlayback.canPlay(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: tr('top_searches')),
          for (final item in items)
            InkWell(
              onTap: () => MobilePlayback.openDetails(context, item),
              onLongPress: () => showTitleSheet(context, item),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 5),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: SizedBox(
                        width: 128,
                        height: 72,
                        child: MediaArt(
                          item: item,
                          path: item.backdropPath ?? item.posterPath,
                          width: 128,
                          size:
                              item.backdropPath == null ? null : ArtSize.still,
                          placeholder: MediaArt.darkPlaceholder,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.cardTitle.copyWith(
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mediaFacts(item),
                            style: AppType.metadata.copyWith(
                              color: palette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canPlay)
                      PlaybackAction(
                        onStart: () => MobilePlayback.play(context, item),
                        builder: (context, busy, start) => IconButton(
                          tooltip: tr('play'),
                          color: palette.foreground,
                          onPressed: busy ? null : start,
                          icon: busy
                              ? SizedBox.square(
                                  dimension: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.foreground,
                                  ),
                                )
                              : PlaybackIcon(PhosphorIcons.playCircle(),
                                  size: 30),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A kind's genres as tiles, two to a row on phones.
class _GenreTiles extends StatelessWidget {
  const _GenreTiles({
    required this.title,
    required this.kind,
    required this.genres,
  });

  final String title;
  final MediaKind kind;
  final List<Genres> genres;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppBreakpoints.tablet ? 4 : 2;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(title: title),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final tile =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: <Widget>[
                    for (final genre in genres)
                      SizedBox(
                        width: tile,
                        height: 52,
                        child: Material(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                openGenreCollection(context, kind, genre),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  genre.genreName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.cardTitle.copyWith(
                                    fontSize: 15,
                                    color: palette.foreground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// People who match, as round portraits with their names.
class _People extends StatelessWidget {
  const _People({required this.people, required this.onOpen});

  final List<Person> people;
  final ValueChanged<Person> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    const size = 84.0;
    return SizedBox(
      height: size + 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final person = people[index];
          final url = tmdbImageUrl(context, person.profilePath, size: 'w185/');
          return Pressable(
            semanticLabel: person.name,
            onTap: () => onOpen(person),
            child: SizedBox(
              width: size,
              child: Column(
                children: <Widget>[
                  ClipOval(
                    child: Container(
                      width: size,
                      height: size,
                      color: palette.raisedSurface,
                      child: url == null
                          ? Icon(
                              PhosphorIcons.user(),
                              size: 34,
                              color: palette.mutedText,
                            )
                          : CachedNetworkImage(
                              cacheManager: cacheProp(),
                              imageUrl: url,
                              fit: BoxFit.cover,
                              memCacheWidth: (size *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                              errorWidget: (_, __, ___) => Icon(
                                PhosphorIcons.user(),
                                size: 34,
                                color: palette.mutedText,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    person.name ?? '',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata.copyWith(
                      fontFamily: AppType.semiBold,
                      color: palette.foreground,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Results while the first answer comes: the top result's wide card, then
/// a grid of posters.
class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= AppBreakpoints.tablet ? 5 : 3;
    final poster = (width - gutter * 2 - 10 * (columns - 1)) / columns;
    return SkeletonPulse(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBlock.line(width: 110, height: 16),
            const SizedBox(height: AppSpace.md),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBlock(width: width, radius: AppRadii.hero),
            ),
            const SizedBox(height: AppSpace.rowGap),
            const SkeletonBlock.line(width: 80, height: 16),
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (var i = 0; i < columns * 2; i++)
                  SkeletonBlock(
                    width: poster,
                    height: poster / PosterCard.aspectRatio,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
