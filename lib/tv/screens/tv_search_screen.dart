import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/genres.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../singleton/sharedpreferences_singleton.dart';
import '../app/tv_design.dart';
import '../app/tv_shell_layout.dart';
import '../controllers/tv_catalog_controller.dart';
import '../controllers/tv_search_history_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_browse_skeleton.dart';
import '../widgets/tv_browse_view.dart';
import '../widgets/tv_search_keyboard.dart';
import '../widgets/tv_shortcut_tile.dart';
import '../widgets/tv_state_panel.dart';

/// Search the Netflix way: a keyboard on the left, and on the right the
/// browse page's spotlight and rows, following focus.
///
/// Before anything is typed the rows suggest: recent searches, today's top
/// titles and the genres. Typing searches as it goes, once the keys pause.
/// Right off the keyboard enters the rows; Left off the rows or Back returns
/// to the keyboard.
class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({
    required this.metrics,
    required this.onOpenMedia,
    this.onOpenCollection,
    this.focusController,
    this.controller = const TvCatalogController(),
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final ValueChanged<TvCollection>? onOpenCollection;
  final TvScreenFocusController? focusController;
  final TvCatalogController controller;

  /// How long typing must pause before the query is searched.
  static const typingPause = Duration(milliseconds: 450);

  /// Shorter queries match too much to be worth a search.
  static const minimumQuery = 2;

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  static final _backKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };

  final GlobalKey<TvSearchKeyboardState> _keyboard =
      GlobalKey<TvSearchKeyboardState>();
  final TvScreenFocusController _results = TvScreenFocusController();

  String _query = '';
  Timer? _typingTimer;
  int _generation = 0;

  /// The query the rows show results for, and those results; kept while the
  /// next query runs, so the rows do not blank out between keys.
  String? _resultsQuery;
  List<TvMediaItem>? _resultItems;
  bool _searching = false;
  bool _searchFailed = false;

  Future<TvSearchSuggestions>? _suggestions;
  String? _configurationKey;
  TvSearchHistoryController? _history;
  List<String> _recent = const <String>[];

  TvCatalogController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _focusKeyboard);
    unawaited(_loadHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${settings.appLanguage}|${settings.enableProxy}|'
        '${dependencies.tmdbProxy}';
    if (_configurationKey == key) return;
    _configurationKey = key;
    _suggestions = _controller
        .loadSearchSuggestions(settings: settings, dependencies: dependencies)
        .then((value) => value,
            onError: (Object _) => TvSearchSuggestions.empty);
    if (_resultsQuery != null) _search(_query);
  }

  @override
  void didUpdateWidget(TvSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _focusKeyboard);
    }
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _typingTimer?.cancel();
    super.dispose();
  }

  bool _focusKeyboard() => _keyboard.currentState?.requestFocus() ?? false;

  bool _focusResults() => _results.isAttached && _results.requestFocus();

  Future<void> _loadHistory() async {
    final preferences = await SharedPreferencesSingleton.getInstance();
    if (!mounted) return;
    final history = TvSearchHistoryController(preferences);
    setState(() {
      _history = history;
      _recent = history.load();
    });
  }

  // Typing.

  void _setQuery(String query, {bool immediately = false}) {
    if (query == _query) return;
    setState(() => _query = query);
    _typingTimer?.cancel();
    final normalized = TvSearchHistoryController.normalize(query);
    if (normalized.length < TvSearchScreen.minimumQuery) {
      // Back to the suggestions.
      _generation++;
      setState(() {
        _resultsQuery = null;
        _resultItems = null;
        _searching = false;
        _searchFailed = false;
      });
      _recoverFocus();
      return;
    }
    if (immediately) {
      _search(normalized);
    } else {
      _typingTimer = Timer(TvSearchScreen.typingPause, () {
        if (mounted) _search(normalized);
      });
    }
  }

  void _type(String character) {
    // A leading or doubled space is never what was meant.
    if (character == ' ' && (_query.isEmpty || _query.endsWith(' '))) return;
    _setQuery('$_query$character');
  }

  void _delete() {
    if (_query.isEmpty) return;
    _setQuery(_query.substring(0, _query.length - 1));
  }

  void _clear() => _setQuery('');

  void _search(String query) {
    final generation = ++_generation;
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    _controller
        .search(
      query: query,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    )
        .then((items) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _resultsQuery = query;
        _resultItems = items;
        _searching = false;
      });
      _recoverFocus();
    }, onError: (Object _) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searching = false;
        _searchFailed = true;
      });
    });
  }

  /// Activating a recent search swaps the suggestions for results under the
  /// remote; land it in the results rather than nowhere.
  void _recoverFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null && focused is! FocusScopeNode) return;
      if (!_focusResults()) _focusKeyboard();
    });
  }

  // History.

  Future<void> _remember(String query) async {
    final history = _history;
    if (history == null) return;
    final updated = await history.remember(query);
    if (mounted) setState(() => _recent = updated);
  }

  Future<void> _forget(String query) async {
    final history = _history;
    if (history == null) return;
    final updated = await history.remove(query);
    if (mounted) setState(() => _recent = updated);
  }

  void _openResult(TvMediaItem item) {
    final query = _resultsQuery;
    if (query != null) unawaited(_remember(query));
    widget.onOpenMedia(item);
  }

  void _openGenre(TvMediaKind kind, Genres genre) {
    widget.onOpenCollection?.call(_controller.genreCollection(
      kind: kind,
      genre: genre,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    ));
  }

  // Focus between the keyboard and the rows.

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final onKeyboard = _keyboard.currentState?.hasFocus ?? false;
    if (onKeyboard) return KeyEventResult.ignored;
    // This handler sits above the rows, so it sees Left before the row's
    // own traversal does: let the row step back a card first, and only
    // return to the keyboard once there is no card further left.
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final focused = FocusManager.instance.primaryFocus;
      if (focused != null &&
          focused.focusInDirection(TraversalDirection.left)) {
        return KeyEventResult.handled;
      }
      return _focusKeyboard() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    // Back returns to the keyboard from anywhere in the results.
    if (_backKeys.contains(event.logicalKey)) {
      return _focusKeyboard() ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final compact = metrics.compact;
    final insets = TvShellInsets.of(context);
    final keyboardWidth = compact ? 246.0 : 300.0;
    final resultsInsets = insets.copyWith(
      left: insets.left + TvDesign.focusOutset + keyboardWidth + 28,
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          TvShellInsets(insets: resultsInsets, child: _buildResults()),
          Positioned(
            left: insets.left + TvDesign.focusOutset,
            top: insets.top + metrics.contentPadding,
            width: keyboardWidth,
            bottom: insets.bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _QueryField(
                  query: _query,
                  searching: _searching,
                  compact: compact,
                ),
                SizedBox(height: compact ? 14 : 20),
                TvSearchKeyboard(
                  key: _keyboard,
                  width: keyboardWidth,
                  onType: _type,
                  onDelete: _delete,
                  onClear: _clear,
                  onExitRight: _focusResults,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final items = _resultItems;
    final query = _resultsQuery;
    if (_searchFailed && items == null) {
      return _panel(TvStatePanel.error(onRetry: () => _search(_query.trim())));
    }
    if (query != null && items != null) {
      if (items.isEmpty) {
        return _panel(TvStatePanel(
          title: 'No matches',
          message: 'Nothing matched “$query”. Try another title.',
          icon: PhosphorIcons.magnifyingGlass(),
        ));
      }
      return _buildResultRows(query, items);
    }
    return FutureBuilder<TvSearchSuggestions>(
      future: _suggestions,
      builder: (context, snapshot) {
        final suggestions = snapshot.data;
        if (suggestions == null) {
          return TvBrowseSkeleton(metrics: widget.metrics);
        }
        return _buildSuggestionRows(suggestions);
      },
    );
  }

  Widget _panel(Widget child) => Builder(
        builder: (context) => Padding(
          padding: TvShellInsets.of(context),
          child: child,
        ),
      );

  Widget _buildResultRows(String query, List<TvMediaItem> items) {
    final movies = items
        .where((item) => item.kind == TvMediaKind.movie)
        .toList(growable: false);
    final series = items
        .where((item) => item.kind == TvMediaKind.series)
        .toList(growable: false);
    // The row with the stronger first match leads.
    final seriesFirst = movies.isEmpty ||
        (series.isNotEmpty &&
            items.indexOf(series.first) < items.indexOf(movies.first));
    final rows = <TvBrowseRow>[
      TvMediaRow(
        title: 'Movies',
        scopeId: 'search-movies:$query',
        items: movies,
        onItemActivated: _openResult,
      ),
      TvMediaRow(
        title: 'Series',
        scopeId: 'search-series:$query',
        items: series,
        onItemActivated: _openResult,
      ),
    ];
    return TvBrowseView(
      key: const ValueKey<String>('search-results'),
      featured: seriesFirst ? series.first : movies.first,
      rows: seriesFirst ? rows.reversed.toList() : rows,
      metrics: widget.metrics,
      onOpenMedia: _openResult,
      focusController: _results,
      focusMemoryScope: 'tv-search-row',
      showBillboard: false,
    );
  }

  Widget _buildSuggestionRows(TvSearchSuggestions suggestions) {
    final featured = suggestions.topSearches.firstOrNull;
    if (featured == null && _recent.isEmpty) {
      return _panel(TvStatePanel(
        title: 'Find something to watch',
        message: 'Type a movie or series title with the keyboard.',
        icon: PhosphorIcons.magnifyingGlass(),
      ));
    }
    List<TvBrowseShortcut> genres(TvMediaKind kind, List<Genres> list) =>
        <TvBrowseShortcut>[
          for (final genre in list)
            TvBrowseShortcut(
              id: '${kind.name}-genre-${genre.genreID}',
              title: genre.genreName!,
              facts: <String>[
                kind == TvMediaKind.movie ? 'Movie genre' : 'Series genre',
              ],
              description: 'The most watched '
                  '${genre.genreName!.toLowerCase()} '
                  '${kind == TvMediaKind.movie ? 'movies' : 'series'}.',
              onActivate: () => _openGenre(kind, genre),
            ),
        ];

    return TvBrowseView(
      key: const ValueKey<String>('search-suggestions'),
      // Recent searches alone still need a title behind them.
      featured: featured ??
          const TvMediaItem(
            kind: TvMediaKind.movie,
            id: -1,
            title: 'Search',
            overview: '',
            posterPath: null,
            backdropPath: null,
            rating: null,
            releaseDate: null,
          ),
      metrics: widget.metrics,
      onOpenMedia: widget.onOpenMedia,
      focusController: _results,
      focusMemoryScope: 'tv-search-suggestions-row',
      showBillboard: false,
      rows: <TvBrowseRow>[
        TvShortcutRow(
          title: 'Recent searches',
          scopeId: 'search-recent',
          menuHint: 'Hold OK to remove',
          onShortcutMenu: (shortcut) => _forget(shortcut.title),
          shortcuts: <TvBrowseShortcut>[
            for (final query in _recent)
              TvBrowseShortcut(
                id: 'recent:$query',
                title: query,
                icon: PhosphorIcons.clockCounterClockwise(),
                facts: const <String>['Recent search'],
                description: 'Search for “$query” again.',
                onActivate: () => _setQuery(query, immediately: true),
              ),
          ],
        ),
        TvTopTenRow(
          title: 'Top searches today',
          scopeId: 'search-top',
          items: suggestions.topSearches,
        ),
        TvShortcutRow(
          title: 'Movie genres',
          scopeId: 'search-movie-genres',
          shortcuts: genres(TvMediaKind.movie, suggestions.movieGenres),
        ),
        TvShortcutRow(
          title: 'Series genres',
          scopeId: 'search-series-genres',
          shortcuts: genres(TvMediaKind.series, suggestions.seriesGenres),
        ),
      ],
    );
  }
}

/// What has been typed, with a cursor, above the keyboard.
class _QueryField extends StatelessWidget {
  const _QueryField({
    required this.query,
    required this.searching,
    required this.compact,
  });

  final String query;
  final bool searching;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final empty = query.isEmpty;
    return Semantics(
      label: empty ? 'Search, nothing typed' : 'Search for $query',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: palette.foreground.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              PhosphorIcons.magnifyingGlass(),
              color: palette.mutedText,
              size: compact ? 20 : 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: <Widget>[
                  Flexible(
                    // Scrolled to its end, so a long query shows what was
                    // typed last, where the cursor is.
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Text(
                        empty ? 'Movies and series' : query,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: empty ? palette.mutedText : palette.foreground,
                          fontFamily: empty ? 'Figtree' : 'FigtreeSB',
                          fontSize: compact ? 20 : 24,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  if (!empty)
                    Container(
                      width: 2,
                      height: compact ? 22 : 26,
                      margin: const EdgeInsets.only(left: 2),
                      color: palette.foreground,
                    ),
                ],
              ),
            ),
            // Built only while searching: a spinner keeps animating, and
            // drawing frames, even when faded out.
            if (searching)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.mutedText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
