import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../controllers/live_tv_database_controller.dart';
import '../../functions/function.dart';
import '../../functions/live_channel_letters.dart';
import '../../functions/live_schedule_sports.dart';
import '../../models/live_tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/live_player.dart';
import '../../services/adsterra_playback_ads_service.dart';
import '../../services/analytics_service.dart';
import '../../services/daddylive_service.dart';
import '../../services/live_channel_focus.dart';
import '../../widgets/hosted_ads_banner.dart';
// EthioTV source (commented out - disabled):
// import '../../services/ethio_sports_service.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../player/tv_player_screen.dart';
import '../widgets/tv_state_panel.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_loading_skeletons.dart';

enum _TvLiveScope { all, favorites, recent }

enum _TvLiveMode { channels, schedule }

// EthioTV source (commented out - disabled):
// enum _TvLiveSource { daddyLive, ethioSports }

class TvLiveScreen extends StatefulWidget {
  const TvLiveScreen({required this.metrics, this.focusController, super.key});

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  State<TvLiveScreen> createState() => _TvLiveScreenState();
}

class _TvLiveScreenState extends State<TvLiveScreen> {
  static const _analyticsSurface = 'tv';
  final _daddyDatabase = LiveTVDatabaseController();
  // EthioTV source (commented out - disabled):
  // final _ethioDatabase = LiveTVDatabaseController(namespace: 'ethiosports');
  final _searchController = TextEditingController();
  late final FocusNode _searchFocus;
  final _channelGrid = TvContentGridController();
  final _browseFocus = FocusNode(debugLabel: 'Live TV browse controls');
  bool _showSearch = false;
  DaddyLiveService? _service;
  // EthioTV source (commented out - disabled):
  // EthioSportsService? _ethioService;
  List<Channel> _channels = const <Channel>[];
  DaddyLiveEpg? _epg;
  Set<String> _favorites = <String>{};
  List<String> _recent = const <String>[];
  _TvLiveScope _scope = _TvLiveScope.all;
  _TvLiveMode _mode = _TvLiveMode.channels;
  // EthioTV source (commented out - disabled):
  // _TvLiveSource _source = _TvLiveSource.daddyLive;
  String? _category;
  String? _letter;
  int _selectedDayIndex = 0;
  String? _sport;
  // Schedule events start collapsed; keys come from [_eventKey].
  final Set<String> _expandedEvents = <String>{};
  String? _resolvingId;
  String _query = '';
  String? _error;
  bool _loading = true;
  Timer? _searchAnalyticsDebounce;

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestContentFocus);
    _searchFocus = FocusNode(
      debugLabel: 'Live TV search',
      onKeyEvent: _handleSearchKeyEvent,
    );
    LiveChannelFocus.pending.addListener(_onChannelFocusRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.trackLiveTVScreenOpened(surface: _analyticsSurface);
      _load();
    });
  }

  void _onChannelFocusRequested() {
    if (LiveChannelFocus.pending.value != null) _focusRequestedChannel();
  }

  /// Puts focus on the channel a link asked for, once the catalog is here to look it up in. A link
  /// that arrives while the catalog loads waits, and [_load] comes back to it.
  ///
  /// Every filter is cleared first, since the channel has to be in the grid to be focused. A channel
  /// the catalog does not list (a stale cache, say) is tried by id instead, so the link still does
  /// what it would have done before the list could show it.
  void _focusRequestedChannel() {
    if (!mounted || _loading) return;
    final request = LiveChannelFocus.take();
    if (request == null) return;
    final id = request.channelId;
    final channel = _channels.where((item) => item.id == id).firstOrNull;
    if (channel == null) {
      if (_resolvingId == null) _play(Channel(id: id, name: id));
      return;
    }
    _searchController.clear();
    setState(() {
      _mode = _TvLiveMode.channels;
      _scope = _TvLiveScope.all;
      _category = null;
      _letter = null;
      _query = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _channelGrid.requestFocus(itemId: id);
    });
  }

  bool _requestContentFocus() {
    // The grid is not built until the catalog arrives; it takes the request
    // then, unless focus has moved on.
    if (_loading && _channels.isEmpty) return _channelGrid.requestFocus();
    if (_mode == _TvLiveMode.channels &&
        _visible.isNotEmpty &&
        _channelGrid.requestFocus()) {
      return true;
    }
    if (_browseFocus.context == null) return false;
    _browseFocus.requestFocus();
    return true;
  }

  KeyEventResult _handleSearchKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
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

  @override
  void didUpdateWidget(TvLiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusController, widget.focusController)) {
      oldWidget.focusController?.detach(this);
      widget.focusController?.attach(this, _requestContentFocus);
    }
  }

  @override
  void dispose() {
    LiveChannelFocus.pending.removeListener(_onChannelFocusRequested);
    widget.focusController?.detach(this);
    _searchAnalyticsDebounce?.cancel();
    _service?.close();
    // EthioTV source (commented out - disabled):
    // _ethioService?.close();
    _searchController.dispose();
    _searchFocus.dispose();
    _browseFocus.dispose();
    super.dispose();
  }

  DaddyLiveService _api() => _service ??= DaddyLiveService(
        baseUrl: context.read<AppDependencyProvider>().flixquestAPIURL,
      );

  // EthioTV source (commented out - disabled):
  // EthioSportsService _ethioApi() => _ethioService ??= EthioSportsService(
  //       baseUrl: context.read<AppDependencyProvider>().flixquestAPIURLV2,
  //     );
  //
  // LiveTvService get _activeService =>
  //     _source == _TvLiveSource.ethioSports ? _ethioApi() : _api();
  //
  // LiveTVDatabaseController get _database =>
  //     _source == _TvLiveSource.ethioSports ? _ethioDatabase : _daddyDatabase;

  AnalyticsService get _analytics => context.read<SettingsProvider>().analytics;

  Future<void> _load({bool refresh = false}) async {
    final stopwatch = Stopwatch()..start();
    var cacheHit = false;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final favorites = await _daddyDatabase.getFavoriteIds();
      final recent = await _daddyDatabase.getRecentIds();
      List<Channel> channels;
      DaddyLiveEpg? epg;
      if (!refresh && await _daddyDatabase.isCacheValid()) {
        cacheHit = true;
        channels = await _daddyDatabase.getCachedChannels();
        epg = await _daddyDatabase.getCachedEpg();
      } else {
        final catalog = await _api().getCatalog(refresh: refresh);
        channels = catalog.channels;
        epg = catalog.epg;
        await _daddyDatabase.cacheChannels(channels);
        await _daddyDatabase.cacheEpg(epg);
      }
      channels = channels.toList()..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _epg = epg;
        _favorites = favorites;
        _recent = recent;
        _loading = false;
      });
      _analytics.trackLiveTVCatalogLoad(
        surface: _analyticsSurface,
        refresh: refresh,
        cacheHit: cacheHit,
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
        channelCount: channels.length,
        epgDayCount: epg?.days.length ?? 0,
      );
    } catch (error) {
      final cached = await _daddyDatabase.getCachedChannels();
      final cachedEpg = await _daddyDatabase.getCachedEpg();
      if (!mounted) return;
      setState(() {
        _channels = cached;
        _epg = cachedEpg;
        _loading = false;
        _error = cached.isEmpty ? friendlyLiveTvError(error) : null;
      });
      _analytics.trackLiveTVCatalogLoad(
        surface: _analyticsSurface,
        refresh: refresh,
        cacheHit: cacheHit,
        success: false,
        fallbackToCache: cached.isNotEmpty,
        durationMs: stopwatch.elapsedMilliseconds,
        channelCount: cached.length,
        epgDayCount: cachedEpg?.days.length ?? 0,
        error: error.toString(),
      );
    } finally {
      _focusRequestedChannel();
    }
  }

  List<String> get _categories {
    final categories = _channels.expand((item) => item.categories).toSet();
    return categories.toList()..sort();
  }

  /// Channels matching every filter except the letter, which indexes them.
  List<Channel> get _unlettered {
    Iterable<Channel> result = _channels;
    if (_scope == _TvLiveScope.favorites) {
      result = result.where((item) => _favorites.contains(item.id));
    } else if (_scope == _TvLiveScope.recent) {
      final byId = <String, Channel>{for (final item in result) item.id: item};
      result = _recent.map((id) => byId[id]).whereType<Channel>();
    }
    if (_category != null) {
      result = result.where((item) => item.categories.contains(_category));
    }
    final tokens = searchTokens(_query);
    if (tokens.isNotEmpty) {
      result = result.where((item) => _matches(item, tokens));
    }
    return result.toList(growable: false);
  }

  List<String> get _letters => channelLetters(_unlettered);

  /// The chosen letter, or null when no channel under it survives the other
  /// filters.
  String? get _activeLetter {
    final letter = _letter;
    if (letter == null) return null;
    return _letters.contains(letter) ? letter : null;
  }

  List<Channel> get _visible {
    final channels = _unlettered;
    final letter = _activeLetter;
    if (letter == null) return channels;
    return channels
        .where((channel) => channelLetter(channel) == letter)
        .toList(growable: false);
  }

  static bool _matches(Channel channel, List<String> tokens) {
    // 24/7 channels match by their own identity only (name / id), never by
    // the event that happens to be airing. Use the Schedule search for teams.
    final haystack = normalizeSearchText('${channel.name} ${channel.id}');
    return tokens.every(haystack.contains);
  }

  static bool _eventMatches(
    DaddyLiveEpgEvent event,
    String categoryName,
    List<String> tokens,
  ) {
    final haystack = normalizeSearchText(
      '$categoryName ${event.title} '
      '${event.channels.map((channel) => channel.name).join(' ')}',
    );
    return tokens.every(haystack.contains);
  }

  List<LiveSportSection> get _sportSections {
    final epg = _epg;
    if (epg == null || epg.days.isEmpty) return const <LiveSportSection>[];
    return groupScheduleBySport(
      epg.days[_selectedDayIndex.clamp(0, epg.days.length - 1)],
    );
  }

  /// The chosen sport, or null when it is not on the selected day.
  String? get _activeSport {
    final sport = _sport;
    if (sport == null) return null;
    return _sportSections.any((section) => section.name == sport)
        ? sport
        : null;
  }

  List<LiveSportSection> get _scheduleSections {
    final sport = _activeSport;
    final tokens = searchTokens(_query);
    return <LiveSportSection>[
      for (final section in _sportSections)
        if (sport == null || section.name == sport)
          LiveSportSection(
            name: section.name,
            emoji: section.emoji,
            events: tokens.isEmpty
                ? section.events
                : section.events
                    .where(
                        (event) => _eventMatches(event, section.name, tokens))
                    .toList(growable: false),
          ),
    ]..removeWhere((section) => section.events.isEmpty);
  }

  int get _visibleEventCount =>
      _scheduleSections.fold(0, (sum, section) => sum + section.events.length);

  Future<void> _toggleFavorite(Channel channel) async {
    final value = await _daddyDatabase.toggleFavorite(channel.id);
    if (!mounted) return;
    setState(() {
      if (value) {
        _favorites.add(channel.id);
      } else {
        _favorites.remove(channel.id);
      }
    });
    _analytics.trackLiveTVFavorite(
      surface: _analyticsSurface,
      channelId: channel.id,
      channelName: channel.name,
      added: value,
    );
  }

  Future<void> _play(Channel channel) async {
    setState(() => _resolvingId = channel.id);
    final stopwatch = Stopwatch()..start();
    try {
      final stream = await _api().getStream(channel.id);
      await _daddyDatabase.addRecent(channel.id);
      if (!mounted) return;
      _analytics.trackLiveTVChannelView(
        channelName: channel.name,
        streamId: channel.id,
      );
      _analytics.trackLiveTVStreamResolution(
        surface: _analyticsSurface,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        source: _mode.name,
      );
      if (!mounted) return;
      // The channel works: the TV's stream-found popup, first.
      if (!await AdsterraPlaybackAdsService.instance
              .streamFound(context, television: true) ||
          !mounted) {
        return;
      }
      final theme = Theme.of(context);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TvPlayerScreen(
            child: LivePlayer(
              channelName: channel.name,
              videoUrl: stream.url,
              headers: stream.headers,
              mediaType: stream.mediaType,
              clearKey: stream.clearKey,
              variants: stream.variants,
              autoFullScreen: false,
              colors: <Color>[
                theme.colorScheme.primary,
                Colors.black,
              ],
              // Keep in-player switching independent from browse filters.
              channels: _channels,
              initialChannelId: channel.id,
              service: _api(),
              analytics: _analytics,
              analyticsSurface: _analyticsSurface,
              scraperApiUrl:
                  context.read<AppDependencyProvider>().flixquestAPIURL,
              onChannelSwitch: (switched) =>
                  _daddyDatabase.addRecent(switched.id),
              enableCast: false,
              useTvControls: true,
            ),
          ),
        ),
      );
      _recent = await _daddyDatabase.getRecentIds();
      if (mounted) setState(() {});
    } catch (error) {
      _analytics.trackLiveTVStreamResolution(
        surface: _analyticsSurface,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'error',
        durationMs: stopwatch.elapsedMilliseconds,
        source: _mode.name,
        error: error.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyLiveTvError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _resolvingId = null);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchAnalyticsDebounce?.cancel();
    _searchAnalyticsDebounce = Timer(const Duration(milliseconds: 750), () {
      if (!mounted || value != _query) return;
      _analytics.trackLiveTVInteraction(
        surface: _analyticsSurface,
        action: 'search',
        value: _mode.name,
        resultCount: _mode == _TvLiveMode.channels
            ? _visible.length
            : _visibleEventCount,
      );
    });
  }

  void _focusFirstChannelResult() {
    if (_mode != _TvLiveMode.channels || _visible.isEmpty) return;
    _channelGrid.requestFocus();
  }

  void _selectMode(_TvLiveMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'view_changed',
      value: mode.name,
    );
  }

  // EthioTV source (commented out - disabled):
  // void _selectSource(_TvLiveSource source) {
  //   if (source == _source) return;
  //   setState(() {
  //     _source = source;
  //     _mode = _TvLiveMode.channels;
  //     _category = null;
  //     _selectedDayIndex = 0;
  //     _channels = const <Channel>[];
  //     _epg = null;
  //   });
  //   _load();
  // }

  void _selectScope(_TvLiveScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'collection_changed',
      value: scope.name,
      resultCount: _visible.length,
    );
  }

  void _selectLetter(String? letter) {
    if (letter == _activeLetter) return;
    setState(() => _letter = letter);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'letter_changed',
      value: letter ?? 'all',
      resultCount: _visible.length,
    );
  }

  void _selectCategory(String? category) {
    if (category == _category) return;
    setState(() => _category = category);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'category_changed',
      value: category ?? 'all',
      resultCount: _visible.length,
    );
  }

  String _eventKey(String section, DaddyLiveEpgEvent event) =>
      '$_selectedDayIndex|$section|${event.time}|${event.title}';

  void _toggleEvent(String key) {
    setState(() {
      if (!_expandedEvents.remove(key)) _expandedEvents.add(key);
    });
  }

  void _selectSport(String? sport) {
    if (sport == _activeSport) return;
    setState(() => _sport = sport);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'schedule_sport_changed',
      value: sport ?? 'all',
      resultCount: _visibleEventCount,
    );
  }

  void _selectDay(int index) {
    if (index == _selectedDayIndex) return;
    setState(() => _selectedDayIndex = index);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'schedule_day_changed',
      value: _epg?.days[index].label,
      resultCount: _visibleEventCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _channels.isEmpty) {
      return TvLiveSkeleton(metrics: widget.metrics);
    }
    if (_error != null) return _buildError();
    final isSchedule = _mode == _TvLiveMode.schedule;
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.metrics.contentPadding,
          0,
          widget.metrics.contentPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildTitle(isSchedule),
            SizedBox(height: widget.metrics.compact ? 8 : 12),
            _buildControls(isSchedule),
            if (!isSchedule && _categories.isNotEmpty) ...<Widget>[
              SizedBox(height: widget.metrics.compact ? 4 : 8),
              _buildCategories(),
            ],
            if (!isSchedule && _letters.length > 1) ...<Widget>[
              const SizedBox(height: 4),
              _buildLetters(),
            ],
            if (isSchedule &&
                _epg != null &&
                _epg!.days.isNotEmpty) ...<Widget>[
              SizedBox(height: widget.metrics.compact ? 4 : 8),
              _buildDays(),
              if (_sportSections.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                _buildSports(),
              ],
            ],
            SizedBox(height: widget.metrics.compact ? 4 : 8),
            Expanded(
              child: isSchedule ? _buildSchedule() : _buildGrid(),
            ),
            // A thin strip under the list stays on screen while the viewer
            // browses and only takes one banner's height from the grid.
            const BannerAdSlot(
              placement: 'live_tv_strip',
              variant: HostedBannerVariant.standard,
              padding: EdgeInsets.only(top: 8, bottom: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// One line: title, the LIVE NOW / PROGRAM GUIDE badge and the count, so
  /// the grid starts a full row higher than with a stacked header.
  Widget _buildTitle(bool isSchedule) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Text(
          isSchedule ? 'Schedule' : 'Live TV',
          style: TextStyle(
            color: palette.foreground,
            fontFamily: 'FigtreeSB',
            fontSize: 34,
            height: .95,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(width: 16),
        if (!isSchedule) ...<Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xffe50914),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          isSchedule ? 'PROGRAM GUIDE' : 'LIVE NOW',
          style: TextStyle(
            color: isSchedule ? colors.primary : const Color(0xfff05a62),
            fontFamily: 'FigtreeSB',
            fontSize: 12,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            isSchedule
                ? '$_visibleEventCount events  •  Select an event to watch'
                : '${_visible.length} channels  •  Hold OK to save a favorite',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        TvFocusable(
          focusNode: _browseFocus,
          semanticLabel: 'Search channels',
          selected: _showSearch,
          onActivate: () {
            setState(() => _showSearch = !_showSearch);
            if (_showSearch) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _searchFocus.requestFocus();
              });
            }
          },
          child:
              _TvPill(icon: PhosphorIcons.magnifyingGlass(), label: 'Search'),
        ),
        const SizedBox(width: 8),
        TvFocusable(
          semanticLabel: 'Refresh live TV',
          onActivate: () => _load(refresh: true),
          focusScale: 1.025,
          child: _TvPill(
            icon: PhosphorIcons.arrowsClockwise(),
            label: 'Refresh',
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isSchedule) {
    final palette = TvPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // EthioTV source (commented out - disabled):
        // _TvSegmentedTrack(
        //   fill: true,
        //   options: <_TvSegmentedOption>[
        //     _TvSegmentedOption(
        //       icon: PhosphorIcons.broadcast(),
        //       label: 'DaddyLive',
        //       semanticLabel: 'DaddyLive source',
        //       selected: _source == _TvLiveSource.daddyLive,
        //       onActivate: () => _selectSource(_TvLiveSource.daddyLive),
        //     ),
        //     _TvSegmentedOption(
        //       icon: PhosphorIcons.football(),
        //       label: 'Ethio Sports',
        //       semanticLabel: 'Ethio Sports source',
        //       selected: _source == _TvLiveSource.ethioSports,
        //       onActivate: () => _selectSource(_TvLiveSource.ethioSports),
        //     ),
        //   ],
        // ),
        // const SizedBox(height: 8),
        _buildModeTracks(isSchedule),
        if (_showSearch) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _focusFirstChannelResult(),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: palette.foreground,
                fontSize: 20,
              ),
              decoration: InputDecoration(
                hintText: isSchedule
                    ? 'Search matches, teams & leagues'
                    : 'Search channels',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          _searchFocus.requestFocus();
                        },
                        icon: Icon(PhosphorIcons.x()),
                      ),
                filled: true,
                fillColor: palette.raisedSurface,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                  borderSide: BorderSide(color: palette.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvDesign.cardRadius),
                  borderSide: BorderSide(color: palette.foreground, width: 2),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeTracks(bool isSchedule) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Row(
        children: <Widget>[
          _TvSegmentedTrack(
            options: <_TvSegmentedOption>[
              _TvSegmentedOption(
                icon: PhosphorIcons.televisionSimple(),
                label: 'Channels',
                semanticLabel: 'Channels view',
                selected: _mode == _TvLiveMode.channels,
                onActivate: () => _selectMode(_TvLiveMode.channels),
              ),
              _TvSegmentedOption(
                icon: PhosphorIcons.calendarDots(),
                label: 'Schedule',
                semanticLabel: 'Schedule view',
                selected: _mode == _TvLiveMode.schedule,
                onActivate: () => _selectMode(_TvLiveMode.schedule),
              ),
            ],
          ),
          if (!isSchedule) ...<Widget>[
            const SizedBox(width: 28),
            _TvSegmentedTrack(
              options: <_TvSegmentedOption>[
                _TvSegmentedOption(
                  icon: PhosphorIcons.broadcast(),
                  label: 'All',
                  semanticLabel: 'All channels',
                  selected: _scope == _TvLiveScope.all,
                  onActivate: () => _selectScope(_TvLiveScope.all),
                ),
                _TvSegmentedOption(
                  icon: PhosphorIcons.heart(),
                  label: 'Favorites',
                  semanticLabel: 'Favorites channels',
                  selected: _scope == _TvLiveScope.favorites,
                  onActivate: () => _selectScope(_TvLiveScope.favorites),
                ),
                _TvSegmentedOption(
                  icon: PhosphorIcons.clockCounterClockwise(),
                  label: 'Recent',
                  semanticLabel: 'Recent channels',
                  selected: _scope == _TvLiveScope.recent,
                  onActivate: () => _selectScope(_TvLiveScope.recent),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          TvFocusable(
            semanticLabel: 'All categories',
            selected: _category == null,
            onActivate: () => _selectCategory(null),
            focusScale: 1.025,
            child:
                _TvPill(label: 'All categories', selected: _category == null),
          ),
          for (final category in _categories) ...<Widget>[
            const SizedBox(width: 6),
            TvFocusable(
              semanticLabel: '$category category',
              selected: _category == category,
              onActivate: () => _selectCategory(category),
              focusScale: 1.025,
              child: _TvPill(
                label: category,
                selected: _category == category,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLetters() {
    final active = _activeLetter;
    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          TvFocusable(
            semanticLabel: 'All letters',
            selected: active == null,
            onActivate: () => _selectLetter(null),
            focusScale: 1.025,
            child: _TvPill(label: 'A–Z', selected: active == null),
          ),
          for (final letter in _letters) ...<Widget>[
            const SizedBox(width: 4),
            TvFocusable(
              semanticLabel: letter == channelLetterOther
                  ? 'Channels starting with a number or symbol'
                  : 'Channels starting with $letter',
              selected: active == letter,
              onActivate: () => _selectLetter(letter),
              focusScale: 1.025,
              child: _TvPill(label: letter, selected: active == letter),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDays() {
    final days = _epg!.days;
    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (var i = 0; i < days.length; i++) ...<Widget>[
            if (i != 0) const SizedBox(width: 6),
            TvFocusable(
              semanticLabel: '${_prettyDayLabel(days[i].label)} schedule',
              selected: _selectedDayIndex == i,
              onActivate: () => _selectDay(i),
              focusScale: 1.025,
              child: _TvPill(
                label: _prettyDayLabel(days[i].label),
                selected: _selectedDayIndex == i,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSports() {
    final sections = _sportSections;
    final active = _activeSport;
    return SizedBox(
      height: 44,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          TvFocusable(
            semanticLabel: 'All sports',
            selected: active == null,
            onActivate: () => _selectSport(null),
            focusScale: 1.025,
            child: _TvPill(label: 'All sports', selected: active == null),
          ),
          for (final section in sections) ...<Widget>[
            const SizedBox(width: 6),
            TvFocusable(
              semanticLabel: '${section.name}, ${section.events.length} events',
              selected: active == section.name,
              onActivate: () => _selectSport(section.name),
              focusScale: 1.025,
              child: _TvPill(
                label: section.label,
                selected: active == section.name,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _prettyDayLabel(String label) {
    final parsed = DateTime.tryParse(label);
    if (parsed == null) return label;
    return DateFormat('EEE, MMM d').format(parsed);
  }

  Widget _buildGrid() {
    final channels = _visible;
    if (channels.isEmpty) {
      return TvStatePanel(
        title: 'No channels found',
        message: 'Try another search, category, or collection.',
        icon: PhosphorIcons.televisionSimple(),
      );
    }
    return TvContentGrid<Channel>(
      controller: _channelGrid,
      scopeId:
          'live-${_scope.name}-${_category ?? 'all'}-${_activeLetter ?? 'all'}-$_query',
      items: channels,
      itemId: (channel) => channel.id,
      semanticLabel: (channel) =>
          'Watch ${channel.name}. Hold OK for favorites.',
      // Upstream never ships channel artwork, so cards are text-only rows.
      targetItemWidth: widget.metrics.compact ? 200 : 240,
      itemExtent: widget.metrics.compact ? 70 : 76,
      horizontalSpacing: widget.metrics.compact ? 10 : 14,
      verticalSpacing: widget.metrics.compact ? 12 : 18,
      onItemActivated: (channel) {
        if (_resolvingId == null) _play(channel);
      },
      onItemMenu: (channel) => showTvDialog<void>(
        context: context,
        title: channel.name,
        content: const Text('Channel options'),
        actions: [
          TvDialogAction(
            label: _favorites.contains(channel.id)
                ? 'Remove from favorites'
                : 'Add to favorites',
            onPressed: () {
              Navigator.of(context).pop();
              _toggleFavorite(channel);
            },
          ),
          TvDialogAction(
              label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      itemBuilder: (_, channel, width) => _TvChannelCard(
        channel: channel,
        favorite: _favorites.contains(channel.id),
        resolving: _resolvingId == channel.id,
      ),
    );
  }

  Widget _buildSchedule() {
    final palette = TvPalette.of(context);
    final sections = _scheduleSections;
    if (sections.isEmpty) {
      return TvStatePanel(
        title: _epg?.days.isNotEmpty ?? false
            ? 'No matches found'
            : 'Schedule unavailable',
        message: _epg?.days.isNotEmpty ?? false
            ? 'Try another team, league, or day.'
            : "Refresh to load today's schedule.",
        icon: PhosphorIcons.calendarDots(),
        actionLabel: (_epg?.days.isNotEmpty ?? false) ? null : 'Refresh',
        onAction: (_epg?.days.isNotEmpty ?? false)
            ? null
            : () => _load(refresh: true),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(3, 3, 12, 32),
      itemCount: sections.length,
      itemBuilder: (_, sectionIndex) {
        final section = sections[sectionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 13, 4, 9),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeSB',
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Text(
                    '${section.events.length} ${section.events.length == 1 ? 'event' : 'events'}',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            for (final event in section.events)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Builder(builder: (_) {
                  final key = _eventKey(section.name, event);
                  return _TvScheduleEventTile(
                    event: event,
                    expanded: _expandedEvents.contains(key),
                    onToggle: () => _toggleEvent(key),
                    resolvingChannelId: _resolvingId,
                    onPlay: _play,
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  Widget _buildError() {
    return TvStatePanel.error(
      onRetry: _load,
      message: _error ?? 'Live TV is currently unavailable.',
    );
  }
}

class _TvSegmentedOption {
  const _TvSegmentedOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onActivate,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback onActivate;
}

class _TvSegmentedTrack extends StatelessWidget {
  // EthioTV source (commented out - disabled): full-width `fill: true` tracks
  // were only used by the Ethio source selector.
  const _TvSegmentedTrack({required this.options});

  final List<_TvSegmentedOption> options;

  // EthioTV source (commented out - disabled):
  // final bool fill;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      for (var index = 0; index < options.length; index++)
        Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: TvFocusable(
            semanticLabel: options[index].semanticLabel ?? options[index].label,
            selected: options[index].selected,
            onActivate: options[index].onActivate,
            focusScale: 1,
            borderRadius:
                const BorderRadius.all(Radius.circular(TvDesign.cardRadius)),
            child: _TvSegmentCell(
              icon: options[index].icon,
              label: options[index].label,
              selected: options[index].selected,
            ),
          ),
        ),
    ];
    return Row(mainAxisSize: MainAxisSize.min, children: cells);
  }
}

class _TvSegmentCell extends StatelessWidget {
  const _TvSegmentCell({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? palette.foreground : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            size: 19,
            color: selected ? palette.foreground : palette.mutedText,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.foreground,
              fontFamily: selected ? 'FigtreeSB' : 'Figtree',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _TvPill extends StatelessWidget {
  const _TvPill({required this.label, this.icon, this.selected = false});

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: selected ? palette.foreground : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 20,
              color: selected ? palette.foreground : palette.mutedText,
            ),
            if (label.isNotEmpty) const SizedBox(width: 8),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: palette.foreground,
                fontFamily: selected ? 'FigtreeSB' : 'Figtree',
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _TvScheduleEventTile extends StatefulWidget {
  const _TvScheduleEventTile({
    required this.event,
    required this.expanded,
    required this.onToggle,
    required this.resolvingChannelId,
    required this.onPlay,
  });

  final DaddyLiveEpgEvent event;
  final bool expanded;
  final VoidCallback onToggle;
  final String? resolvingChannelId;
  final void Function(Channel channel) onPlay;

  @override
  State<_TvScheduleEventTile> createState() => _TvScheduleEventTileState();
}

class _TvScheduleEventTileState extends State<_TvScheduleEventTile> {
  // Left edge of the title column, so revealed channels line up under it.
  static const double _contentInset = 16 + 86 + 1 + 18;

  final _headerFocus = FocusNode(debugLabel: 'Schedule event');
  final _firstChannelFocus = FocusNode(debugLabel: 'Schedule event channel');

  @override
  void dispose() {
    _headerFocus.dispose();
    _firstChannelFocus.dispose();
    super.dispose();
  }

  static bool _isPress(KeyEvent event, LogicalKeyboardKey key) =>
      (event is KeyDownEvent || event is KeyRepeatEvent) &&
      event.logicalKey == key;

  // Directional traversal keeps vertical moves inside the schedule's own
  // scrollable, so it never lands on the nested horizontal channel row.
  // Bridge header <-> channels explicitly.
  KeyEventResult _handleHeaderKey(FocusNode node, KeyEvent event) {
    if (!widget.expanded ||
        widget.event.channels.isEmpty ||
        !_isPress(event, LogicalKeyboardKey.arrowDown) ||
        _firstChannelFocus.context == null) {
      return KeyEventResult.ignored;
    }
    _firstChannelFocus.requestFocus();
    return KeyEventResult.handled;
  }

  KeyEventResult _handleChannelKey(FocusNode node, KeyEvent event) {
    if (!_isPress(event, LogicalKeyboardKey.arrowUp)) {
      return KeyEventResult.ignored;
    }
    _headerFocus.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final event = widget.event;
    final expanded = widget.expanded;
    final channelCount = event.channels.length;
    final showChannels = expanded && channelCount > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TvFocusable(
            semanticLabel: '${event.title}, $channelCount '
                '${channelCount == 1 ? 'channel' : 'channels'}, '
                '${expanded ? 'expanded' : 'collapsed'}',
            focusNode: _headerFocus,
            enabled: channelCount > 0,
            selected: expanded,
            onActivate: widget.onToggle,
            onKeyEvent: _handleHeaderKey,
            focusScale: 1,
            borderRadius:
                const BorderRadius.all(Radius.circular(TvDesign.cardRadius)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 86,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          event.displayTime,
                          style: TextStyle(
                            color: palette.foreground,
                            fontFamily: 'FigtreeSB',
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xffe50914),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontFamily: 'FigtreeSB',
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: palette.hairline),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.foreground,
                        fontFamily: 'FigtreeSB',
                        fontSize: 19,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '$channelCount ${channelCount == 1 ? 'channel' : 'channels'}',
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: 14,
                    ),
                  ),
                  if (channelCount > 0) ...<Widget>[
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 24,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showChannels
                ? SizedBox(
                    height: 42 + 4 + 12,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(
                        _contentInset - 2,
                        2,
                        16,
                        14,
                      ),
                      itemCount: channelCount,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => _TvScheduleChannelChip(
                        channel: event.channels[index],
                        focusNode: index == 0 ? _firstChannelFocus : null,
                        onKeyEvent: _handleChannelKey,
                        resolving: widget.resolvingChannelId ==
                            event.channels[index].id,
                        onPlay: widget.onPlay,
                        primary: palette.foreground,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _TvScheduleChannelChip extends StatelessWidget {
  const _TvScheduleChannelChip({
    required this.channel,
    required this.resolving,
    required this.onPlay,
    required this.primary,
    this.focusNode,
    this.onKeyEvent,
  });

  final Channel channel;
  final bool resolving;
  final void Function(Channel channel) onPlay;
  final Color primary;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    return TvFocusable(
      semanticLabel: 'Watch on ${channel.name}',
      focusNode: focusNode,
      onKeyEvent: onKeyEvent,
      enabled: !resolving,
      onActivate: () => onPlay(channel),
      focusScale: 1,
      borderRadius: const BorderRadius.all(
        Radius.circular(TvDesign.cardRadius),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: palette.idleFill,
          borderRadius: BorderRadius.circular(TvDesign.cardRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (resolving)
              SizedBox.square(
                dimension: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primary,
                ),
              )
            else
              Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: palette.foreground,
              ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.foreground,
                  fontFamily: 'FigtreeSB',
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvChannelCard extends StatelessWidget {
  const _TvChannelCard(
      {required this.channel, required this.favorite, required this.resolving});
  final Channel channel;
  final bool favorite;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final palette = TvPalette.of(context);
    final secondaryLabel = channel.nowPlaying ??
        channel.nextUp ??
        (channel.categories.isEmpty
            ? 'Live channel'
            : channel.categories.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(TvDesign.cardRadius),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xffe50914),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.foreground,
                          fontFamily: 'FigtreeSB',
                          fontSize: 16,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Text(
                    resolving ? 'Opening channel…' : secondaryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: resolving ? palette.foreground : palette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (resolving) ...<Widget>[
            const SizedBox(width: 10),
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.foreground,
              ),
            ),
          ] else if (favorite) ...<Widget>[
            const SizedBox(width: 10),
            Icon(
              PhosphorIcons.heart(PhosphorIconsStyle.fill),
              size: 16,
              color: palette.foreground,
            ),
          ],
        ],
      ),
    );
  }
}
