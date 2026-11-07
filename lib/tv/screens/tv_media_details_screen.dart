import 'package:flixquest/services/video_launcher.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/title_people.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../design/outline_mark.dart';
import '../../functions/function.dart';
import '../../models/credits.dart';
import '../../widgets/playback_action.dart';
import '../../models/tv.dart';
import '../../models/videos.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/playlist_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../app/tv_design.dart';
import '../controllers/tv_media_details_controller.dart';
import '../controllers/tv_title_logos.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_content_row.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_playlist_picker.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_person_card.dart';
import '../widgets/tv_spotlight.dart';
import 'tv_person_screen.dart';

class TvMediaDetailsScreen extends StatefulWidget {
  const TvMediaDetailsScreen({
    required this.item,
    this.controller = const TvMediaDetailsController(),
    super.key,
  });

  final TvMediaItem item;
  final TvMediaDetailsController controller;

  @override
  State<TvMediaDetailsScreen> createState() => _TvMediaDetailsScreenState();
}

/// The rows of controls Down and Up move between.
enum _Stop { actions, seasons, episodes, cast, videos, similar }

class _TvMediaDetailsScreenState extends State<TvMediaDetailsScreen> {
  TvMediaDetailsController get _controller => widget.controller;
  static const _motion = Duration(milliseconds: 260);

  /// A season's episodes load once it has kept focus this long, so sweeping
  /// across the seasons does not fetch each one.
  static const _seasonSettle = Duration(milliseconds: 300);

  static final _backKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };

  Future<TvMediaDetailsData>? _details;
  TvMediaDetailsData? _loaded;
  Future<bool>? _bookmarked;
  bool _bookmarkBusy = false;
  String? _configurationKey;

  int? _selectedSeason;
  final Map<int, Future<List<EpisodeList>>> _seasons =
      <int, Future<List<EpisodeList>>>{};
  final Set<int> _loadedSeasons = <int>{};
  Timer? _seasonTimer;

  final Map<String, FocusNode> _actionNodes = <String, FocusNode>{};
  String? _lastActionId;
  final TvContentRowController _seasonRow = TvContentRowController();
  final Map<int, TvContentRowController> _episodeRows =
      <int, TvContentRowController>{};
  final TvContentGridController _similarGrid = TvContentGridController();

  /// The title's YouTube videos, loaded apart from the details so a slow or
  /// failed answer holds up nothing else. Null until the first answer.
  List<Results>? _videos;
  bool _videosFailed = false;
  int _videosRequest = 0;
  final TvContentRowController _videoRow = TvContentRowController();
  final FocusNode _videosRetry =
      FocusNode(debugLabel: 'TV details videos retry');

  /// The title's cast and crew, loaded apart like the videos. Null until
  /// they come; a failure leaves the row out, as having nobody listed does.
  Credits? _credits;
  int _creditsRequest = 0;
  final TvContentRowController _castRow = TvContentRowController();

  /// Where each row was left, for this page only.
  final TvFocusMemory _memory = TvFocusMemory();

  _Stop _stop = _Stop.actions;
  final GlobalKey _columnKey = GlobalKey();
  final GlobalKey _episodesKey = GlobalKey();
  final GlobalKey _castKey = GlobalKey();
  final GlobalKey _videosKey = GlobalKey();
  final GlobalKey _similarKey = GlobalKey();

  /// How far the page is slid up, so the focused section sits at the top, or
  /// in the recommendations far enough to show the focused card's row.
  double _shift = 0;

  TvMediaItem get _item => widget.item;
  bool get _isMovie => _item.kind == TvMediaKind.movie;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${settings.appLanguage}|${settings.enableProxy}|'
        '${dependencies.tmdbProxy}|${_item.stableId}';
    if (_configurationKey != key) {
      _configurationKey = key;
      _seasons.clear();
      _loadedSeasons.clear();
      _load();
      _videos = null;
      _videosFailed = false;
      _loadVideos();
      _credits = null;
      _loadCredits();
      _bookmarked = _controller.isBookmarked(_item);
    }
  }

  void _load() {
    final details = _controller.load(
      item: _item,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    );
    _details = details;
    details.then((data) {
      if (!mounted || !identical(_details, details)) return;
      setState(() => _loaded = data);
      final season = initialSeasonNumber(data.seasons, _resume());
      if (season != null) _selectSeason(season, immediately: true);
    }, onError: (Object _) {});
  }

  void _retry() => setState(_load);

  /// A Retry stays on screen until the answer, so it keeps focus meanwhile.
  void _loadVideos() {
    final request = ++_videosRequest;
    _controller
        .loadVideos(
      item: _item,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    )
        .then((videos) {
      if (!mounted || request != _videosRequest) return;
      final retried = _videosRetry.hasFocus;
      setState(() {
        _videos = videos;
        _videosFailed = false;
      });
      _settleAfterVideos(retried: retried);
    }, onError: (Object error) {
      debugPrint('[TvMediaDetails] videos unavailable: $error');
      if (!mounted || request != _videosRequest) return;
      setState(() => _videosFailed = true);
      _settleAfterVideos();
    });
  }

  void _loadCredits() {
    final request = ++_creditsRequest;
    _controller
        .loadCredits(
      item: _item,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    )
        .then((credits) {
      if (!mounted || request != _creditsRequest) return;
      setState(() => _credits = credits);
      // The row moves those below it; follow the focused one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _stop != _Stop.actions) _scheduleShift();
      });
    }, onError: (Object error) {
      debugPrint('[TvMediaDetails] credits unavailable: $error');
    });
  }

  /// The videos arriving move the rows below them, and a Retry that worked
  /// ([retried]) goes, taking its focus: once they are laid out, focus moves
  /// on to the videos, or what follows when there were none.
  void _settleAfterVideos({bool retried = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (retried && !_focusStop(_Stop.videos) && !_focusStop(_Stop.similar)) {
        _focusStop(_Stop.actions);
      }
      if (_stop != _Stop.actions) _scheduleShift();
    });
  }

  @override
  void dispose() {
    _seasonTimer?.cancel();
    for (final node in _actionNodes.values) {
      node.dispose();
    }
    _videosRetry.dispose();
    super.dispose();
  }

  TvResumePoint? _resume({bool listen = false}) {
    final recent = listen
        ? context.watch<RecentProvider?>()
        : context.read<RecentProvider?>();
    if (recent == null) return null;
    return TvResumePoint.forItem(
      _item,
      movies: recent.movies,
      episodes: recent.episodes,
    );
  }

  Future<List<EpisodeList>> _episodesOf(int season) {
    final known = _seasons[season];
    if (known != null) return known;
    late final Future<List<EpisodeList>> episodes;
    episodes = _controller
        .loadSeason(
      seriesId: _item.id,
      seasonNumber: season,
      settings: context.read<SettingsProvider>(),
      dependencies: context.read<AppDependencyProvider>(),
    )
        .then((episodes) {
      _loadedSeasons.add(season);
      return episodes;
    }, onError: (Object error) {
      // Forgotten, so the season can be tried again.
      if (identical(_seasons[season], episodes)) _seasons.remove(season);
      throw error;
    });
    // A season swept past before it loaded has no one left to report a
    // failure to; whoever is still watching it sees the error regardless.
    episodes.ignore();
    return _seasons[season] = episodes;
  }

  void _selectSeason(int season, {bool immediately = false}) {
    _seasonTimer?.cancel();
    if (_selectedSeason != season) setState(() => _selectedSeason = season);
    if (_seasons.containsKey(season) || immediately) {
      setState(() {
        _episodesOf(season);
      });
      return;
    }
    _seasonTimer = Timer(_seasonSettle, () {
      if (mounted && _selectedSeason == season) {
        setState(() {
          _episodesOf(season);
        });
      }
    });
  }

  // Focus between the page's rows.

  FocusNode _actionNode(String id) => _actionNodes.putIfAbsent(
      id, () => FocusNode(debugLabel: 'TV details $id'));

  bool _focusStop(_Stop stop) {
    switch (stop) {
      case _Stop.actions:
        final node = _actionNodes[_lastActionId] ??
            _actionNodes.values
                .where((node) => node.context != null)
                .firstOrNull;
        if (node == null || node.context == null) return false;
        node.requestFocus();
        return true;
      case _Stop.seasons:
        return _seasonRow.requestFocus('${_selectedSeason ?? ''}');
      case _Stop.episodes:
        final season = _selectedSeason;
        if (season == null) return false;
        // Where the row was left, else the episode being watched.
        final resume = _resume()?.episode;
        final itemId = _memory.recall(_episodesScope(season)) ??
            (resume?.seasonNum == season ? '${resume?.episodeNum}' : null);
        return _episodeRows[season]?.requestFocus(itemId) ?? false;
      case _Stop.cast:
        // Nobody listed, or not loaded yet: no stop.
        if (_castKey.currentContext == null) return false;
        return _castRow.requestFocus();
      case _Stop.videos:
        // No stop at all while they load, or when there are none.
        if (_videosKey.currentContext == null) return false;
        if (_videosFailed) {
          _videosRetry.requestFocus();
          return true;
        }
        return _videoRow.requestFocus();
      case _Stop.similar:
        // The grid holds a request made before it mounts and acts on it
        // later; only ask once it is there.
        if (_similarKey.currentContext == null) return false;
        return _similarGrid.requestFocus();
    }
  }

  void _enterStop(_Stop stop) {
    if (_stop != stop) setState(() => _stop = stop);
    _scheduleShift();
  }

  void _scheduleShift() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stop = _stop;
      final section = switch (stop) {
        _Stop.actions => null,
        _Stop.seasons || _Stop.episodes => _episodesKey,
        _Stop.cast => _castKey,
        _Stop.videos => _videosKey,
        _Stop.similar => _similarKey,
      };
      final column = _columnKey.currentContext?.findRenderObject();
      final box = section?.currentContext?.findRenderObject();
      var shift = 0.0;
      if (column is RenderBox && box is RenderBox && box.hasSize) {
        // Measured in the column's own coordinates, which the slide does not
        // move.
        shift = box.localToGlobal(Offset.zero, ancestor: column).dy;
        // The grid runs taller than the screen: below its first rows the
        // page follows the focused card down.
        final card =
            FocusManager.instance.primaryFocus?.context?.findRenderObject();
        final page = context.size;
        if (stop == _Stop.similar &&
            card is RenderBox &&
            card.hasSize &&
            page != null) {
          final cardBottom = card
              .localToGlobal(Offset(0, card.size.height), ancestor: column)
              .dy;
          final inset = _insetFor(BoxConstraints.tight(page));
          shift = math.max(shift, cardBottom - page.height + inset * 2);
        }
      }
      if (shift != _shift) setState(() => _shift = shift);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final stops = _Stop.values;
    final index = stops.indexOf(_stop);
    if (key == LogicalKeyboardKey.arrowDown) {
      for (final next in stops.skip(index + 1)) {
        if (_focusStop(next)) return KeyEventResult.handled;
        // Wait for the season's episodes rather than skip past them.
        if (next == _Stop.episodes && _episodesPending) {
          return KeyEventResult.handled;
        }
      }
      // Nothing of the page's own below: a Retry, say, is reached the usual
      // way.
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      for (final previous in stops.take(index).toList().reversed) {
        if (_focusStop(previous)) return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (_backKeys.contains(key) &&
        event is KeyDownEvent &&
        _stop != _Stop.actions &&
        _focusStop(_Stop.actions)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _episodesScope(int season) => 'details-episodes:${_item.id}:$season';

  bool get _episodesPending {
    final season = _selectedSeason;
    if (season == null || _loadedSeasons.contains(season)) return false;
    // Settling, or in flight; a failed season is neither, and its Retry
    // should be reachable.
    return _seasonTimer?.isActive == true || _seasons.containsKey(season);
  }

  Widget _stopRegion(_Stop stop, Widget child) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (hasFocus) {
          if (hasFocus) _enterStop(stop);
        },
        child: child,
      );

  // Actions.

  Future<void> _toggleBookmark(bool current) async {
    if (_bookmarkBusy) return;
    setState(() => _bookmarkBusy = true);
    try {
      final updated = await _controller.toggleBookmark(_item, current);
      if (mounted) {
        setState(() => _bookmarked = Future<bool>.value(updated));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                updated ? tr('added_to_my_list') : tr('removed_from_my_list')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  void _restoreFocus(FocusNode? previousFocus) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          previousFocus == null ||
          previousFocus.context == null ||
          !previousFocus.canRequestFocus) {
        return;
      }
      previousFocus.requestFocus();
    });
  }

  Future<void> _openRecommendation(TvMediaItem item) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    final logos = TvTitleLogoScope.maybeOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          final page =
              TvMediaDetailsScreen(item: item, controller: _controller);
          return logos == null
              ? page
              : TvTitleLogoScope(logos: logos, child: page);
        },
      ),
    );
    _restoreFocus(previousFocus);
  }

  Future<void> _openPerson(TitlePerson person) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    final logos = TvTitleLogoScope.maybeOf(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) {
          final page = TvPersonScreen(
            personId: person.id,
            name: person.name,
            profilePath: person.profilePath,
            isAdult: person.adult,
            controller: _controller,
          );
          return logos == null
              ? page
              : TvTitleLogoScope(logos: logos, child: page);
        },
      ),
    );
    _restoreFocus(previousFocus);
  }

  Future<void> _activateEpisode(
          EpisodeList episode, List<EpisodeList> season) =>
      _showEpisode(episode, season);

  Future<void> _showEpisode(
      EpisodeList episode, List<EpisodeList> season) async {
    await showTvDialog<void>(
        context: context,
        title: episode.name ?? tr('tv_episode_information'),
        content: Text(episode.overview?.trim().isNotEmpty == true
            ? episode.overview!
            : tr('tv_no_episode_overview_is_available')),
        actions: [
          TvDialogAction(
              label: tr('close'),
              autofocus: true,
              onPressed: () => Navigator.of(context).pop())
        ]);
  }

  // Layout.

  double _insetFor(BoxConstraints constraints) {
    final metrics = TvShellMetrics.fromConstraints(constraints);
    final system = MediaQuery.paddingOf(context);
    return metrics.safeInset > system.left ? metrics.safeInset : system.left;
  }

  @override
  Widget build(BuildContext context) => Builder(builder: _page);

  Widget _page(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final resume = _resume(listen: true);
    return TvFocusMemoryScope(
      memory: _memory,
      child: Scaffold(
        backgroundColor: palette.page,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = TvShellMetrics.fromConstraints(constraints);
            final inset = _insetFor(constraints);
            final height = constraints.maxHeight;
            final browsing = _stop != _Stop.actions;

            return Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _handleKey,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    TvBackdrop(item: _item, settleDelay: Duration.zero),
                    // A plain shaded rect rather than an Opacity, which would
                    // cost the whole backdrop an offscreen layer.
                    AnimatedContainer(
                      duration: _motion,
                      color: browsing ? palette.scrim(0.8) : palette.scrim(0),
                    ),
                    Positioned(
                      left: inset,
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRect(
                        clipper: const TvLeadingEdgeClipper(),
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minHeight: 0,
                          maxHeight: double.infinity,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              end: browsing ? inset - _shift : 0,
                            ),
                            duration: _motion,
                            curve: Curves.easeOutCubic,
                            builder: (_, dy, child) => Transform.translate(
                              offset: Offset(0, dy),
                              child: child,
                            ),
                            child: Column(
                              key: _columnKey,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(
                                  // Leaves the next section's title peeking in,
                                  // so the page reads as more than one screen.
                                  height: height * (_hasRowsBelow ? 0.84 : 1) -
                                      (_hasRowsBelow ? 0 : inset),
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: _stopRegion(
                                      _Stop.actions,
                                      _buildHero(
                                        metrics,
                                        resume,
                                        maxWidth: ((constraints.maxWidth -
                                                    inset * 2) *
                                                0.5)
                                            .clamp(
                                                0.0,
                                                metrics.compact
                                                    ? 460.0
                                                    : 620.0),
                                        dimmed: browsing,
                                      ),
                                    ),
                                  ),
                                ),
                                ..._buildSections(
                                  metrics,
                                  resume,
                                  inset: inset,
                                ),
                                // Room for the last section to slide to the top.
                                SizedBox(height: height * 0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // A thin banner along the backdrop's top edge, clear of
                    // the artwork's subject and the bottom-left info, while
                    // the viewer reads and picks. Remove the WebView while
                    // the rows below are in view so hidden ads stop loading.
                    Positioned(
                      top: inset * 0.6,
                      right: inset,
                      width: (constraints.maxWidth - inset * 2)
                          .clamp(0.0, 360.0)
                          .toDouble(),
                      child: Visibility(
                        visible: !browsing,
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _hasRowsBelow {
    final data = _loaded;
    if (data == null) return true;
    return data.recommendations.isNotEmpty ||
        data.seasons.isNotEmpty ||
        _people.isNotEmpty ||
        (_videos?.isNotEmpty ?? false) ||
        _videosFailed;
  }

  Widget _buildHero(
    TvShellMetrics metrics,
    TvResumePoint? resume, {
    required double maxWidth,
    required bool dimmed,
  }) {
    final palette = TvPalette.of(context);
    final compact = metrics.compact;
    final colors = Theme.of(context).colorScheme;
    final data = _loaded;
    final facts = data?.facts ??
        <String>[
          if (_item.year case final year?) year,
          if (_item.rating case final rating? when rating > 0)
            '★ ${rating.toStringAsFixed(1)}',
        ];
    final overview = _item.overview;

    return Padding(
      padding: EdgeInsets.only(
        left: TvDesign.focusOutset + 4,
        bottom: compact ? 18 : 28,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _isMovie
                      ? PhosphorIcons.filmSlate()
                      : PhosphorIcons.television(),
                  color: colors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _isMovie ? tr('tv_movie') : tr('tv_series'),
                  style: TextStyle(
                    color: colors.primary,
                    fontFamily: 'FigtreeSB',
                    fontSize: compact ? 11 : 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TvTitleLogo(
              item: _item,
              maxHeight: compact ? 104 : 140,
              fallback: Text(
                _item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontFamily: 'FigtreeBold',
                  fontSize: compact ? 38 : 52,
                  height: 1.02,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            if (facts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                facts.join('   '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.secondaryText,
                  fontFamily: 'FigtreeSB',
                  fontSize: compact ? 14 : 16,
                ),
              ),
            ],
            if (resume != null && !resume.finished) ...<Widget>[
              const SizedBox(height: 12),
              _ResumeProgress(resume: resume, compact: compact),
            ],
            if (overview.isNotEmpty) ...<Widget>[
              SizedBox(height: compact ? 10 : 14),
              Text(
                overview,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: compact ? 14 : 17,
                  height: 1.35,
                ),
              ),
            ],
            SizedBox(height: compact ? 14 : 20),
            // Faded behind the rows below, not hidden, so Up finds it again.
            AnimatedOpacity(
              duration: _motion,
              opacity: dimmed ? 0.35 : 1,
              child: _buildActions(resume),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(TvResumePoint? resume) {
    final canWatch =
        context.watch<AppDependencyProvider>().displayWatchNowButton;
    final resuming = resume != null && !resume.finished;

    final buttons = <Widget>[
      if (canWatch) const SizedBox.shrink(),
      if (canWatch && resuming) const SizedBox.shrink(),
      if (!_isMovie && (_loaded?.seasons.isNotEmpty ?? false))
        _DetailButton(
          focusNode: _actionNode('episodes'),
          label: tr('episodes'),
          icon: PhosphorIcons.listBullets(),
          onFocused: () => _lastActionId = 'episodes',
          onActivate: () =>
              _focusStop(_Stop.episodes) || _focusStop(_Stop.seasons),
        ),
      FutureBuilder<bool>(
        future: _bookmarked,
        builder: (context, snapshot) {
          final saved = snapshot.data ?? false;
          return _DetailButton(
            focusNode: _actionNode('list'),
            label: tr('my_list'),
            icon: saved
                ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                : PhosphorIcons.plusCircle(),
            // Autofocus falls here when nothing can be played.
            autofocus: !canWatch,
            enabled: snapshot.hasData && !_bookmarkBusy,
            onFocused: () => _lastActionId = 'list',
            onActivate: () => _toggleBookmark(saved),
          );
        },
      ),
      if (context.watch<PlaylistProvider?>() case final playlists?)
        _DetailButton(
          focusNode: _actionNode('lists'),
          label: tr('playlist_save'),
          icon: playlists.listsContaining(_item).isNotEmpty
              ? PhosphorIcons.listChecks()
              : PhosphorIcons.listPlus(),
          onFocused: () => _lastActionId = 'lists',
          onActivate: () => showTvPlaylistPicker(context, _item),
        ),
    ];
    _actionOrder = <String>[
      if (canWatch) 'play',
      if (canWatch && resuming) 'restart',
      if (!_isMovie && (_loaded?.seasons.isNotEmpty ?? false)) 'episodes',
      'list',
      if (context.read<PlaylistProvider?>() != null) 'lists',
    ];
    // One line, even when the buttons run wider than the text above them: a
    // wrapped second line sent Right from the first line's end off to
    // whatever lay below and to the right, the season picker.
    return FocusTraversalGroup(
      policy: _actionsPolicy,
      child: SizedBox(
        height: 56,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var index = 0; index < buttons.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 12),
                buttons[index],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The action buttons in the order Left and Right step through them.
  List<String> _actionOrder = const <String>[];
  late final _actionsPolicy = _ActionsTraversalPolicy(_stepAction);

  /// Moves focus [delta] buttons along from [node], skipping any that cannot
  /// take focus (My List while it loads), or reports that the row ends there.
  bool _stepAction(FocusNode node, int delta) {
    final nodes = <FocusNode>[
      for (final id in _actionOrder)
        if (_actionNodes[id] case final actionNode?) actionNode,
    ];
    var index = nodes.indexOf(node);
    if (index < 0) return false;
    while (true) {
      index += delta;
      if (index < 0 || index >= nodes.length) return false;
      final target = nodes[index];
      if (target.context != null && target.canRequestFocus) {
        target.requestFocus();
        return true;
      }
    }
  }

  List<Widget> _buildSections(
    TvShellMetrics metrics,
    TvResumePoint? resume, {
    required double inset,
  }) {
    final compact = metrics.compact;
    final gap = SizedBox(height: compact ? 16 : 24);
    return <Widget>[
      FutureBuilder<TvMediaDetailsData>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SectionMessage(
              message: tr('tv_some_details_could_not_be_loaded'),
              actionLabel: tr('retry'),
              onAction: _retry,
            );
          }
          final data = snapshot.data;
          if (data == null) return const SizedBox.shrink();
          return Column(
            key: _episodesKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (data.seasons.isNotEmpty) ...<Widget>[
                _buildSeasons(data.seasons),
                _buildEpisodes(metrics, data, resume, inset: inset),
                gap,
              ],
            ],
          );
        },
      ),
      _buildCast(metrics, inset: inset, gap: gap),
      _buildVideos(metrics, inset: inset, gap: gap),
      FutureBuilder<TvMediaDetailsData>(
        future: _details,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null || data.recommendations.isEmpty) {
            return const SizedBox.shrink();
          }
          return KeyedSubtree(
            key: _similarKey,
            child: _stopRegion(
              _Stop.similar,
              _buildSimilar(metrics, data, inset: inset),
            ),
          );
        },
      ),
    ];
  }

  /// The cast in billing order, then who made the title.
  List<TitlePerson> get _people => titlePeople(
        _credits,
        creators: _loaded?.seriesDetails?.createdBy ?? const <CreatedBy>[],
        creatorRole: tr('tv_creator'),
      );

  /// Faces in billing order, each opening the person's page. Nothing at
  /// all while they load or when nobody is listed, so Down never stops on
  /// an empty row.
  Widget _buildCast(
    TvShellMetrics metrics, {
    required double inset,
    required Widget gap,
  }) {
    final people = _people;
    if (people.isEmpty) return const SizedBox.shrink();
    final width = metrics.mediaCardWidth * 0.9;
    return Column(
      key: _castKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _stopRegion(
          _Stop.cast,
          TvContentRow<TitlePerson>(
            controller: _castRow,
            title: tr('cast_and_crew'),
            scopeId: 'details-cast:${_item.stableId}',
            items: people,
            itemId: (person) => person.key,
            semanticLabel: (person) => <String>[
              person.name,
              if (person.role case final role?) role,
            ].join(', '),
            itemBuilder: (_, person) => TvPersonCard(
              name: person.name,
              role: person.role,
              profilePath: person.profilePath,
              width: width,
            ),
            itemSpacing: 18,
            itemFocusScale: 1.06,
            trailingInset: inset,
            pinFocusedItem: true,
            onItemActivated: _openPerson,
          ),
        ),
        gap,
      ],
    );
  }

  String get _videosScope => 'details-videos:${_item.stableId}';

  /// The title's trailers, teasers and featurettes, each opening in YouTube.
  /// Nothing at all while they load or when there are none, so Down never
  /// stops on an empty row; a Retry when they could not load.
  Widget _buildVideos(
    TvShellMetrics metrics, {
    required double inset,
    required Widget gap,
  }) {
    if (_videosFailed) {
      return KeyedSubtree(
        key: _videosKey,
        child: _stopRegion(
          _Stop.videos,
          _SectionMessage(
            message: tr('tv_videos_could_not_be_loaded'),
            actionLabel: tr('retry'),
            onAction: _loadVideos,
            focusNode: _videosRetry,
          ),
        ),
      );
    }
    final videos = _videos;
    if (videos == null || videos.isEmpty) return const SizedBox.shrink();
    final width = metrics.mediaCardWidth * 1.75;
    return Column(
      key: _videosKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _stopRegion(
          _Stop.videos,
          TvContentRow<Results>(
            controller: _videoRow,
            title: tr('videos'),
            scopeId: _videosScope,
            items: videos,
            itemId: (video) => video.videoLink!,
            semanticLabel: (video) => <String>[
              if (video.name?.trim() case final name? when name.isNotEmpty)
                name,
              if (video.type?.trim() case final type? when type.isNotEmpty)
                type,
            ].join(', '),
            itemBuilder: (_, video) => _VideoCard(video: video, width: width),
            itemSpacing: 18,
            itemFocusScale: 1.06,
            trailingInset: inset,
            pinFocusedItem: true,
            onItemActivated: _openVideo,
          ),
        ),
        gap,
      ],
    );
  }

  /// Hands [video] to YouTube. Focus stays on its card meanwhile, so the
  /// viewer comes back to it.
  Future<void> _openVideo(Results video) async {
    if (await openYouTubeVideo(video) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('tv_video_could_not_open'))),
    );
  }

  /// A grid rather than a row, so the recommendations fill the page below
  /// the episodes instead of leaving its lower half empty.
  Widget _buildSimilar(
    TvShellMetrics metrics,
    TvMediaDetailsData data, {
    required double inset,
  }) {
    final palette = TvPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          // Lines up with the artwork, as the rows' titles do.
          padding: const EdgeInsets.only(left: TvDesign.focusOutset + 6),
          child: Text(
            tr('tv_more_like_this'),
            style: TextStyle(
              color: palette.foreground,
              fontFamily: 'FigtreeSB',
              fontSize: 21,
              letterSpacing: -0.15,
            ),
          ),
        ),
        TvContentGrid<TvMediaItem>(
          controller: _similarGrid,
          scopeId: 'details-similar:${_item.stableId}',
          items: data.recommendations,
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
          shrinkWrap: true,
          // The page runs to the screen edge; the grid stops at its margin.
          padding: EdgeInsets.fromLTRB(
            TvDesign.focusOutset,
            8,
            TvDesign.focusOutset + inset,
            TvDesign.focusOutset,
          ),
          horizontalSpacing: 18,
          verticalSpacing: 20,
          onItemActivated: _openRecommendation,
          onItemFocused: (_) => _scheduleShift(),
        ),
      ],
    );
  }

  Widget _buildSeasons(List<Seasons> seasons) {
    final selected = _selectedSeason;
    return _stopRegion(
      _Stop.seasons,
      TvContentRow<Seasons>(
        controller: _seasonRow,
        title: tr('episodes'),
        scopeId: 'details-seasons:${_item.id}',
        items: seasons,
        itemId: (season) => '${season.seasonNumber}',
        semanticLabel: (season) => _seasonName(season),
        itemBuilder: (_, season) => _SeasonPill(
          label: _seasonName(season),
          selected: season.seasonNumber == selected,
        ),
        itemSpacing: 8,
        itemFocusScale: 1.04,
        itemFocusRadius: 24,
        pinFocusedItem: true,
        onItemFocused: (season) => _selectSeason(season.seasonNumber!),
        onItemActivated: (season) {
          _selectSeason(season.seasonNumber!, immediately: true);
          _focusStop(_Stop.episodes);
        },
      ),
    );
  }

  static String _seasonName(Seasons season) {
    final number = season.seasonNumber ?? 0;
    if (number <= 0) return season.name ?? tr('tv_specials');
    return tr('tv_season_number', namedArgs: {'season': '$number'});
  }

  Widget _buildEpisodes(
    TvShellMetrics metrics,
    TvMediaDetailsData data,
    TvResumePoint? resume, {
    required double inset,
  }) {
    final season = _selectedSeason;
    final width = metrics.mediaCardWidth * 1.75;
    final cardHeight = width * 9 / 16 + _EpisodeCard.captionHeight;
    final episodes = season == null ? null : _seasons[season];
    final seasonInfo =
        data.seasons.where((item) => item.seasonNumber == season).firstOrNull;
    return FutureBuilder<List<EpisodeList>>(
      key: ValueKey<int?>(season),
      future: episodes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SectionMessage(
            message: tr('tv_episodes_could_not_be_loaded'),
            actionLabel: tr('retry'),
            onAction: () {
              if (season != null) _selectSeason(season, immediately: true);
            },
          );
        }
        final items = snapshot.data;
        if (items == null || season == null) {
          return _EpisodePlaceholders(width: width, height: cardHeight);
        }
        if (items.isEmpty) {
          return _SectionMessage(
            message: tr('tv_no_episodes_are_listed_for_this_season_yet'),
          );
        }
        final watched = resume?.episode;
        final count = items.length;
        return _stopRegion(
          _Stop.episodes,
          TvContentRow<EpisodeList>(
            controller: _episodeRows.putIfAbsent(
              season,
              TvContentRowController.new,
            ),
            title: tr('tv_season_episode_count', namedArgs: {
              'season': seasonInfo == null
                  ? tr('tv_season_number', namedArgs: {'season': '$season'})
                  : _seasonName(seasonInfo),
              'episodes': plural('tv_episodes_count', count, name: 'count')
            }),
            scopeId: _episodesScope(season),
            items: items,
            itemId: (episode) => '${episode.episodeNumber}',
            semanticLabel: (episode) => tr('tv_episode_semantics', namedArgs: {
              'number': '${episode.episodeNumber ?? ''}',
              'title': episode.name ?? tr('tv_untitled_episode')
            }),
            itemBuilder: (_, episode) => _EpisodeCard(
              episode: episode,
              width: width,
              fallbackPath: _item.backdropPath,
              airLabel: _airLabel(episode),
              progress: watched != null &&
                      watched.seasonNum == episode.seasonNumber &&
                      watched.episodeNum == episode.episodeNumber
                  ? resume!.progress
                  : null,
            ),
            itemSpacing: 18,
            itemFocusScale: 1.06,
            trailingInset: inset,
            pinFocusedItem: true,
            onItemActivated: (episode) => _activateEpisode(episode, items),
            onItemMenu: (episode) => _showEpisode(episode, items),
            itemMenuHint: tr('tv_hold_ok_for_episode_info'),
          ),
        );
      },
    );
  }

  /// "Coming 3 Oct 2026" for an episode yet to air, else its air date.
  static String? _airLabel(EpisodeList episode) {
    final aired = DateTime.tryParse(episode.airDate ?? '');
    if (aired == null) return null;
    final date = DateFormat.yMMMd().format(aired);
    return hasAired(episode)
        ? date
        : tr('tv_coming_date', namedArgs: {'date': date});
  }
}

/// Left and Right stay on the action buttons; Down and Up belong to the page.
class _ActionsTraversalPolicy extends ReadingOrderTraversalPolicy {
  _ActionsTraversalPolicy(this._step);

  final bool Function(FocusNode node, int delta) _step;

  /// Left and Right follow the buttons' order rather than geometry, which
  /// would search the whole page for the nearest thing in that direction.
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    return switch (direction) {
      TraversalDirection.left => _step(currentNode, -1),
      TraversalDirection.right => _step(currentNode, 1),
      // Up and Down are the page's to route; they only get here when the
      // page has nothing of its own below, such as a Retry.
      _ => super.inDirection(currentNode, direction),
    };
  }
}

/// A hero action: a translucent pill that turns white with focus, as the
/// rail's destinations do.
class _DetailButton extends StatefulWidget {
  const _DetailButton({
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.onActivate,
    this.onFocused,
    this.autofocus = false,
    this.enabled = true,
  });

  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onActivate;
  final VoidCallback? onFocused;
  final bool autofocus;
  final bool enabled;

  @override
  State<_DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<_DetailButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => PlaybackAction(
        onStart: widget.onActivate,
        builder: (context, busy, start) => _buildButton(context, busy, start),
      );

  Widget _buildButton(BuildContext context, bool busy, VoidCallback start) {
    final palette = TvPalette.of(context);
    final foreground = _focused ? palette.onFocus : palette.foreground;
    return TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: widget.label,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onActivate: busy ? () {} : start,
      onFocusChanged: (hasFocus) {
        if (hasFocus) widget.onFocused?.call();
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      focusScale: 1.04,
      focusColor: Colors.transparent,
      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      scrollAlignment: null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _focused ? palette.focusFill : palette.idleFill,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (busy)
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(widget.icon, color: foreground, size: 20),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                color: foreground,
                fontFamily: 'FigtreeSB',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How far into the title the user is, under its facts.
class _ResumeProgress extends StatelessWidget {
  const _ResumeProgress({required this.resume, required this.compact});

  final TvResumePoint resume;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: compact ? 140 : 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: resume.progress,
              minHeight: 3,
              color: colors.primary,
              backgroundColor: palette.foreground.withValues(alpha: 0.24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          <String>[
            if (resume.episodeLabel case final label?) label,
            resume.timeLeft,
          ].join('  ·  '),
          style: TextStyle(
            color: palette.mutedText,
            fontFamily: 'FigtreeSB',
            fontSize: compact ? 13 : 14,
          ),
        ),
      ],
    );
  }
}

/// A season in the picker: white once chosen, muted otherwise.
class _SeasonPill extends StatelessWidget {
  const _SeasonPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? palette.focusFill : palette.idleFill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? palette.onFocus : palette.mutedText,
          fontFamily: selected ? 'FigtreeSB' : 'Figtree',
          fontSize: 15,
        ),
      ),
    );
  }
}

/// An episode: its still, numbered, with the title and air date below.
class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.width,
    this.fallbackPath,
    this.airLabel,
    this.progress,
  });

  static const captionHeight = 44.0;

  final EpisodeList episode;
  final double width;

  /// The series backdrop, for an episode without a still of its own.
  final String? fallbackPath;
  final String? airLabel;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    final still = episode.stillPath;
    final path = still ?? fallbackPath;
    final imageUrl = path == null
        ? null
        : '${buildImageUrl(
            TMDB_BASE_IMAGE_URL,
            proxy,
            settings.enableProxy,
            context,
          )}w300$path';
    final number = episode.episodeNumber;
    final placeholder = ColoredBox(
      color: palette.raisedSurface,
      child: Center(
        child: OutlineMark(height: 34, color: palette.mutedText),
      ),
    );

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TvDesign.cardRadius),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (imageUrl == null)
                    placeholder
                  else
                    CachedNetworkImage(
                      cacheManager: cacheProp(),
                      imageUrl: imageUrl,
                      memCacheWidth:
                          (width * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => placeholder,
                      errorWidget: (_, __, ___) => placeholder,
                    ),
                  // The series art stands in for a missing still; shade it
                  // so a row of them does not read as one image repeated.
                  if (still == null && imageUrl != null)
                    const ColoredBox(color: Color(0x99050606)),
                  if (!hasAired(episode) && airLabel != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      right: 6,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: TvMediaBadge(label: airLabel!.toUpperCase()),
                      ),
                    ),
                  if (progress case final progress?)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: colors.primary,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: captionHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${number == null ? '' : '$number. '}'
                    '${episode.name ?? tr('tv_untitled_episode')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: 15,
                      height: 1.1,
                    ),
                  ),
                  if (airLabel != null && hasAired(episode)) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      airLabel!,
                      maxLines: 1,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A video: its YouTube thumbnail with a play mark, the name and TMDB's
/// kind of video ("Trailer", "Featurette") below.
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.width});

  final Results video;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final type = video.type?.trim() ?? '';
    final placeholder = ColoredBox(
      color: palette.raisedSurface,
      child: Center(
        child: OutlineMark(height: 34, color: palette.mutedText),
      ),
    );
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TvDesign.cardRadius),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CachedNetworkImage(
                    cacheManager: cacheProp(),
                    imageUrl:
                        '$YOUTUBE_THUMBNAIL_URL${video.videoLink}/hqdefault.jpg',
                    memCacheWidth:
                        (width * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => placeholder,
                    errorWidget: (_, __, ___) => placeholder,
                  ),
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0x8C000000),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.play(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _EpisodeCard.captionHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeSB',
                      fontSize: 15,
                      height: 1.1,
                    ),
                  ),
                  if (type.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The episode row's shape while a season loads.
class _EpisodePlaceholders extends StatelessWidget {
  const _EpisodePlaceholders({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Semantics(
      label: tr('loading_episodes'),
      child: Padding(
        padding: const EdgeInsets.only(
          left: TvDesign.focusOutset + 4,
          top: 31 + 12,
          bottom: 12,
        ),
        child: SizedBox(
          height: height,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var index = 0; index < 5; index++)
                  Container(
                    width: width,
                    height: width * 9 / 16,
                    margin: const EdgeInsets.only(right: 26),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(TvDesign.cardRadius),
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

/// A short note in place of a section that could not show, with a way to
/// try again.
class _SectionMessage extends StatelessWidget {
  const _SectionMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.focusNode,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The action's, for a page that moves focus to it itself.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final action = onAction;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TvDesign.focusOutset + 4, 8, 0, 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: TextStyle(color: palette.mutedText, fontSize: 15),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: 16),
            TvFocusable(
              focusNode: focusNode,
              semanticLabel: actionLabel ?? tr('retry'),
              onActivate: action,
              focusScale: 1.04,
              borderRadius: BorderRadius.circular(TvDesign.cardRadius),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: palette.idleFill,
                  borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                ),
                child: Text(
                  actionLabel ?? tr('retry'),
                  style: TextStyle(
                    color: palette.foreground,
                    fontFamily: 'FigtreeSB',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
