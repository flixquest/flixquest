import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/discover_query.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../widgets/common_widgets.dart' show appStreamingServices;
import '../app/tv_design.dart';
import '../controllers/tv_catalog_controller.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_choice_row.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_focus_list.dart';
import '../widgets/tv_loading_skeletons.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_page_header.dart';
import '../widgets/tv_pill_button.dart';
import 'tv_discover_country_screen.dart';

/// The filters a Discover panel lists, in order.
enum _Filter { sort, genres, country, services, year, ratings, status }

/// One row of the panel: a filter to open, or an option within one.
class _Choice {
  const _Choice({
    required this.label,
    required this.onActivate,
    this.detail,
    this.leading,
    this.mark = TvChoiceMark.none,
    this.selected = false,
  });

  final String label;
  final String? detail;
  final Widget? leading;
  final TvChoiceMark mark;
  final bool selected;
  final VoidCallback onActivate;
}

/// Browse with filters on a TV: the filters in a panel on the left, and on
/// the right everything they find, refreshed as they change.
///
/// The panel lists one row per filter with its current choice under it; OK
/// opens the filter's options in its place, and Back or Left closes them.
/// A filter with one answer (sort, year) closes as soon as it is chosen;
/// one that takes several (genres, countries, services) stays open, so the
/// results can be watched changing behind each OK. Countries can also be
/// searched by name on a keyboard of their own.
///
/// Right from the panel enters the results; Left off their first column or
/// Back returns to the panel row it came from. Movies and series keep their
/// own filters, as on the phone.
class TvDiscoverScreen extends StatefulWidget {
  const TvDiscoverScreen({
    required this.metrics,
    required this.onOpenMedia,
    this.focusController,
    this.controller = const TvCatalogController(),
    this.countResults,
    this.loadCountries,
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final TvScreenFocusController? focusController;
  final TvCatalogController controller;

  /// How many titles a request finds; TMDB's count by default.
  final DiscoverCounter? countResults;

  /// The countries to choose from; TMDB's list by default.
  final DiscoverCountryLoader? loadCountries;

  /// How long the filters must be left alone before the results follow.
  static const settlePause = Duration(milliseconds: 450);

  @override
  State<TvDiscoverScreen> createState() => _TvDiscoverScreenState();
}

class _TvDiscoverScreenState extends State<TvDiscoverScreen> {
  static final _backKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };

  /// How close to the end focus gets before the next page is fetched.
  static const _prefetchDistance = 12;

  final Map<TvMediaKind, DiscoverQuery> _queries = <TvMediaKind, DiscoverQuery>{
    TvMediaKind.movie: DiscoverQuery(TvMediaKind.movie),
    TvMediaKind.series: DiscoverQuery(TvMediaKind.series),
  };
  TvMediaKind _kind = TvMediaKind.movie;

  DiscoverQuery get _query => _queries[_kind]!;

  // The panel.

  /// The filter whose options are showing, if any.
  _Filter? _open;
  GlobalKey<TvFocusListState> _filterList = GlobalKey<TvFocusListState>();
  GlobalKey<TvFocusListState> _optionList = GlobalKey<TvFocusListState>();

  /// The countries chosen as their options opened; the list is ordered by
  /// these, so a row never moves out from under the remote.
  Set<String> _countriesAtOpen = const <String>{};
  final FocusNode _movieTab = FocusNode(debugLabel: 'TV discover movies');
  final FocusNode _seriesTab = FocusNode(debugLabel: 'TV discover series');

  /// Whether focus last sat on the kind switch rather than a list, so a
  /// return to the panel goes back there.
  bool _onKindSwitch = true;

  // The results.

  late final FocusNode _resultsRegion = FocusNode(
    debugLabel: 'TV discover results',
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _handleResultsKey,
  );
  final FocusNode _resultsAction =
      FocusNode(debugLabel: 'TV discover results action');
  final TvContentGridController _grid = TvContentGridController();

  /// The request whose results are showing, and the one being loaded.
  String? _shownUrl;
  String? _wantedUrl;
  TvCollection? _collection;
  List<TvMediaItem> _items = const <TvMediaItem>[];
  final Set<String> _ids = <String>{};
  int _pages = 0;
  bool _loadingMore = false;
  bool _ended = false;
  Object? _error;
  int _generation = 0;

  /// What each request finds, by request; kept so going back to a set of
  /// choices shows its count at once.
  final Map<String, int?> _counts = <String, int?>{};
  Timer? _settleTimer;
  bool _started = false;

  late Future<List<DiscoverCountry>> _allCountries;
  List<DiscoverCountry> _countries = DiscoverQuery.featuredCountries;

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _focusEntry);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
    _loadCountries();
  }

  @override
  void didUpdateWidget(TvDiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _focusEntry);
    }
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _settleTimer?.cancel();
    _movieTab.dispose();
    _seriesTab.dispose();
    _resultsRegion.dispose();
    _resultsAction.dispose();
    super.dispose();
  }

  String get _url {
    final settings = context.read<SettingsProvider>();
    return _query.url(settings.appLanguage, includeAdult: settings.isAdult);
  }

  void _loadCountries() {
    final language = context.read<SettingsProvider>().appLanguage;
    final load = widget.loadCountries ??
        (language) => fetchDiscoverCountries(
              language,
              proxyUrl: context.read<AppDependencyProvider>().tmdbProxy,
            );
    _allCountries = load(language);
    _allCountries.then((countries) {
      if (mounted) setState(() => _countries = countries);
    });
  }

  // Changing the filters.

  void _change(void Function(DiscoverQuery query) edit) {
    setState(() => edit(_query));
    _settleTimer?.cancel();
    _settleTimer = Timer(TvDiscoverScreen.settlePause, _load);
  }

  void _toggle(Set<String> values, String value) => _change(
        (_) =>
            values.contains(value) ? values.remove(value) : values.add(value),
      );

  void _switchKind(TvMediaKind kind) {
    if (kind == _kind) return;
    _settleTimer?.cancel();
    setState(() {
      _kind = kind;
      // Series and movies have different options; a list open for one
      // means nothing for the other.
      _open = null;
      _filterList = GlobalKey<TvFocusListState>();
    });
    _load();
  }

  List<_Filter> get _filters => <_Filter>[
        _Filter.sort,
        _Filter.genres,
        _Filter.country,
        _Filter.services,
        _Filter.year,
        _Filter.ratings,
        if (_kind == TvMediaKind.series) _Filter.status,
      ];

  bool get _changed => _query.activeCount > 0 || _query.sort != 0;

  void _openFilter(_Filter filter) {
    setState(() {
      _open = filter;
      _optionList = GlobalKey<TvFocusListState>();
      _countriesAtOpen = <String>{..._query.countries};
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _optionList.currentState?.focus();
    });
  }

  /// Back to the filters, on the row of the one that was open.
  void _closeFilter() {
    final filter = _open;
    if (filter == null) return;
    final index = _filters.indexOf(filter);
    setState(() {
      _open = null;
      _filterList = GlobalKey<TvFocusListState>();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _filterList.currentState?.focus(index < 0 ? 0 : index);
    });
  }

  /// Sets a filter that takes one answer, and goes back to the filters.
  void _choose(void Function(DiscoverQuery query) edit) {
    _change(edit);
    _closeFilter();
  }

  void _clearAll() {
    _change((query) => query.clear());
    // The Clear row goes with the filters it cleared.
    _filterList.currentState?.focus(0);
  }

  Future<void> _searchCountries() async {
    final query = _query;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TvDiscoverCountryScreen(
          countries: _allCountries,
          selected: query.countries,
          onToggle: (code) => _toggle(query.countries, code),
        ),
      ),
    );
    if (!mounted) return;
    // Countries found by search join the list near the top, by the search
    // row the remote comes back to.
    setState(() {
      _countriesAtOpen = <String>{...query.countries};
      _optionList = GlobalKey<TvFocusListState>();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _optionList.currentState?.focus(1);
    });
  }

  // The results.

  /// Starts on the results for the filters as they are now, unless they
  /// are already showing or on their way.
  void _load() {
    _settleTimer?.cancel();
    final url = _url;
    if (url == _wantedUrl) return;
    _wantedUrl = url;
    final query = _query;
    final movie = query.kind == TvMediaKind.movie;
    _collection = widget.controller.listCollection(
      id: 'discover-${query.kind.name}-${query.url('')}',
      kind: query.kind,
      url: url,
      title: tr(movie ? 'discover_movies' : 'discover_tv_series'),
      kicker: tr('browse_with_filters').toUpperCase(),
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    );
    _count(url);
    _loadPage(fresh: true);
  }

  /// Loads the first page of new results, or the next page of these. A
  /// late answer for filters since changed is dropped.
  Future<void> _loadPage({required bool fresh}) async {
    final collection = _collection;
    if (collection == null) return;
    if (!fresh && (_loadingMore || _ended || _shownUrl != _wantedUrl)) return;
    final generation = fresh ? ++_generation : _generation;
    final url = _wantedUrl;
    final page = fresh ? 1 : _pages + 1;
    if (!fresh) setState(() => _loadingMore = true);
    try {
      final loaded = await collection.loadPage(page);
      if (!mounted || generation != _generation) return;
      final hadFocus = _resultsRegion.hasFocus;
      var nothingNew = false;
      setState(() {
        if (fresh) {
          _shownUrl = url;
          _ids.clear();
          _items = const <TvMediaItem>[];
        }
        _error = null;
        _pages = page;
        _ended = loaded.isEmpty;
        // TMDB's discover pages can repeat a title across a page boundary,
        // and the grid needs every id once.
        final added = loaded.where((item) => _ids.add(item.stableId));
        final before = _items.length;
        _items = <TvMediaItem>[..._items, ...added];
        nothingNew = !_ended && _items.length == before;
        _loadingMore = false;
      });
      // New results replace a grid that had focus: land on their first.
      if (fresh && hadFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_enterResults()) _returnToPanel();
        });
      }
      // A page of nothing but repeats gives focus nowhere new to go, so
      // nothing would ask for the next one.
      if (nothingNew) unawaited(_loadPage(fresh: false));
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loadingMore = false;
        if (fresh) {
          _shownUrl = url;
          _ids.clear();
          _items = const <TvMediaItem>[];
        }
      });
    }
  }

  void _retry() {
    if (_items.isEmpty) {
      _wantedUrl = null;
      _load();
    } else {
      unawaited(_loadPage(fresh: false));
    }
  }

  void _count(String url) {
    if (_counts.containsKey(url)) return;
    final counter = widget.countResults ??
        (url) {
          final settings = context.read<SettingsProvider>();
          return fetchDiscoverTotal(
            url,
            proxyEnabled: settings.enableProxy,
            proxyUrl: context.read<AppDependencyProvider>().tmdbProxy,
          );
        };
    counter(url).then((count) {
      if (mounted) setState(() => _counts[url] = count);
    });
  }

  void _handleItemFocused(TvMediaItem item) {
    final index = _items.indexOf(item);
    if (index >= _items.length - _prefetchDistance) {
      unawaited(_loadPage(fresh: false));
    }
  }

  // Focus.

  /// From the rail: back to wherever the panel was left.
  bool _focusEntry() {
    if (_movieTab.context == null) return false;
    return _returnToPanel();
  }

  bool _focusKindSwitch() {
    final tab = _kind == TvMediaKind.movie ? _movieTab : _seriesTab;
    if (tab.context == null) return false;
    tab.requestFocus();
    return true;
  }

  bool _focusList() =>
      (_open == null ? _filterList : _optionList).currentState?.focus() ??
      false;

  bool _returnToPanel() {
    if (!_onKindSwitch && _focusList()) return true;
    return _focusKindSwitch();
  }

  /// Into the results: the first title, or what to do when there are none.
  bool _enterResults() {
    if (_items.isNotEmpty) return _grid.requestFocus();
    if (_resultsAction.context != null) {
      _resultsAction.requestFocus();
      return true;
    }
    return false;
  }

  KeyEventResult _handleKindKey(TvMediaKind tab, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final movie = tab == TvMediaKind.movie;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
        movie ? _seriesTab.requestFocus() : _enterResults();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (movie) return KeyEventResult.ignored;
        _movieTab.requestFocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _focusList();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Sees what the panel's rows leave: Right into the results, Left out of
  /// a filter's options.
  KeyEventResult _handlePanelKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _enterResults();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _open != null) {
      _closeFilter();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Sees what the grid leaves: Left off its first column back to the
  /// panel, and Up off its first row nowhere.
  KeyEventResult _handleResultsKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _returnToPanel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Back steps out one level at a time: from the results to the panel,
  /// from a filter's options to the filters, and only then to the rail.
  KeyEventResult _handleBack(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_backKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (_resultsRegion.hasFocus) {
      return _returnToPanel() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (_open != null) {
      _closeFilter();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Labels.

  static const _sortLabels = <String>[
    'most_popular',
    'least_popular',
    'highest_rated',
    'lowest_rated',
  ];

  static final _sortIcons = <IconData>[
    PhosphorIcons.fire(),
    PhosphorIcons.trendDown(),
    PhosphorIcons.star(),
    PhosphorIcons.starHalf(),
  ];

  String _ratingsLabel(int threshold) => threshold == 0
      ? tr('any')
      : tr(
          'ratings_at_least',
          namedArgs: <String, String>{
            'n': NumberFormat.compact(
              locale: Localizations.maybeLocaleOf(context)?.toLanguageTag(),
            ).format(threshold),
          },
        );

  String _genreNames(DiscoverQuery query) => query.genreOptions
      .where((genre) => query.genres.contains(genre.value))
      .map((genre) => tr(genre.label))
      .join(', ');

  String _serviceNames(DiscoverQuery query) => DiscoverQuery.services
      .where((service) => query.providers.contains(service.value))
      .map((service) => service.label)
      .join(', ');

  String _filterTitle(_Filter filter) => switch (filter) {
        _Filter.sort => tr('sort_by'),
        _Filter.genres => tr('genres'),
        _Filter.country => tr('country'),
        _Filter.services => tr('streaming_on'),
        _Filter.year => tr('year'),
        _Filter.ratings => tr('minimum_ratings'),
        _Filter.status => tr('tv_series_status'),
      };

  /// The filter's current choice, as its row shows it.
  String _filterValue(_Filter filter) {
    final query = _query;
    String orAny(String value) => value.isEmpty ? tr('any') : value;
    return switch (filter) {
      _Filter.sort => tr(_sortLabels[query.sort]),
      _Filter.genres => orAny(_genreNames(query)),
      _Filter.country => orAny(countryNames(query.countries, _countries)),
      _Filter.services => orAny(_serviceNames(query)),
      _Filter.year => orAny(query.year),
      _Filter.ratings => _ratingsLabel(query.minimumRatings),
      _Filter.status => tr(DiscoverQuery.seriesStatuses[query.status].label),
    };
  }

  IconData _filterIcon(_Filter filter) => switch (filter) {
        _Filter.sort => PhosphorIcons.sortAscending(),
        _Filter.genres => PhosphorIcons.maskHappy(),
        _Filter.country => PhosphorIcons.globeHemisphereWest(),
        _Filter.services => PhosphorIcons.monitorPlay(),
        _Filter.year => PhosphorIcons.calendarBlank(),
        _Filter.ratings => PhosphorIcons.star(),
        _Filter.status => PhosphorIcons.pulse(),
      };

  /// What the results are, on one line: the kind, then each choice.
  String _summary(DiscoverQuery query) {
    final parts = <String>[
      if (query.genres.isNotEmpty) _genreNames(query),
      if (query.countries.isNotEmpty) countryNames(query.countries, _countries),
      if (query.providers.isNotEmpty) _serviceNames(query),
      if (query.year.isNotEmpty) query.year,
      if (query.minimumRatings > 0) _ratingsLabel(query.minimumRatings),
      if (query.kind == TvMediaKind.series && query.status != 0)
        tr(DiscoverQuery.seriesStatuses[query.status].label),
    ];
    if (parts.isEmpty) return tr('no_filters_on');
    return parts.join('  ·  ');
  }

  // The panel's rows.

  List<_Choice> _filterChoices() {
    final query = _query;
    return <_Choice>[
      for (final filter in _filters)
        _Choice(
          label: _filterTitle(filter),
          detail: _filterValue(filter),
          leading: Icon(_filterIcon(filter)),
          mark: TvChoiceMark.caret,
          onActivate: () => _openFilter(filter),
        ),
      if (_changed)
        _Choice(
          label: tr('clear_all'),
          // What clearing leaves: everything, or how much it takes away.
          detail: query.activeCount == 0
              ? tr('no_filters_on')
              : tr(
                  'filters_on',
                  namedArgs: <String, String>{'n': '${query.activeCount}'},
                ),
          leading: Icon(PhosphorIcons.x()),
          onActivate: _clearAll,
        ),
    ];
  }

  List<_Choice> _optionChoices(_Filter filter) {
    final query = _query;
    _Choice any(Set<String> values) => _Choice(
          label: tr('any'),
          mark: TvChoiceMark.check,
          selected: values.isEmpty,
          onActivate: () => _change((_) => values.clear()),
        );
    final options = switch (filter) {
      _Filter.sort => <_Choice>[
          for (var i = 0; i < DiscoverQuery.sorts.length; i++)
            _Choice(
              label: tr(_sortLabels[i]),
              leading: Icon(_sortIcons[i]),
              mark: TvChoiceMark.radio,
              selected: query.sort == i,
              onActivate: () => _choose((query) => query.sort = i),
            ),
        ],
      _Filter.genres => <_Choice>[
          any(query.genres),
          for (final genre in query.genreOptions)
            _Choice(
              label: tr(genre.label),
              mark: TvChoiceMark.check,
              selected: query.genres.contains(genre.value),
              onActivate: () => _toggle(query.genres, genre.value),
            ),
        ],
      _Filter.country => <_Choice>[
          _Choice(
            label: tr('search_countries'),
            leading: Icon(PhosphorIcons.magnifyingGlass()),
            mark: TvChoiceMark.caret,
            onActivate: _searchCountries,
          ),
          any(query.countries),
          for (final country
              in DiscoverQuery.browseCountries(_countries, _countriesAtOpen))
            _Choice(
              label: country.name,
              detail: country.englishName == country.name
                  ? null
                  : country.englishName,
              leading: _Flag(country.code),
              mark: TvChoiceMark.check,
              selected: query.countries.contains(country.code),
              onActivate: () => _toggle(query.countries, country.code),
            ),
        ],
      _Filter.services => <_Choice>[
          any(query.providers),
          for (final service in DiscoverQuery.services)
            _Choice(
              label: service.label,
              leading: _ServiceLogo(service.label),
              mark: TvChoiceMark.check,
              selected: query.providers.contains(service.value),
              onActivate: () => _toggle(query.providers, service.value),
            ),
        ],
      _Filter.year => <_Choice>[
          for (final year in <String>['', ...DiscoverQuery.years()])
            _Choice(
              label: year.isEmpty ? tr('any') : year,
              mark: TvChoiceMark.radio,
              selected: query.year == year,
              onActivate: () => _choose((query) => query.year = year),
            ),
        ],
      _Filter.ratings => <_Choice>[
          for (final threshold in DiscoverQuery.ratingThresholds)
            _Choice(
              label: _ratingsLabel(threshold),
              mark: TvChoiceMark.radio,
              selected: query.minimumRatings == threshold,
              onActivate: () =>
                  _choose((query) => query.minimumRatings = threshold),
            ),
        ],
      _Filter.status => <_Choice>[
          for (var i = 0; i < DiscoverQuery.seriesStatuses.length; i++)
            _Choice(
              label: tr(DiscoverQuery.seriesStatuses[i].label),
              mark: TvChoiceMark.radio,
              selected: query.status == i,
              onActivate: () => _choose((query) => query.status = i),
            ),
        ],
    };
    return <_Choice>[
      // The way back, named for the filter it leaves.
      _Choice(
        label: _filterTitle(filter),
        detail: tr('player_back'),
        leading: Icon(PhosphorIcons.caretLeft()),
        onActivate: _closeFilter,
      ),
      ...options,
    ];
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final metrics = widget.metrics;
    final compact = metrics.compact;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleBack,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: TvDesign.focusOutset + 4),
              child: TvPageHeader(
                kicker: tr('browse_with_filters').toUpperCase(),
                title: tr('discover'),
                compact: compact,
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: compact ? 290 : 360,
                    child: _buildPanel(compact),
                  ),
                  SizedBox(width: compact ? 14 : 24),
                  Expanded(child: _buildResults(compact)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(bool compact) {
    final open = _open;
    final choices = open == null ? _filterChoices() : _optionChoices(open);
    // An open filter starts on its current answer.
    final initialIndex = open == null
        ? 0
        : choices
            .indexWhere(
              (choice) => choice.selected && choice.mark != TvChoiceMark.caret,
            )
            .clamp(1, choices.length - 1);
    return Padding(
      padding: const EdgeInsets.only(left: TvDesign.focusOutset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _KindSwitch(
            kind: _kind,
            movieNode: _movieTab,
            seriesNode: _seriesTab,
            compact: compact,
            onSelect: _switchKind,
            onKeyEvent: _handleKindKey,
            onFocused: () => _onKindSwitch = true,
          ),
          SizedBox(height: compact ? 10 : 14),
          Expanded(
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _handlePanelKey,
              onFocusChange: (hasFocus) {
                if (hasFocus) _onKindSwitch = false;
              },
              child: TvFocusList(
                key: open == null ? _filterList : _optionList,
                debugLabel: open == null
                    ? 'TV discover filter'
                    : 'TV discover ${open.name}',
                itemCount: choices.length,
                itemExtent: TvChoiceRow.heightFor(compact: compact),
                initialIndex: initialIndex,
                onExitUp: _focusKindSwitch,
                itemBuilder: (context, index, node) {
                  final choice = choices[index];
                  return TvChoiceRow(
                    focusNode: node,
                    compact: compact,
                    label: choice.label,
                    detail: choice.detail,
                    leading: choice.leading,
                    mark: choice.mark,
                    selected: choice.selected,
                    onActivate: choice.onActivate,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool compact) {
    final palette = TvPalette.of(context);
    final url = _url;
    final stale = _shownUrl != url;
    final count = _counts[url];
    final countLabel = count == null || stale
        ? ''
        : tr(
            'tv_discover_titles',
            namedArgs: <String, String>{
              'n': NumberFormat.decimalPattern(
                Localizations.maybeLocaleOf(context)?.toLanguageTag(),
              ).format(count),
            },
          );
    final busy = stale || _loadingMore;
    final header = SizedBox(
      height: compact ? 30 : 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TvDesign.focusOutset),
        child: Row(
          children: <Widget>[
            Text(
              tr(_kind == TvMediaKind.movie ? 'movies' : 'series'),
              style: TextStyle(
                color: palette.foreground,
                fontFamily: 'FigtreeBold',
                fontSize: compact ? 16 : 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error != null && _items.isNotEmpty
                    ? tr('tv_collection_load_more_failed')
                    : _summary(_query),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.mutedText,
                  fontFamily: 'Figtree',
                  fontSize: compact ? 14 : 16,
                ),
              ),
            ),
            // Built only while busy: a spinner keeps drawing frames even
            // when faded out.
            if (busy) ...<Widget>[
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.mutedText,
                ),
              ),
            ],
            if (countLabel.isNotEmpty) ...<Widget>[
              const SizedBox(width: 12),
              Text(
                countLabel,
                style: TextStyle(
                  color: palette.mutedText,
                  fontFamily: 'FigtreeSB',
                  fontSize: compact ? 14 : 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return Focus(
      focusNode: _resultsRegion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          Expanded(child: _buildResultsBody(stale)),
        ],
      ),
    );
  }

  Widget _buildResultsBody(bool stale) {
    final metrics = widget.metrics;
    if (_shownUrl == null || (stale && _items.isEmpty)) {
      return TvCollectionGridSkeleton(metrics: metrics);
    }
    if (_items.isEmpty) {
      final failed = _error != null;
      return _ResultsState(
        icon: failed
            ? PhosphorIcons.warningCircle()
            : PhosphorIcons.funnelSimple(),
        title: failed ? tr('something_went_wrong') : tr('no_titles_match'),
        message: failed
            ? tr('tv_check_your_connection_and_try_again')
            : tr('tv_discover_no_matches'),
        actionLabel: failed
            ? tr('retry')
            : _query.activeCount > 0
                ? tr('clear_all')
                : null,
        actionIcon: failed ? PhosphorIcons.arrowClockwise() : PhosphorIcons.x(),
        actionNode: _resultsAction,
        onAction: failed
            ? _retry
            : () {
                _change((query) => query.clear());
                _returnToPanel();
              },
      );
    }
    final scope = 'discover-${_shownUrl.hashCode}';
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      // Results for filters since changed fade until the new ones arrive.
      opacity: stale ? 0.35 : 1,
      child: TvContentGrid<TvMediaItem>(
        // A new grid for new results: it starts at the top.
        key: ValueKey<String>(scope),
        scopeId: scope,
        controller: _grid,
        items: _items,
        itemId: (item) => item.stableId,
        semanticLabel: (item) => item.title,
        targetItemWidth: metrics.mediaCardWidth,
        itemAspectRatio: TvMediaCard.artworkAspectRatio,
        itemDetailsExtent: TvMediaCard.detailsHeight,
        itemBuilder: (_, item, width) => TvMediaCard(
          item: item,
          width: width,
          badge: TvMediaBadge.recencyOf(item),
        ),
        onItemActivated: widget.onOpenMedia,
        onItemFocused: _handleItemFocused,
      ),
    );
  }
}

/// Movies or series, as two tabs over the filters. OK switches.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({
    required this.kind,
    required this.movieNode,
    required this.seriesNode,
    required this.compact,
    required this.onSelect,
    required this.onKeyEvent,
    required this.onFocused,
  });

  final TvMediaKind kind;
  final FocusNode movieNode;
  final FocusNode seriesNode;
  final bool compact;
  final ValueChanged<TvMediaKind> onSelect;
  final KeyEventResult Function(TvMediaKind tab, KeyEvent event) onKeyEvent;
  final VoidCallback onFocused;

  @override
  Widget build(BuildContext context) {
    Widget tab(TvMediaKind tab, String label, IconData icon, FocusNode node) =>
        Expanded(
          child: _KindTab(
            label: label,
            icon: icon,
            focusNode: node,
            compact: compact,
            selected: kind == tab,
            onActivate: () => onSelect(tab),
            onKeyEvent: (event) => onKeyEvent(tab, event),
            onFocused: onFocused,
          ),
        );
    return Row(
      children: <Widget>[
        tab(
          TvMediaKind.movie,
          tr('movies'),
          PhosphorIcons.filmSlate(),
          movieNode,
        ),
        const SizedBox(width: 8),
        tab(
          TvMediaKind.series,
          tr('series'),
          PhosphorIcons.television(),
          seriesNode,
        ),
      ],
    );
  }
}

class _KindTab extends StatefulWidget {
  const _KindTab({
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.compact,
    required this.selected,
    required this.onActivate,
    required this.onKeyEvent,
    required this.onFocused,
  });

  final String label;
  final IconData icon;
  final FocusNode focusNode;
  final bool compact;
  final bool selected;
  final VoidCallback onActivate;
  final KeyEventResult Function(KeyEvent event) onKeyEvent;
  final VoidCallback onFocused;

  @override
  State<_KindTab> createState() => _KindTabState();
}

class _KindTabState extends State<_KindTab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    return TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: widget.label,
      selected: widget.selected,
      onActivate: widget.onActivate,
      onKeyEvent: (_, event) => widget.onKeyEvent(event),
      onFocusChanged: (hasFocus) {
        if (hasFocus) widget.onFocused();
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      scrollAlignment: null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: widget.compact ? 42 : 48,
        decoration: BoxDecoration(
          color: _focused
              ? palette.focusFill
              : widget.selected
                  ? palette.idleFillStrong
                  : palette.idleFillFaint,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(widget.icon, color: foreground, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontFamily: widget.selected ? 'FigtreeBold' : 'FigtreeSB',
                  fontSize: widget.compact ? 15 : 17,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the results area says when it has no titles to show, with the one
/// thing to do about it.
class _ResultsState extends StatelessWidget {
  const _ResultsState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionNode,
    required this.actionIcon,
    required this.onAction,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData actionIcon;
  final FocusNode actionNode;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final actionLabel = this.actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TvDesign.focusOutset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: palette.mutedText, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.foreground,
                fontFamily: 'FigtreeBold',
                fontSize: 26,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.mutedText,
                fontSize: 17,
                height: 1.35,
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 20),
              TvPillButton(
                focusNode: actionNode,
                label: actionLabel,
                icon: actionIcon,
                prominent: true,
                scrollAlignment: null,
                onActivate: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final flag = DiscoverQuery.flag(code);
    if (flag == null) return Icon(PhosphorIcons.globeHemisphereWest());
    return Text(flag, style: const TextStyle(fontSize: 22, height: 1.1));
  }
}

/// A service's logo on the light plate its tile uses, or its initial.
class _ServiceLogo extends StatelessWidget {
  const _ServiceLogo(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final logo = appStreamingServices
        .where((service) => service.name == name)
        .firstOrNull
        ?.imagePath;
    return Container(
      width: 28,
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: TvPalette.logoPlate,
        borderRadius: BorderRadius.circular(3),
      ),
      child: logo == null
          ? Center(
              child: Text(
                name.characters.first,
                style: const TextStyle(
                  color: Color(0xFF141516),
                  fontFamily: 'FigtreeBold',
                  fontSize: 11,
                  height: 1,
                ),
              ),
            )
          : Image.asset(logo, fit: BoxFit.contain),
    );
  }
}
