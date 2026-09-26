import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/tv.dart';
import '../../models/tv_stream_metadata.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/movie/movie_video_loader.dart';
import '../../screens/tv/tv_video_loader.dart';
import '../app/tv_design.dart';
import '../controllers/tv_media_details_controller.dart';
import '../controllers/tv_title_logos.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_row.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_spotlight.dart';

/// A title's page, laid out like the browse pages: its backdrop fills the
/// screen, the logo, facts and actions sit bottom left, and the episodes and
/// "More like this" rows wait below.
///
/// The page opens straight away from what the card already knows; details,
/// seasons and recommendations fill in as they load.
///
/// Down and Up step between the actions, the seasons, the episodes and the
/// recommendations, each returning to where it was left. Back from below
/// the actions returns to them; Back from the actions leaves the page.
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
enum _Stop { actions, seasons, episodes, similar }

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
  final TvContentRowController _similarRow = TvContentRowController();

  /// Where each row was left, for this page only.
  final TvFocusMemory _memory = TvFocusMemory();

  _Stop _stop = _Stop.actions;
  final GlobalKey _columnKey = GlobalKey();
  final GlobalKey _episodesKey = GlobalKey();
  final GlobalKey _similarKey = GlobalKey();

  /// How far the page is slid up, so the focused section sits at the top.
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

  @override
  void dispose() {
    _seasonTimer?.cancel();
    for (final node in _actionNodes.values) {
      node.dispose();
    }
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
      case _Stop.similar:
        return _similarRow.requestFocus();
    }
  }

  void _enterStop(_Stop stop) {
    if (_stop != stop) setState(() => _stop = stop);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stop != stop) return;
      final section = switch (stop) {
        _Stop.actions => null,
        _Stop.seasons || _Stop.episodes => _episodesKey,
        _Stop.similar => _similarKey,
      };
      final column = _columnKey.currentContext?.findRenderObject();
      final box = section?.currentContext?.findRenderObject();
      var shift = 0.0;
      if (column is RenderBox && box is RenderBox && box.hasSize) {
        // Measured in the column's own coordinates, which the slide does not
        // move.
        shift = box.localToGlobal(Offset.zero, ancestor: column).dy;
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
            content:
                Text(updated ? 'Added to My List' : 'Removed from My List'),
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

  Future<bool> _online() async {
    if (await checkConnection()) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check your internet connection.')),
      );
    }
    return false;
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

  Future<void> _playMovie({int? elapsed}) async {
    final movie = _item.movie;
    if (movie == null || movie.id == null) return;
    if (!await _online() || !mounted) return;
    final previousFocus = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MovieVideoLoader(
          download: false,
          useTvPlayer: true,
          onTvPlayerExit: () => _restoreFocus(previousFocus),
          metadata: MovieStreamMetadata(
            backdropPath: movie.backdropPath,
            elapsed: elapsed,
            movieId: movie.id,
            movieName: movie.title,
            posterPath: movie.posterPath,
            releaseYear: int.tryParse(_item.year ?? '') ?? 0,
            isAdult: movie.adult,
            releaseDate: movie.releaseDate,
          ),
        ),
      ),
    );
  }

  /// Plays the series from where it stands: the episode in progress, the one
  /// after a finished episode, or the very first.
  Future<void> _playSeries({bool fromStart = false}) async {
    final data = await _details?.then((data) => data, onError: (_) => null);
    if (data == null || !mounted) return;
    final seasons = data.seasons;
    final resume = fromStart ? null : _resume();
    final watched = resume?.episode;

    try {
      if (watched != null) {
        final season = await _episodesOf(watched.seasonNum!);
        if (!resume!.finished) {
          final episode = season.firstWhere(
            (episode) => episode.episodeNumber == watched.episodeNum,
            orElse: () => EpisodeList(
              episodeId: watched.id,
              episodeNumber: watched.episodeNum,
              seasonNumber: watched.seasonNum,
              name: watched.episodeName,
            ),
          );
          return _playEpisode(episode, season, elapsed: resume.elapsed);
        }
        final next = episodeAfter(season, watched.episodeNum!);
        if (next != null && hasAired(next)) {
          return _playEpisode(next, season);
        }
        final nextSeason = seasons
            .map((season) => season.seasonNumber!)
            .where((number) => number > watched.seasonNum!)
            .firstOrNull;
        if (nextSeason != null) {
          final episodes = await _episodesOf(nextSeason);
          if (episodes.isNotEmpty && hasAired(episodes.first)) {
            return _playEpisode(episodes.first, episodes);
          }
        }
      }
      final first = seasons.firstOrNull?.seasonNumber;
      if (first == null) return;
      final episodes = await _episodesOf(first);
      if (episodes.isNotEmpty) await _playEpisode(episodes.first, episodes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Episodes could not be loaded.')),
        );
      }
    }
  }

  Future<void> _playEpisode(
    EpisodeList episode,
    List<EpisodeList> seasonEpisodes, {
    int? elapsed,
  }) async {
    if (!await _online() || !mounted) return;
    final previousFocus = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TVVideoLoader(
          download: false,
          useTvPlayer: true,
          onTvPlayerExit: () => _restoreFocus(previousFocus),
          metadata: TVStreamMetadata(
            elapsed: elapsed,
            episodeId: episode.episodeId,
            episodeName: episode.name,
            episodeNumber: episode.episodeNumber,
            posterPath: _item.posterPath,
            backdropPath: episode.stillPath ?? _item.backdropPath,
            seasonNumber: episode.seasonNumber,
            seriesName: _item.title,
            tvId: _item.id,
            airDate: episode.airDate,
            seasonEpisodes: seasonEpisodes
                .where((item) => item.episodeId != null)
                .map(EpisodeMetadata.fromEpisodeList)
                .toList(growable: false),
            allSeasons: _loaded?.seriesDetails?.seasons
                ?.where((season) => season.seasonNumber != null)
                .map(SeasonMetadata.fromSeason)
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  bool _canPlay(EpisodeList episode) =>
      episode.episodeId != null &&
      hasAired(episode) &&
      context.read<AppDependencyProvider>().displayWatchNowButton;

  void _activateEpisode(EpisodeList episode, List<EpisodeList> season) {
    if (_canPlay(episode)) {
      final resume = _resume();
      final watched = resume?.episode;
      final resuming = watched != null &&
          !resume!.finished &&
          watched.seasonNum == episode.seasonNumber &&
          watched.episodeNum == episode.episodeNumber;
      _playEpisode(episode, season, elapsed: resuming ? resume.elapsed : null);
    } else {
      _showEpisode(episode, season);
    }
  }

  Future<void> _showEpisode(
    EpisodeList episode,
    List<EpisodeList> season,
  ) async {
    final canPlay = _canPlay(episode);
    final facts = <String>[
      if (episode.seasonNumber != null && episode.episodeNumber != null)
        'S${episode.seasonNumber}:E${episode.episodeNumber}',
      if (_airLabel(episode) case final aired?) aired,
      if (episode.voteAverage case final rating? when rating > 0)
        '★ ${rating.toStringAsFixed(1)}',
    ].join('   ');
    final play = await showTvDialog<bool>(
      context: context,
      title: episode.name ?? 'Episode information',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (facts.isNotEmpty) ...<Widget>[
            Text(facts),
            const SizedBox(height: 13),
          ],
          Text(
            episode.overview?.trim().isNotEmpty ?? false
                ? episode.overview!
                : 'No episode overview is available.',
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: <TvDialogAction>[
        if (canPlay)
          TvDialogAction(
            label: 'Play episode',
            autofocus: true,
            isPrimary: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        TvDialogAction(
          label: 'Close',
          autofocus: !canPlay,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
    if (play == true && mounted) await _playEpisode(episode, season);
  }

  // Layout.

  @override
  Widget build(BuildContext context) {
    final resume = _resume(listen: true);
    return TvFocusMemoryScope(
      memory: _memory,
      child: Scaffold(
        backgroundColor: TvDesign.pageBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = TvShellMetrics.fromConstraints(constraints);
            final system = MediaQuery.paddingOf(context);
            final inset = metrics.safeInset > system.left
                ? metrics.safeInset
                : system.left;
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
                      color: browsing
                          ? const Color(0xcc050606)
                          : const Color(0x00050606),
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
                                ..._buildSections(metrics, resume),
                                // Room for the last section to slide to the top.
                                SizedBox(height: height * 0.6),
                              ],
                            ),
                          ),
                        ),
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
    return data.recommendations.isNotEmpty || data.seasons.isNotEmpty;
  }

  Widget _buildHero(
    TvShellMetrics metrics,
    TvResumePoint? resume, {
    required double maxWidth,
    required bool dimmed,
  }) {
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
                  _isMovie ? 'MOVIE' : 'SERIES',
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
                  color: TvDesign.foreground,
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
                  color: const Color(0xffd2d2d2),
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
                  color: const Color(0xffdedede),
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
    final playLabel = switch ((_isMovie, resume)) {
      (_, final point?) when !point.finished =>
        point.episodeLabel == null ? 'Resume' : 'Resume ${point.episodeLabel}',
      (false, final point?) when point.finished => 'Next episode',
      (true, _) => 'Play',
      (false, _) => 'Play S1:E1',
    };
    final seriesStartsAtOne = _loaded?.seasons.firstOrNull?.seasonNumber;
    final buttons = <Widget>[
      if (canWatch)
        _DetailButton(
          focusNode: _actionNode('play'),
          label: _isMovie || seriesStartsAtOne == null || resume != null
              ? playLabel
              : playLabel.replaceFirst('S1', 'S$seriesStartsAtOne'),
          icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
          autofocus: true,
          onFocused: () => _lastActionId = 'play',
          onActivate: () => _isMovie
              ? _playMovie(elapsed: resuming ? resume.elapsed : null)
              : _playSeries(),
        ),
      if (canWatch && resuming)
        _DetailButton(
          focusNode: _actionNode('restart'),
          label: _isMovie ? 'Play from start' : 'Play from S1:E1',
          icon: PhosphorIcons.arrowCounterClockwise(),
          onFocused: () => _lastActionId = 'restart',
          onActivate: () =>
              _isMovie ? _playMovie() : _playSeries(fromStart: true),
        ),
      if (!_isMovie && (_loaded?.seasons.isNotEmpty ?? false))
        _DetailButton(
          focusNode: _actionNode('episodes'),
          label: 'Episodes',
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
            label: 'My List',
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
    ];
    return FocusTraversalGroup(
      policy: _ActionsTraversalPolicy(),
      child: Wrap(spacing: 12, runSpacing: 12, children: buttons),
    );
  }

  List<Widget> _buildSections(TvShellMetrics metrics, TvResumePoint? resume) {
    final compact = metrics.compact;
    final gap = SizedBox(height: compact ? 16 : 24);
    return <Widget>[
      FutureBuilder<TvMediaDetailsData>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SectionMessage(
              message: 'Some details could not be loaded.',
              actionLabel: 'Retry',
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
                _buildEpisodes(metrics, data, resume),
                gap,
              ],
              if (data.recommendations.isNotEmpty)
                KeyedSubtree(
                  key: _similarKey,
                  child: _stopRegion(
                    _Stop.similar,
                    TvContentRow<TvMediaItem>(
                      controller: _similarRow,
                      title: 'More like this',
                      scopeId: 'details-similar:${_item.stableId}',
                      items:
                          data.recommendations.take(16).toList(growable: false),
                      itemId: (item) => item.stableId,
                      semanticLabel: (item) => item.title,
                      itemBuilder: (_, item) => TvMediaCard(
                        item: item,
                        width: metrics.mediaCardWidth,
                        badge: TvMediaBadge.recencyOf(item),
                      ),
                      itemSpacing: 18,
                      itemFocusScale: 1.06,
                      pinFocusedItem: true,
                      onItemActivated: _openRecommendation,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }

  Widget _buildSeasons(List<Seasons> seasons) {
    final selected = _selectedSeason;
    return _stopRegion(
      _Stop.seasons,
      TvContentRow<Seasons>(
        controller: _seasonRow,
        title: 'Episodes',
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
    if (number <= 0) return season.name ?? 'Specials';
    return 'Season $number';
  }

  Widget _buildEpisodes(
    TvShellMetrics metrics,
    TvMediaDetailsData data,
    TvResumePoint? resume,
  ) {
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
            message: 'Episodes could not be loaded.',
            actionLabel: 'Retry',
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
          return const _SectionMessage(
            message: 'No episodes are listed for this season yet.',
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
            title:
                '${seasonInfo == null ? 'Season $season' : _seasonName(seasonInfo)}'
                '  ·  $count episode${count == 1 ? '' : 's'}',
            scopeId: _episodesScope(season),
            items: items,
            itemId: (episode) => '${episode.episodeNumber}',
            semanticLabel: (episode) =>
                'Episode ${episode.episodeNumber ?? ''}, '
                '${episode.name ?? 'Untitled episode'}',
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
            pinFocusedItem: true,
            onItemActivated: (episode) => _activateEpisode(episode, items),
            onItemMenu: (episode) => _showEpisode(episode, items),
            itemMenuHint: 'Hold OK for episode info',
          ),
        );
      },
    );
  }

  /// "Coming 3 Oct 2026" for an episode yet to air, else its air date.
  static String? _airLabel(EpisodeList episode) {
    final aired = DateTime.tryParse(episode.airDate ?? '');
    if (aired == null) return null;
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
    ];
    final date = '${aired.day} ${months[aired.month - 1]} ${aired.year}';
    return hasAired(episode) ? date : 'Coming $date';
  }
}

/// Left and Right stay on the action buttons; Down and Up belong to the page.
class _ActionsTraversalPolicy extends ReadingOrderTraversalPolicy {
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    if (direction == TraversalDirection.up ||
        direction == TraversalDirection.down) {
      return false;
    }
    return super.inDirection(currentNode, direction);
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
  final VoidCallback onActivate;
  final VoidCallback? onFocused;
  final bool autofocus;
  final bool enabled;

  @override
  State<_DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<_DetailButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final foreground = _focused ? Colors.black : TvDesign.foreground;
    return TvFocusable(
      focusNode: widget.focusNode,
      semanticLabel: widget.label,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onActivate: widget.onActivate,
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
          color: _focused ? const Color(0xf2ffffff) : const Color(0x33ffffff),
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
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
              backgroundColor: Colors.white24,
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
            color: TvDesign.mutedText,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xf2ffffff) : const Color(0x1fffffff),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : TvDesign.mutedText,
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
      color: TvDesign.raisedSurface,
      child: Center(
        child: Icon(
          PhosphorIcons.television(),
          color: TvDesign.mutedText,
          size: 30,
        ),
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
                    '${episode.name ?? 'Untitled episode'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TvDesign.foreground,
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
                      style: const TextStyle(
                        color: TvDesign.mutedText,
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
    return Semantics(
      label: 'Loading episodes',
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
                      color: TvDesign.surface,
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
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = onAction;
    return Padding(
      padding: const EdgeInsets.fromLTRB(TvDesign.focusOutset + 4, 8, 0, 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: const TextStyle(color: TvDesign.mutedText, fontSize: 15),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: 16),
            TvFocusable(
              semanticLabel: actionLabel ?? 'Retry',
              onActivate: action,
              focusScale: 1.04,
              borderRadius: BorderRadius.circular(TvDesign.cardRadius),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0x33ffffff),
                  borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                ),
                child: Text(
                  actionLabel ?? 'Retry',
                  style: const TextStyle(
                    color: TvDesign.foreground,
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
