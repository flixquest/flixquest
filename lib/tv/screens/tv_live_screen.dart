import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../controllers/live_tv_database_controller.dart';
import '../../functions/function.dart';
import '../../functions/live_channel_letters.dart';
import '../../functions/live_schedule_sports.dart';
import '../../functions/live_sport_preferences.dart';
import '../../models/live_tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/live_player.dart';
import '../../services/adsterra_playback_ads_service.dart';
import '../../services/analytics_service.dart';
import '../../services/daddylive_service.dart';
import '../../services/live_channel_focus.dart';
import '../../services/live_tv_source.dart';
import '../../widgets/hosted_ads_banner.dart';
import '../app/tv_design.dart';
import '../focus/tv_focusable.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../player/tv_player_screen.dart';
import '../widgets/tv_state_panel.dart';
import '../widgets/tv_content_grid.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_loading_skeletons.dart';
import '../widgets/tv_search_keyboard.dart';
import '../widgets/tv_sport_picker.dart';

enum _TvLiveScope { all, favorites, recent }

enum _TvLiveMode { channels, schedule }

class TvLiveScreen extends StatefulWidget {
  const TvLiveScreen({required this.metrics, this.focusController, super.key});

  final TvShellMetrics metrics;
  final TvScreenFocusController? focusController;

  @override
  State<TvLiveScreen> createState() => _TvLiveScreenState();
}

class _TvLiveScreenState extends State<TvLiveScreen> {
  static const _analyticsSurface = 'tv';
  static final _backKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.browserBack,
  };
  // The sports followed are the viewer's, whichever source is showing.
  final _sportsDatabase = LiveTvSource.daddyLive.database();
  final _databases = <LiveTvSource, LiveTVDatabaseController>{};
  final _services = <LiveTvSource, LiveTvService>{};
  final GlobalKey<TvSearchKeyboardState> _keyboard =
      GlobalKey<TvSearchKeyboardState>();
  final _channelGrid = TvContentGridController();
  final _browseFocus = FocusNode(debugLabel: 'Live TV browse controls');
  bool _showSearch = false;
  List<Channel> _channels = const <Channel>[];
  DaddyLiveEpg? _epg;
  Set<String> _favorites = <String>{};
  List<String> _recent = const <String>[];
  _TvLiveScope _scope = _TvLiveScope.all;
  _TvLiveMode _mode = _TvLiveMode.channels;
  LiveTvSource _source = LiveTvSource.daddyLive;
  String? _category;
  String? _letter;
  int _selectedDayIndex = 0;
  String? _sport;
  // Sports the viewer follows, by [LiveSport.id]; their sections lead the
  // schedule.
  Set<String> _preferredSports = <String>{};
  // Set once a link has asked for a channel, which the sports question must
  // not cover.
  bool _openedForChannel = false;
  // Schedule events start collapsed; keys come from [_eventKey].
  final Set<String> _expandedEvents = <String>{};
  String? _resolvingId;
  PlaybackAdPreload? _adPreload;
  String _query = '';
  String? _error;
  bool _loading = true;
  // Only the first load covers the screen; a source switched to later loads
  // under the controls, which keep the remote's focus.
  bool _loadedOnce = false;
  Timer? _searchAnalyticsDebounce;

  @override
  void initState() {
    super.initState();
    widget.focusController?.attach(this, _requestContentFocus);
    LiveChannelFocus.pending.addListener(_onChannelFocusRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A link opens the source its channel belongs to.
      final linked = LiveChannelFocus.pending.value?.channelId;
      final source = linked == null
          ? await LiveTvSource.lastUsed()
          : LiveTvSource.forChannel(linked);
      if (!mounted) return;
      setState(() => _source = source);
      _analytics.trackLiveTVScreenOpened(
        surface: _analyticsSurface,
        provider: source.analyticsName,
      );
      _load().then((_) => _askSports());
    });
  }

  /// Asks a first-time viewer which sports they follow, once the catalog is
  /// in. A link to a channel is not interrupted, and a failed load leaves the
  /// question for the next visit.
  Future<void> _askSports() async {
    if (!mounted || _openedForChannel || _error != null) return;
    if (await _sportsDatabase.getPreferredSports() != null || !mounted) return;
    if (_openedForChannel) return;
    await _editSports(firstTime: true);
  }

  /// Opens the sports picker. Backing out of it the first time counts as
  /// skipping, so the viewer is not asked on every visit.
  Future<void> _editSports({bool firstTime = false}) async {
    final picked = await showTvSportPicker(
      context,
      initial: _preferredSports,
      firstTime: firstTime,
    );
    if (!mounted || (picked == null && !firstTime)) return;
    final sports = picked ?? const <String>{};
    await _sportsDatabase.setPreferredSports(sports);
    if (!mounted) return;
    setState(() => _preferredSports = sports);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      provider: _source.analyticsName,
      action: 'preferred_sports_changed',
      value: sports.isEmpty ? 'none' : (sports.toList()..sort()).join(','),
      resultCount: sports.length,
    );
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
    final pending = LiveChannelFocus.pending.value;
    if (pending == null) return;
    // A channel from the other source is focused once that source loads.
    final source = LiveTvSource.forChannel(pending.channelId);
    if (source != _source) {
      _selectSource(source);
      return;
    }
    final request = LiveChannelFocus.take();
    if (request == null) return;
    _openedForChannel = true;
    final id = request.channelId;
    final channel = _channels.where((item) => item.id == id).firstOrNull;
    if (channel == null) {
      if (_resolvingId == null) _play(Channel(id: id, name: id));
      return;
    }
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
    if (_showSearch && _focusKeyboard()) return true;
    if (_browseFocus.context == null) return false;
    _browseFocus.requestFocus();
    return true;
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
    _adPreload?.dispose();
    LiveChannelFocus.pending.removeListener(_onChannelFocusRequested);
    widget.focusController?.detach(this);
    _searchAnalyticsDebounce?.cancel();
    for (final service in _services.values) {
      service.close();
    }
    _browseFocus.dispose();
    super.dispose();
  }

  LiveTvService _api() => _services[_source] ??= _source.createService(
        context.read<AppDependencyProvider>().flixquestAPIURL,
      );

  LiveTVDatabaseController get _database =>
      _databases[_source] ??= _source.database();

  AnalyticsService get _analytics => context.read<SettingsProvider>().analytics;

  Future<void> _load({bool refresh = false}) async {
    final stopwatch = Stopwatch()..start();
    // A load the viewer has since switched away from is dropped.
    final source = _source;
    final database = _database;
    var cacheHit = false;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final favorites = await database.getFavoriteIds();
    final recent = await database.getRecentIds();
    final preferredSports = await _sportsDatabase.getPreferredSports();
    try {
      List<Channel> channels;
      DaddyLiveEpg? epg;
      if (!refresh && await database.isCacheValid()) {
        cacheHit = true;
        channels = await database.getCachedChannels();
        epg = await database.getCachedEpg();
      } else {
        if (!mounted) return;
        final catalog = await _api().getCatalog(refresh: refresh);
        channels = catalog.channels;
        epg = catalog.epg;
        await database.cacheChannels(channels);
        await database.cacheEpg(epg);
      }
      channels = channels.toList()..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted || source != _source) return;
      setState(() {
        _channels = channels;
        _epg = epg;
        _favorites = favorites;
        _recent = recent;
        _preferredSports = preferredSports ?? <String>{};
        _loading = false;
        _loadedOnce = true;
      });
      _analytics.trackLiveTVCatalogLoad(
        surface: _analyticsSurface,
        provider: source.analyticsName,
        refresh: refresh,
        cacheHit: cacheHit,
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
        channelCount: channels.length,
        epgDayCount: epg?.days.length ?? 0,
      );
    } catch (error) {
      final cached = await database.getCachedChannels();
      final cachedEpg = await database.getCachedEpg();
      if (!mounted || source != _source) return;
      setState(() {
        _channels = cached;
        _epg = cachedEpg;
        _favorites = favorites;
        _recent = recent;
        _preferredSports = preferredSports ?? <String>{};
        _loading = false;
        _loadedOnce = true;
        _error = cached.isEmpty ? friendlyLiveTvError(error) : null;
      });
      _analytics.trackLiveTVCatalogLoad(
        surface: _analyticsSurface,
        provider: source.analyticsName,
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
    return prioritizeSportSections(
      groupScheduleBySport(
        epg.days[_selectedDayIndex.clamp(0, epg.days.length - 1)],
      ),
      _preferredSports,
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
    final source = _source;
    final value = await _database.toggleFavorite(channel.id);
    if (!mounted || source != _source) return;
    setState(() {
      if (value) {
        _favorites.add(channel.id);
      } else {
        _favorites.remove(channel.id);
      }
    });
    _analytics.trackLiveTVFavorite(
      surface: _analyticsSurface,
      provider: _source.analyticsName,
      channelId: channel.id,
      channelName: channel.name,
      added: value,
    );
  }

  Future<void> _play(Channel channel) async {
    if (_resolvingId != null) return;
    setState(() => _resolvingId = channel.id);
    // The source this channel came from, should the viewer switch meanwhile.
    final source = _source;
    final service = _api();
    final database = _database;
    _adPreload = AdsterraPlaybackAdsService.instance
        .preloadStreamFound(context, television: true);
    final stopwatch = Stopwatch()..start();
    try {
      final stream = await service.getStream(channel.id);
      await database.addRecent(channel.id);
      if (!mounted) return;
      _analytics.trackLiveTVChannelView(
        channelName: channel.name,
        streamId: channel.id,
      );
      _analytics.trackLiveTVStreamResolution(
        surface: _analyticsSurface,
        provider: source.analyticsName,
        channelId: channel.id,
        channelName: channel.name,
        outcome: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        source: _mode.name,
      );
      if (!mounted) return;
      // The channel works: the TV's stream-found popup, first.
      final proceed = await AdsterraPlaybackAdsService.instance
          .streamFound(context, television: true, preload: _adPreload);
      _adPreload?.dispose();
      _adPreload = null;
      if (!proceed || !mounted) return;
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
              streamDiscovery: stream.discovery,
              autoFullScreen: false,
              colors: <Color>[
                theme.colorScheme.primary,
                Colors.black,
              ],
              // Keep in-player switching independent from browse filters.
              channels: _channels,
              initialChannelId: channel.id,
              service: service,
              source: source,
              analytics: _analytics,
              analyticsSurface: _analyticsSurface,
              scraperApiUrl:
                  context.read<AppDependencyProvider>().flixquestAPIURL,
              onChannelSwitch: (switched) => database.addRecent(switched.id),
              enableCast: false,
              useTvControls: true,
            ),
          ),
        ),
      );
      final recent = await database.getRecentIds();
      if (mounted && source == _source) setState(() => _recent = recent);
    } catch (error) {
      _analytics.trackLiveTVStreamResolution(
        surface: _analyticsSurface,
        provider: source.analyticsName,
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
      _adPreload?.dispose();
      _adPreload = null;
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
        provider: _source.analyticsName,
        action: 'search',
        value: _mode.name,
        resultCount: _mode == _TvLiveMode.channels
            ? _visible.length
            : _visibleEventCount,
      );
    });
  }

  // The search keyboard.

  void _type(String character) {
    // A leading or doubled space is never what was meant.
    if (character == ' ' && (_query.isEmpty || _query.endsWith(' '))) return;
    _onSearchChanged('$_query$character');
  }

  void _deleteCharacter() {
    if (_query.isEmpty) return;
    _onSearchChanged(_query.substring(0, _query.length - 1));
  }

  void _clearQuery() {
    if (_query.isEmpty) return;
    _onSearchChanged('');
  }

  bool _focusKeyboard() => _keyboard.currentState?.requestFocus() ?? false;

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_showSearch) {
        _focusKeyboard();
      } else {
        _browseFocus.requestFocus();
      }
    });
  }

  /// Right off the keyboard: the channels, or in the schedule whatever sits
  /// beside the key.
  bool _focusResultsFromKeyboard() {
    if (_mode == _TvLiveMode.channels &&
        _visible.isNotEmpty &&
        _channelGrid.requestFocus()) {
      return true;
    }
    final focused = FocusManager.instance.primaryFocus;
    return focused != null &&
        focused.focusInDirection(TraversalDirection.right);
  }

  /// Up off the keyboard: the Search button that opened it.
  bool _focusSearchButton() {
    if (_browseFocus.context == null) return false;
    _browseFocus.requestFocus();
    return true;
  }

  /// Back on the keyboard closes it.
  KeyEventResult _handleKeyboardKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_backKeys.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _toggleSearch();
    return KeyEventResult.handled;
  }

  /// Left off the first column of channels, or off an event, returns to the
  /// key last used rather than whichever key happens to be level with it.
  /// A row of an event's channels steps through its own chips first.
  KeyEventResult _handleResultsKey(FocusNode node, KeyEvent event) {
    if (!_showSearch ||
        event.logicalKey != LogicalKeyboardKey.arrowLeft ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) return KeyEventResult.ignored;
    final scrollable = Scrollable.maybeOf(focusedContext);
    if (scrollable != null &&
        axisDirectionToAxis(scrollable.axisDirection) == Axis.horizontal) {
      return KeyEventResult.ignored;
    }
    // Holding Left stops at the edge instead of running into the keys.
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    return _focusKeyboard() ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void _selectMode(_TvLiveMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      provider: _source.analyticsName,
      action: 'view_changed',
      value: mode.name,
    );
  }

  /// Shows [source]'s channels and schedule in place of the current ones.
  /// The view and search stay; filters belonging to the old catalog go.
  void _selectSource(LiveTvSource source) {
    if (source == _source) return;
    setState(() {
      _source = source;
      _category = null;
      _letter = null;
      _sport = null;
      _selectedDayIndex = 0;
      _expandedEvents.clear();
      _channels = const <Channel>[];
      _epg = null;
    });
    unawaited(source.remember());
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      provider: source.analyticsName,
      action: 'source_changed',
      value: source.id,
    );
    _load();
  }

  void _selectScope(_TvLiveScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      provider: _source.analyticsName,
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
      provider: _source.analyticsName,
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
      provider: _source.analyticsName,
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
      provider: _source.analyticsName,
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
      provider: _source.analyticsName,
      action: 'schedule_day_changed',
      value: _epg?.days[index].label,
      resultCount: _visibleEventCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    if (_loading && !_loadedOnce) {
      return TvLiveSkeleton(metrics: widget.metrics);
    }
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
            // The keyboard docks beside everything under the title, so the
            // filters and the list narrow rather than move down.
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_showSearch) ...<Widget>[
                    _buildSearchDock(isSchedule),
                    SizedBox(width: widget.metrics.compact ? 18 : 28),
                  ],
                  Expanded(child: _buildBrowse(isSchedule)),
                ],
              ),
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

  Widget _buildBrowse(bool isSchedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildControls(isSchedule),
        if (!isSchedule && _categories.isNotEmpty) ...<Widget>[
          SizedBox(height: widget.metrics.compact ? 4 : 8),
          _buildCategories(),
        ],
        if (!isSchedule && _letters.length > 1) ...<Widget>[
          const SizedBox(height: 4),
          _buildLetters(),
        ],
        if (isSchedule && _epg != null && _epg!.days.isNotEmpty) ...<Widget>[
          SizedBox(height: widget.metrics.compact ? 4 : 8),
          _buildDays(),
          if (_sportSections.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _buildSports(),
          ],
        ],
        SizedBox(height: widget.metrics.compact ? 4 : 8),
        Expanded(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _handleResultsKey,
            child: _error != null
                ? _buildError()
                : _loading && _channels.isEmpty
                    ? Center(
                        child: Semantics(
                          label: tr('tv_loading_live_tv'),
                          child: const CircularProgressIndicator(),
                        ),
                      )
                    : isSchedule
                        ? _buildSchedule()
                        : _buildGrid(),
          ),
        ),
      ],
    );
  }

  /// What has been typed over the keyboard, sized to fit the height left
  /// between the title and the banner.
  Widget _buildSearchDock(bool isSchedule) {
    final compact = widget.metrics.compact;
    final dockWidth = compact ? 246.0 : 300.0;
    final fieldHeight = compact ? 44.0 : 50.0;
    final fieldGap = compact ? 12.0 : 18.0;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyboardKey,
      child: SizedBox(
        width: dockWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardWidth = TvSearchKeyboard.widthFor(
              constraints.maxHeight - fieldHeight - fieldGap - 8,
            ).clamp(150.0, dockWidth);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    height: fieldHeight,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: TvSearchQueryField(
                        query: _query,
                        hint: isSchedule
                            ? tr('tv_teams_and_leagues')
                            : tr('channels'),
                        compact: compact,
                      ),
                    ),
                  ),
                  SizedBox(height: fieldGap),
                  TvSearchKeyboard(
                    key: _keyboard,
                    width: keyboardWidth,
                    onType: _type,
                    onDelete: _deleteCharacter,
                    onClear: _clearQuery,
                    onExitRight: _focusResultsFromKeyboard,
                    onExitUp: _focusSearchButton,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// One line: title, the LIVE NOW / PROGRAM GUIDE badge and the count, so
  /// the grid starts a full row higher than with a stacked header.
  Widget _buildTitle(bool isSchedule) {
    final palette = TvPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    final shortQuery =
        _query.length > 14 ? '${_query.substring(0, 14)}…' : _query;
    final searchLabel = '“$shortQuery”';
    return Row(
      children: <Widget>[
        Text(
          isSchedule ? tr('schedule') : tr('live_tv'),
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
          isSchedule ? tr('tv_program_guide') : tr('tv_live_now'),
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
                ? tr('tv_live_events_summary', namedArgs: {
                    'events': plural('tv_events_count', _visibleEventCount,
                        name: 'count')
                  })
                : tr('tv_live_channels_summary', namedArgs: {
                    'channels': plural('tv_channels_count', _visible.length,
                        name: 'count')
                  }),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (isSchedule) ...<Widget>[
          TvFocusable(
            semanticLabel: tr('my_sports'),
            onActivate: _editSports,
            focusScale: 1.025,
            child: _TvPill(
              icon: _preferredSports.isEmpty
                  ? PhosphorIcons.star()
                  : PhosphorIcons.star(PhosphorIconsStyle.fill),
              label: tr('my_sports'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        TvFocusable(
          focusNode: _browseFocus,
          semanticLabel: tr('search_channels'),
          selected: _showSearch,
          onActivate: _toggleSearch,
          // A search left in place while the keyboard is closed still
          // filters, so it shows here.
          child: _TvPill(
            icon: PhosphorIcons.magnifyingGlass(),
            label: _showSearch || _query.isEmpty ? tr('search') : searchLabel,
            selected: _showSearch,
          ),
        ),
        const SizedBox(width: 8),
        TvFocusable(
          semanticLabel: tr('tv_refresh_live_tv'),
          onActivate: () => _load(refresh: true),
          focusScale: 1.025,
          child: _TvPill(
            icon: PhosphorIcons.arrowsClockwise(),
            label: tr('refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(bool isSchedule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildModeTracks(isSchedule),
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
              for (final source in LiveTvSource.values)
                _TvSegmentedOption(
                  icon: switch (source) {
                    LiveTvSource.daddyLive => PhosphorIcons.broadcast(),
                    LiveTvSource.ntv => PhosphorIcons.globeHemisphereWest(),
                  },
                  label: source.label,
                  semanticLabel: '${tr('live_tv_source')}: ${source.label}',
                  selected: _source == source,
                  onActivate: () => _selectSource(source),
                ),
            ],
          ),
          const SizedBox(width: 28),
          _TvSegmentedTrack(
            options: <_TvSegmentedOption>[
              _TvSegmentedOption(
                icon: PhosphorIcons.televisionSimple(),
                label: tr('channels'),
                semanticLabel: tr('tv_channels_view'),
                selected: _mode == _TvLiveMode.channels,
                onActivate: () => _selectMode(_TvLiveMode.channels),
              ),
              _TvSegmentedOption(
                icon: PhosphorIcons.calendarDots(),
                label: tr('schedule'),
                semanticLabel: tr('tv_schedule_view'),
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
                  label: tr('filter_all'),
                  semanticLabel: tr('tv_all_channels'),
                  selected: _scope == _TvLiveScope.all,
                  onActivate: () => _selectScope(_TvLiveScope.all),
                ),
                _TvSegmentedOption(
                  icon: PhosphorIcons.heart(),
                  label: tr('favorites'),
                  semanticLabel: tr('tv_favorites_channels'),
                  selected: _scope == _TvLiveScope.favorites,
                  onActivate: () => _selectScope(_TvLiveScope.favorites),
                ),
                _TvSegmentedOption(
                  icon: PhosphorIcons.clockCounterClockwise(),
                  label: tr('recent'),
                  semanticLabel: tr('tv_recent_channels'),
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
            semanticLabel: tr('all_categories'),
            selected: _category == null,
            onActivate: () => _selectCategory(null),
            focusScale: 1.025,
            child: _TvPill(
                label: tr('all_categories'), selected: _category == null),
          ),
          for (final category in _categories) ...<Widget>[
            const SizedBox(width: 6),
            TvFocusable(
              semanticLabel: tr('tv_category_semantics',
                  namedArgs: {'category': category}),
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
            semanticLabel: tr('tv_all_letters'),
            selected: active == null,
            onActivate: () => _selectLetter(null),
            focusScale: 1.025,
            child: _TvPill(label: 'A–Z', selected: active == null),
          ),
          for (final letter in _letters) ...<Widget>[
            const SizedBox(width: 4),
            TvFocusable(
              semanticLabel: letter == channelLetterOther
                  ? tr('tv_channels_starting_with_a_number_or_symbol')
                  : tr('tv_letter_channels', namedArgs: {'letter': letter}),
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
              semanticLabel: tr('tv_day_schedule',
                  namedArgs: {'day': _prettyDayLabel(days[i].label)}),
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
            semanticLabel: tr('all_sports'),
            selected: active == null,
            onActivate: () => _selectSport(null),
            focusScale: 1.025,
            child: _TvPill(label: tr('all_sports'), selected: active == null),
          ),
          for (final section in sections) ...<Widget>[
            const SizedBox(width: 6),
            TvFocusable(
              semanticLabel: tr('tv_section_events', namedArgs: {
                'section': section.label,
                'events': plural('tv_events_count', section.events.length,
                    name: 'count')
              }),
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
        title: tr('player_no_channels'),
        message: tr('tv_try_another_search_category_or_collection'),
        icon: PhosphorIcons.televisionSimple(),
      );
    }
    return TvContentGrid<Channel>(
      controller: _channelGrid,
      scopeId:
          'live-${_scope.name}-${_category ?? 'all'}-${_activeLetter ?? 'all'}-$_query',
      items: channels,
      itemId: (channel) => channel.id,
      semanticLabel: (channel) => tr('tv_watch_channel_favorites',
          namedArgs: {'channel': channel.name}),
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
        content: Text(tr('tv_channel_options')),
        actions: [
          TvDialogAction(
            label: _favorites.contains(channel.id)
                ? tr('remove_from_favorites')
                : tr('add_to_favorites'),
            onPressed: () {
              Navigator.of(context).pop();
              _toggleFavorite(channel);
            },
          ),
          TvDialogAction(
              label: tr('cancel'),
              onPressed: () => Navigator.of(context).pop()),
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
            ? tr('no_matches_found')
            : tr('schedule_unavailable'),
        message: _epg?.days.isNotEmpty ?? false
            ? tr('tv_try_another_team_league_or_day')
            : tr('tv_refresh_to_load_today_s_schedule'),
        icon: PhosphorIcons.calendarDots(),
        actionLabel: (_epg?.days.isNotEmpty ?? false) ? null : tr('refresh'),
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
                    plural('tv_events_count', section.events.length,
                        name: 'count'),
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
      message: _error ?? tr('tv_live_tv_is_currently_unavailable'),
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
  const _TvSegmentedTrack({required this.options});

  final List<_TvSegmentedOption> options;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
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
    Localizations.localeOf(context);
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
    Localizations.localeOf(context);
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
    Localizations.localeOf(context);
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
            semanticLabel: tr('tv_event_semantics', namedArgs: {
              'title': event.title,
              'channels':
                  plural('tv_channels_count', channelCount, name: 'count'),
              'state': tr(expanded ? 'tv_expanded' : 'tv_collapsed')
            }),
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
                              tr('player_live'),
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
                    plural('tv_channels_count', channelCount, name: 'count'),
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
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return TvFocusable(
      semanticLabel:
          tr('tv_watch_channel', namedArgs: {'channel': channel.name}),
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
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    final secondaryLabel = channel.nowPlaying ??
        channel.nextUp ??
        (channel.categories.isEmpty
            ? tr('tv_live_channel')
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
                    resolving ? tr('tv_opening_channel') : secondaryLabel,
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
