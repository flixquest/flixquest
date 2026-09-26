import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../singleton/sharedpreferences_singleton.dart';
import '../app/tv_design.dart';
import '../controllers/tv_catalog_controller.dart';
import '../controllers/tv_search_history_controller.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_state_panel.dart';

class TvSearchScreen extends StatefulWidget {
  const TvSearchScreen({
    required this.metrics,
    required this.onOpenMedia,
    this.focusController,
    super.key,
  });

  final TvShellMetrics metrics;
  final ValueChanged<TvMediaItem> onOpenMedia;
  final TvScreenFocusController? focusController;

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  static const _controller = TvCatalogController();
  final TextEditingController _queryController = TextEditingController();
  late final FocusNode _queryFocusNode;
  final FocusNode _searchActionFocusNode =
      FocusNode(debugLabel: 'TV search action');
  Future<List<TvMediaItem>>? _results;
  String _submittedQuery = '';
  bool _queryHasFocus = false;
  bool _historyIsLoading = true;
  List<String> _recentSearches = const <String>[];
  TvSearchHistoryController? _historyController;
  TvMediaKind _selectedKind = TvMediaKind.movie;

  @override
  void initState() {
    super.initState();
    _queryFocusNode = FocusNode(
      debugLabel: 'TV search query',
      onKeyEvent: _handleQueryKeyEvent,
    );
    _queryFocusNode.addListener(_handleQueryFocus);
    widget.focusController?.attach(this, _requestEntryFocus);
    unawaited(_loadSearchHistory());
  }

  @override
  void didUpdateWidget(TvSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestEntryFocus);
    }
  }

  KeyEventResult _handleQueryKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _searchActionFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    final direction = switch (key) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    return node.focusInDirection(direction)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _requestEntryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _queryFocusNode.context == null ||
          !_queryFocusNode.canRequestFocus) {
        return;
      }
      _queryFocusNode.requestFocus();
    });
  }

  void _requestSearchActionFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _searchActionFocusNode.context == null ||
          !_searchActionFocusNode.canRequestFocus) {
        return;
      }
      _searchActionFocusNode.requestFocus();
    });
  }

  Future<void> _loadSearchHistory() async {
    final preferences = await SharedPreferencesSingleton.getInstance();
    if (!mounted) return;
    final controller = TvSearchHistoryController(preferences);
    setState(() {
      _historyController = controller;
      _recentSearches = controller.load();
      _historyIsLoading = false;
    });
  }

  void _handleQueryFocus() {
    if (_queryHasFocus != _queryFocusNode.hasFocus) {
      setState(() => _queryHasFocus = _queryFocusNode.hasFocus);
    }
  }

  void _submit([String? savedQuery]) {
    final query = TvSearchHistoryController.normalize(
      savedQuery ?? _queryController.text,
    );
    if (query.isEmpty) {
      _queryFocusNode.requestFocus();
      return;
    }
    _queryController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    FocusScope.of(context).unfocus();
    unawaited(_rememberSearch(query));
    final results = _controller.search(
      query: query,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    );
    setState(() {
      _submittedQuery = query;
      _selectedKind = TvMediaKind.movie;
      _results = results.then((items) {
        final hasMovies = items.any((item) => item.kind == TvMediaKind.movie);
        final hasSeries = items.any((item) => item.kind == TvMediaKind.series);
        if (mounted && !hasMovies && hasSeries) {
          setState(() => _selectedKind = TvMediaKind.series);
        }
        return items;
      });
    });
    _requestSearchActionFocus();
  }

  Future<void> _rememberSearch(String query) async {
    var controller = _historyController;
    if (controller == null) {
      final preferences = await SharedPreferencesSingleton.getInstance();
      controller = TvSearchHistoryController(preferences);
    }
    final updated = await controller.remember(query);
    if (!mounted) return;
    setState(() {
      _historyController = controller;
      _recentSearches = updated;
      _historyIsLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    var controller = _historyController;
    if (controller == null) {
      final preferences = await SharedPreferencesSingleton.getInstance();
      controller = TvSearchHistoryController(preferences);
    }
    await controller.clear();
    if (!mounted) return;
    setState(() {
      _historyController = controller;
      _recentSearches = const <String>[];
      _historyIsLoading = false;
    });
    _requestSearchActionFocus();
  }

  Future<void> _removeHistoryEntry(String query) async {
    var controller = _historyController;
    if (controller == null) {
      final preferences = await SharedPreferencesSingleton.getInstance();
      controller = TvSearchHistoryController(preferences);
    }
    final updated = await controller.remove(query);
    if (!mounted) return;
    setState(() {
      _historyController = controller;
      _recentSearches = updated;
      _historyIsLoading = false;
    });
    _requestSearchActionFocus();
  }

  void _showRecentSearches() {
    setState(() {
      _results = null;
      _submittedQuery = '';
    });
    _requestSearchActionFocus();
  }

  @override
  void dispose() {
    widget.focusController?.detach(this);
    _queryFocusNode
      ..removeListener(_handleQueryFocus)
      ..dispose();
    _queryController.dispose();
    _searchActionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.metrics.contentPadding,
        0,
        widget.metrics.contentPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Search',
              style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: 'FigtreeBold',
                  fontSize: 28,
                  letterSpacing: -0.4)),
          const SizedBox(height: 10),
          FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 62,
                    decoration: BoxDecoration(
                      color: _queryHasFocus
                          ? TvDesign.surfaceFor(context, emphasis: 0.045)
                          : TvDesign.surfaceFor(context, emphasis: 0.012),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _queryHasFocus
                            ? Colors.white
                            : colors.onSurface.withValues(alpha: 0.1),
                        width: _queryHasFocus ? 3 : 1,
                      ),
                      boxShadow: _queryHasFocus
                          ? <BoxShadow>[
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.38),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: _queryController,
                      focusNode: _queryFocusNode,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.text,
                      onSubmitted: (_) => _submit(),
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 20,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          PhosphorIcons.keyboard(),
                          color: _queryHasFocus
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          size: 23,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 18,
                        ),
                        hintText: 'Type a movie or series title',
                        hintStyle: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                _SearchActionButton(
                  focusNode: _searchActionFocusNode,
                  label: 'Search',
                  semanticLabel: 'Search FlixQuest',
                  icon: PhosphorIcons.magnifyingGlass(),
                  onActivate: _submit,
                  primary: true,
                ),
                if (_results != null) ...<Widget>[
                  const SizedBox(width: 14),
                  _SearchActionButton(
                    label:
                        widget.metrics.compact ? 'Recent' : 'Recent searches',
                    semanticLabel: 'Show recent searches',
                    icon: PhosphorIcons.clockCounterClockwise(),
                    onActivate: _showRecentSearches,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: widget.metrics.compact ? 10 : 18),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final future = _results;
    if (future == null) {
      return _buildSearchLanding();
    }
    return FutureBuilder<List<TvMediaItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return TvStatePanel.error(onRetry: _submit);
        }
        final items = snapshot.data ?? const <TvMediaItem>[];
        if (items.isEmpty) {
          return TvStatePanel(
            title: 'No matches',
            message: 'No movies or series matched “$_submittedQuery”.',
            icon: PhosphorIcons.magnifyingGlass(),
          );
        }
        final movies = items
            .where((item) => item.kind == TvMediaKind.movie)
            .toList(growable: false);
        final series = items
            .where((item) => item.kind == TvMediaKind.series)
            .toList(growable: false);
        final selectedItems =
            _selectedKind == TvMediaKind.movie ? movies : series;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Row(
                children: <Widget>[
                  _SearchResultTab(
                    label: 'Movies',
                    count: movies.length,
                    icon: PhosphorIcons.filmSlate(),
                    selected: _selectedKind == TvMediaKind.movie,
                    onActivate: () =>
                        setState(() => _selectedKind = TvMediaKind.movie),
                  ),
                  const SizedBox(width: 14),
                  _SearchResultTab(
                    label: 'TV Series',
                    count: series.length,
                    icon: PhosphorIcons.television(),
                    selected: _selectedKind == TvMediaKind.series,
                    onActivate: () =>
                        setState(() => _selectedKind = TvMediaKind.series),
                  ),
                ],
              ),
            ),
            SizedBox(height: widget.metrics.compact ? 8 : 14),
            Expanded(
              child: selectedItems.isEmpty
                  ? TvStatePanel(
                      title: _selectedKind == TvMediaKind.movie
                          ? 'No movie matches'
                          : 'No TV series matches',
                      message:
                          'Try another title or choose the other results tab.',
                      icon: _selectedKind == TvMediaKind.movie
                          ? PhosphorIcons.filmSlate()
                          : PhosphorIcons.television(),
                    )
                  : TvContentGrid<TvMediaItem>(
                      scopeId: 'search:$_submittedQuery:${_selectedKind.name}',
                      items: selectedItems,
                      itemId: (item) => item.stableId,
                      semanticLabel: (item) => item.title,
                      targetItemWidth: widget.metrics.mediaCardWidth,
                      itemAspectRatio: TvMediaCard.artworkAspectRatio,
                      itemDetailsExtent: TvMediaCard.detailsHeight,
                      autofocus: true,
                      itemBuilder: (_, item, width) =>
                          TvMediaCard(item: item, width: width),
                      onItemActivated: widget.onOpenMedia,
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchLanding() {
    final colors = Theme.of(context).colorScheme;
    if (_historyIsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recentSearches.isEmpty) {
      return TvStatePanel(
        title: 'Find something to watch',
        message:
            'Select the search field to open the TV keyboard. Your searches will be saved here for next time.',
        icon: PhosphorIcons.keyboard(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TvDesign.focusOutset,
        TvDesign.focusOutset,
        TvDesign.focusOutset,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                PhosphorIcons.clockCounterClockwise(),
                color: colors.primary,
                size: 25,
              ),
              const SizedBox(width: 10),
              Text(
                'Recent searches',
                style: TextStyle(
                  color: colors.onSurface,
                  fontFamily: 'FigtreeSB',
                  fontSize: 25,
                ),
              ),
              const Spacer(),
              TvFocusable(
                semanticLabel: 'Clear all recent searches',
                onActivate: _clearHistory,
                focusScale: 1.02,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        PhosphorIcons.trash(),
                        color: colors.onSurfaceVariant,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clear all',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontFamily: 'FigtreeSB',
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a title to search again without using the keyboard.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 20),
          FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                for (var index = 0; index < _recentSearches.length; index++)
                  _RecentSearchTile(
                    query: _recentSearches[index],
                    isMostRecent: index == 0,
                    onActivate: () => _submit(_recentSearches[index]),
                    onRemove: () => unawaited(
                      _removeHistoryEntry(_recentSearches[index]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onActivate,
    this.focusNode,
    this.primary = false,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = primary ? colors.onPrimary : colors.onSurface;
    return TvFocusable(
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      onActivate: onActivate,
      focusScale: 1.025,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 23),
        decoration: BoxDecoration(
          color: primary ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(13),
          border: primary
              ? null
              : Border.all(color: colors.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: foreground, size: 22),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontFamily: 'FigtreeSB',
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  const _RecentSearchTile({
    required this.query,
    required this.isMostRecent,
    required this.onActivate,
    required this.onRemove,
  });

  final String query;
  final bool isMostRecent;
  final VoidCallback onActivate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TvFocusable(
          semanticLabel: 'Search again for $query',
          onActivate: onActivate,
          autofocus: isMostRecent,
          focusScale: 1.025,
          child: Container(
            constraints: const BoxConstraints(minWidth: 190, maxWidth: 330),
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: isMostRecent
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isMostRecent
                    ? colors.primary.withValues(alpha: 0.32)
                    : colors.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  PhosphorIcons.magnifyingGlass(),
                  color:
                      isMostRecent ? colors.primary : colors.onSurfaceVariant,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Flexible(
                  child: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontFamily: 'FigtreeSB',
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Icon(
                  PhosphorIcons.arrowUpRight(),
                  color: colors.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        TvFocusable(
          semanticLabel: 'Remove $query from recent searches',
          onActivate: onRemove,
          focusScale: 1.04,
          child: Container(
            width: 54,
            height: 64,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              PhosphorIcons.x(),
              color: colors.onSurfaceVariant,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultTab extends StatelessWidget {
  const _SearchResultTab({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onActivate,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TvFocusable(
      semanticLabel: '$label, $count results',
      onActivate: onActivate,
      selected: selected,
      focusScale: 1.02,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: selected ? colors.primary : colors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontFamily: selected ? 'FigtreeSB' : 'Figtree',
                fontSize: 17,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              '$count',
              style: TextStyle(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontFamily: 'FigtreeSB',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
