import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../services/daddylive_service.dart';
// EthioTV source (commented out - disabled):
// import '../../services/ethio_sports_service.dart';
import '../../services/analytics_service.dart';
import '../../ui_components/app_ui_components.dart';
import 'live_player.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

enum _ChannelScope { all, favorites, recent }

enum _LiveTvMode { channels, schedule }

// EthioTV source (commented out - disabled):
// enum _LiveTvSource { daddyLive, ethioSports }

const _allCategoriesKey = '__all_categories__';

class ChannelList extends StatefulWidget {
  const ChannelList({super.key});

  @override
  State<ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends State<ChannelList> {
  static const _analyticsSurface = 'standard';
  final _daddyDatabase = LiveTVDatabaseController();
  // EthioTV source (commented out - disabled):
  // final _ethioDatabase = LiveTVDatabaseController(namespace: 'ethiosports');
  final _searchController = TextEditingController();
  DaddyLiveService? _service;
  // EthioTV source (commented out - disabled):
  // EthioSportsService? _ethioService;
  List<Channel> _channels = const <Channel>[];
  DaddyLiveEpg? _epg;
  Set<String> _favoriteIds = <String>{};
  List<String> _recentIds = const <String>[];
  String? _selectedCategory;
  String? _letter;
  String? _resolvingId;
  String _query = '';
  String? _error;
  bool _loading = true;
  Timer? _searchAnalyticsDebounce;
  _ChannelScope _scope = _ChannelScope.all;
  _LiveTvMode _mode = _LiveTvMode.channels;
  // EthioTV source (commented out - disabled):
  // _LiveTvSource _source = _LiveTvSource.daddyLive;
  int _selectedDayIndex = 0;
  String? _sport;
  // Schedule events start collapsed; keys come from [_eventKey].
  final Set<String> _expandedEvents = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.trackLiveTVScreenOpened(surface: _analyticsSurface);
      _load();
    });
  }

  @override
  void dispose() {
    _searchAnalyticsDebounce?.cancel();
    _service?.close();
    // EthioTV source (commented out - disabled):
    // _ethioService?.close();
    _searchController.dispose();
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
  //     _source == _LiveTvSource.ethioSports ? _ethioApi() : _api();
  //
  // LiveTVDatabaseController get _database =>
  //     _source == _LiveTvSource.ethioSports ? _ethioDatabase : _daddyDatabase;

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
        await _daddyDatabase.cacheEpg(catalog.epg);
      }
      channels = channels.toList()..sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _epg = epg;
        _favoriteIds = favorites;
        _recentIds = recent;
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
    }
  }

  List<String> get _categories {
    final values = _channels.expand((channel) => channel.categories).toSet();
    return values.toList()..sort();
  }

  /// Channels matching every filter except the letter, which indexes them.
  List<Channel> get _unletteredChannels {
    Iterable<Channel> result = _channels;
    if (_scope == _ChannelScope.favorites) {
      result = result.where((channel) => _favoriteIds.contains(channel.id));
    } else if (_scope == _ChannelScope.recent) {
      final byId = <String, Channel>{for (final item in result) item.id: item};
      result = _recentIds.map((id) => byId[id]).whereType<Channel>();
    }
    if (_selectedCategory != null) {
      result = result.where(
        (channel) => channel.categories.contains(_selectedCategory),
      );
    }
    final tokens = searchTokens(_query);
    if (tokens.isNotEmpty) {
      result = result.where(
        (channel) => _channelMatches(channel, tokens),
      );
    }
    return result.toList(growable: false);
  }

  List<String> get _letters => channelLetters(_unletteredChannels);

  /// The chosen letter, or null when no channel under it survives the other
  /// filters.
  String? get _activeLetter {
    final letter = _letter;
    if (letter == null) return null;
    return _letters.contains(letter) ? letter : null;
  }

  List<Channel> get _visibleChannels {
    final channels = _unletteredChannels;
    final letter = _activeLetter;
    if (letter == null) return channels;
    return channels
        .where((channel) => channelLetter(channel) == letter)
        .toList(growable: false);
  }

  void _selectLetter(String? letter) {
    if (letter == _activeLetter) return;
    setState(() => _letter = letter);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'letter_changed',
      value: letter ?? 'all',
      resultCount: _visibleChannels.length,
    );
  }

  static bool _channelMatches(Channel channel, List<String> tokens) {
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
    final isFavorite = await _daddyDatabase.toggleFavorite(channel.id);
    if (!mounted) return;
    setState(() {
      if (isFavorite) {
        _favoriteIds.add(channel.id);
      } else {
        _favoriteIds.remove(channel.id);
      }
    });
    _analytics.trackLiveTVFavorite(
      surface: _analyticsSurface,
      channelId: channel.id,
      channelName: channel.name,
      added: isFavorite,
    );
  }

  Future<void> _play(Channel channel) async {
    final stopwatch = Stopwatch()..start();
    setState(() => _resolvingId = channel.id);
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
      final dependencies = context.read<AppDependencyProvider>();
      await showHostedInterstitialAd(
        context,
        loadAds: () => ScraperApi(dependencies.flixquestAPIURL).getAds(),
      );
      final autoFullScreen = context.read<SettingsProvider>().defaultViewMode;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LivePlayer(
            channelName: channel.name,
            videoUrl: stream.url,
            headers: stream.headers,
            mediaType: stream.mediaType,
            clearKey: stream.clearKey,
            variants: stream.variants,
            autoFullScreen: autoFullScreen,
            colors: <Color>[
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.surface,
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
          ),
        ),
      );
      _recentIds = await _daddyDatabase.getRecentIds();
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
        resultCount: _mode == _LiveTvMode.channels
            ? _visibleChannels.length
            : _visibleEventCount,
      );
    });
  }

  void _selectMode(_LiveTvMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'view_changed',
      value: mode.name,
    );
  }

  // EthioTV source (commented out - disabled):
  // void _selectSource(_LiveTvSource source) {
  //   if (source == _source) return;
  //   setState(() {
  //     _source = source;
  //     _mode = _LiveTvMode.channels;
  //     _selectedCategory = null;
  //     _selectedDayIndex = 0;
  //     _channels = const <Channel>[];
  //     _epg = null;
  //   });
  //   _load();
  // }

  void _selectScope(_ChannelScope scope) {
    if (scope == _scope) return;
    setState(() => _scope = scope);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'collection_changed',
      value: scope.name,
      resultCount: _visibleChannels.length,
    );
  }

  void _selectCategory(String? category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    _analytics.trackLiveTVInteraction(
      surface: _analyticsSurface,
      action: 'category_changed',
      value: category ?? 'all',
      resultCount: _visibleChannels.length,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh channels and schedule',
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
        ],
      ),
      body: AppResponsiveContent(
        maxWidth: 1100,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppEmptyState(
        icon: PhosphorIcons.broadcast(),
        title: 'Live TV is unavailable',
        message: _error!,
        action: FilledButton.icon(
          onPressed: _load,
          icon: Icon(PhosphorIcons.arrowsClockwise()),
          label: const Text('Retry'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(
            child: RemoteHostedAdsBanner(
              placement: 'live_tv',
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
          ),
          if (_mode == _LiveTvMode.channels)
            ..._buildChannelSlivers()
          else
            ..._buildScheduleSlivers(),
        ],
      ),
    );
  }

  List<Widget> _buildChannelSlivers() {
    final visible = _visibleChannels;
    if (visible.isEmpty) {
      final tokens = searchTokens(_query);
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: PhosphorIcons.televisionSimple(),
            title: 'No channels found',
            message: tokens.isNotEmpty && _epg?.days.isNotEmpty == true
                ? "No channels match '$_query'. Try the Schedule tab to browse "
                    'matching matches, or clear the search.'
                : 'Try another search, category, or collection.',
            action: tokens.isNotEmpty
                ? FilledButton.tonalIcon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: Icon(PhosphorIcons.x()),
                    label: const Text('Clear search'),
                  )
                : null,
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
        sliver: SliverGrid.builder(
          itemCount: visible.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 148,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, index) => _ChannelCard(
            channel: visible[index],
            favorite: _favoriteIds.contains(visible[index].id),
            resolving: _resolvingId == visible[index].id,
            onFavorite: () => _toggleFavorite(visible[index]),
            onPlay: () => _play(visible[index]),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildScheduleSlivers() {
    final sections = _scheduleSections;
    if (sections.isEmpty) {
      final epgAvailable = _epg?.days.isNotEmpty ?? false;
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: PhosphorIcons.calendarDots(),
            title: epgAvailable ? 'No matches found' : 'Schedule unavailable',
            message: epgAvailable
                ? 'Try another team, league, or day.'
                : "Pull to refresh to load today's schedule.",
            action: epgAvailable
                ? null
                : FilledButton.icon(
                    onPressed: () => _load(refresh: true),
                    icon: Icon(PhosphorIcons.arrowsClockwise()),
                    label: const Text('Refresh'),
                  ),
          ),
        ),
      ];
    }
    return <Widget>[
      for (final section in sections) ...<Widget>[
        SliverToBoxAdapter(
          child: _ScheduleCategoryHeader(
            name: section.label,
            count: section.events.length,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
          sliver: SliverList.builder(
            itemCount: section.events.length,
            itemBuilder: (_, index) {
              final event = section.events[index];
              final key = _eventKey(section.name, event);
              return _ScheduleEventTile(
                event: event,
                expanded: _expandedEvents.contains(key),
                onToggle: () => _toggleEvent(key),
                resolvingChannelId: _resolvingId,
                onPlay: _play,
              );
            },
          ),
        ),
      ],
    ];
  }

  Widget _buildHeader() {
    final isSchedule = _mode == _LiveTvMode.schedule;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // EthioTV source (commented out - disabled):
          // _SegmentedTrack(
          //   children: <Widget>[
          //     _ModeTab(
          //       icon: PhosphorIcons.broadcast(),
          //       label: 'DaddyLive',
          //       selected: _source == _LiveTvSource.daddyLive,
          //       onTap: () => _selectSource(_LiveTvSource.daddyLive),
          //     ),
          //     _ModeTab(
          //       icon: PhosphorIcons.football(),
          //       label: 'Ethio Sports',
          //       selected: _source == _LiveTvSource.ethioSports,
          //       onTap: () => _selectSource(_LiveTvSource.ethioSports),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 10),
          _SegmentedTrack(
            children: <Widget>[
              _ModeTab(
                icon: PhosphorIcons.televisionSimple(),
                label: 'Channels',
                selected: !isSchedule,
                onTap: () => _selectMode(_LiveTvMode.channels),
              ),
              _ModeTab(
                icon: PhosphorIcons.calendarDots(),
                label: 'Schedule',
                selected: isSchedule,
                onTap: () => _selectMode(_LiveTvMode.schedule),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: isSchedule
                  ? 'Search matches, teams & leagues'
                  : 'Search channels',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: Icon(PhosphorIcons.x()),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!isSchedule) ...<Widget>[
            AppFilterRail(
              children: <Widget>[
                for (final entry in <(_ChannelScope, String, IconData)>[
                  (_ChannelScope.all, 'All', PhosphorIcons.broadcast()),
                  (_ChannelScope.favorites, 'Favorites', PhosphorIcons.heart()),
                  (
                    _ChannelScope.recent,
                    'Recent',
                    PhosphorIcons.clockCounterClockwise()
                  ),
                ])
                  AppFilterPill(
                    label: entry.$2,
                    selected: _scope == entry.$1,
                    onPressed: () => _selectScope(entry.$1),
                  ),
              ],
            ),
            if (_categories.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              _buildCategorySelector(),
            ],
            if (_letters case final letters when letters.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppFilterRail(
                  children: <Widget>[
                    AppFilterPill(
                      label: 'A–Z',
                      selected: _activeLetter == null,
                      onPressed: () => _selectLetter(null),
                    ),
                    for (final letter in letters)
                      AppFilterPill(
                        label: letter,
                        selected: _activeLetter == letter,
                        onPressed: () => _selectLetter(letter),
                      ),
                  ],
                ),
              ),
          ] else if (_epg case final epg? when epg.days.isNotEmpty) ...<Widget>[
            AppFilterRail(
              children: <Widget>[
                for (var i = 0; i < epg.days.length; i++)
                  AppFilterPill(
                    label: _prettyDayLabel(epg.days[i].label),
                    selected: _selectedDayIndex == i,
                    onPressed: () => _selectDay(i),
                  ),
              ],
            ),
            if (_sportSections case final sports when sports.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppFilterRail(
                  children: <Widget>[
                    AppFilterPill(
                      label: 'All sports',
                      selected: _activeSport == null,
                      onPressed: () => _selectSport(null),
                    ),
                    for (final sport in sports)
                      AppFilterPill(
                        label: sport.label,
                        selected: _activeSport == sport.name,
                        onPressed: () => _selectSport(sport.name),
                      ),
                  ],
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Text(
              isSchedule
                  ? '$_visibleEventCount events • Times in $_localTimeZoneLabel'
                  : '${_visibleChannels.length} channels',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String get _localTimeZoneLabel {
    final offset = DateTime.now().timeZoneOffset;
    final hours = offset.inHours;
    final minutes = (offset.inMinutes % 60).abs();
    final sign = hours >= 0 ? '+' : '-';
    final formattedHours = hours.abs();
    final minutesStr =
        minutes > 0 ? ':${minutes.toString().padLeft(2, '0')}' : '';
    return 'GMT$sign$formattedHours$minutesStr';
  }

  String _prettyDayLabel(String label) {
    final parsed = DateTime.tryParse(label);
    if (parsed == null) return label;
    return DateFormat('EEE, MMM d').format(parsed);
  }

  Widget _buildCategorySelector() {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _pickCategory,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: <Widget>[
              Icon(PhosphorIcons.funnel(), size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedCategory ?? 'All categories',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (_selectedCategory != null)
                IconButton(
                  tooltip: 'Clear category filter',
                  onPressed: () => _selectCategory(null),
                  icon: Icon(
                    PhosphorIcons.xCircle(),
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              Icon(
                PhosphorIcons.caretDown(),
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCategory() async {
    final counts = <String, int>{};
    for (final channel in _channels) {
      for (final category in channel.categories) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CategoryPickerSheet(
        categories: _categories,
        counts: counts,
        totalChannels: _channels.length,
        selected: _selectedCategory,
      ),
    );
    if (!mounted || selected == null) return;
    _selectCategory(selected == _allCategoriesKey ? null : selected);
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color:
                        selected ? colors.onPrimary : colors.onSurfaceVariant,
                    fontFamily: selected ? 'FigtreeSB' : 'Figtree',
                    fontSize: 14,
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

class _SegmentedTrack extends StatelessWidget {
  const _SegmentedTrack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: children,
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.favorite,
    required this.resolving,
    required this.onFavorite,
    required this.onPlay,
  });

  final Channel channel;
  final bool favorite;
  final bool resolving;
  final VoidCallback onFavorite;
  final VoidCallback onPlay;

  bool get _isLive => channel.nowPlaying != null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final subtitle = channel.nowPlaying ??
        channel.nextUp ??
        (channel.categories.isEmpty
            ? 'Channel ${channel.id}'
            : channel.categories.take(2).join(' • '));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: resolving ? null : onPlay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _ChannelAvatar(name: channel.name, letter: channel.letter),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (_isLive) const _LiveBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Icon(
                      _isLive
                          ? PhosphorIcons.broadcast(PhosphorIconsStyle.fill)
                          : channel.nextUp != null
                              ? PhosphorIcons.clockCounterClockwise()
                              : PhosphorIcons.radio(),
                      size: 15,
                      color: _isLive ? colors.primary : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _isLive
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              fontWeight:
                                  _isLive ? FontWeight.w600 : FontWeight.w400,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                    onPressed: onFavorite,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      favorite
                          ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                          : PhosphorIcons.heart(),
                      size: 20,
                      color: favorite ? colors.primary : null,
                    ),
                  ),
                  const Spacer(),
                  if (resolving)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    Material(
                      color: colors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onPlay,
                        child: SizedBox.square(
                          dimension: 34,
                          child: Icon(
                            PhosphorIcons.play(),
                            size: 18,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.name, this.letter});

  final String name;
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = (letter ?? (name.isEmpty ? '?' : name.trim()))
        .characters
        .first
        .toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primary.withValues(alpha: .85),
            colors.primary.withValues(alpha: .45),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: colors.onPrimary,
          fontFamily: 'FigtreeSB',
          fontSize: 17,
          height: 1,
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: colors.error,
              fontFamily: 'FigtreeSB',
              fontSize: 10,
              height: 1,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCategoryHeader extends StatelessWidget {
  const _ScheduleCategoryHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEventTile extends StatelessWidget {
  const _ScheduleEventTile({
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final channelCount = event.channels.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: channelCount == 0 ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        event.displayTime,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.primary,
                          fontFamily: 'FigtreeSB',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$channelCount ${channelCount == 1 ? 'channel' : 'channels'}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    if (channelCount > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          PhosphorIcons.caretDown(),
                          size: 18,
                          color: colors.onSurfaceVariant,
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
              child: expanded && channelCount > 0
                  ? SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: channelCount,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final channel = event.channels[index];
                          return _ChannelChip(
                            channel: channel,
                            resolving: resolvingChannelId == channel.id,
                            onPlay: () => onPlay(channel),
                          );
                        },
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    required this.channel,
    required this.resolving,
    required this.onPlay,
  });

  final Channel channel;
  final bool resolving;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: resolving ? null : onPlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (resolving)
                const SizedBox.square(
                  dimension: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  PhosphorIcons.broadcast(PhosphorIconsStyle.fill),
                  size: 13,
                  color: colors.primary,
                ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.counts,
    required this.totalChannels,
    required this.selected,
  });

  final List<String> categories;
  final Map<String, int> counts;
  final int totalChannels;
  final String? selected;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _query.trim().isEmpty
        ? widget.categories
        : widget.categories
            .where(
              (category) => normalizeSearchText(category)
                  .contains(normalizeSearchText(_query)),
            )
            .toList(growable: false);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    PhosphorIcons.funnel(),
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Categories',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.categories.length} categories • tap to filter',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search categories',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: Icon(PhosphorIcons.x()),
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: <Widget>[
                _CategoryPickerTile(
                  label: 'All categories',
                  count: widget.totalChannels,
                  selected: widget.selected == null,
                  onTap: () => Navigator.pop(context, _allCategoriesKey),
                ),
                const SizedBox(height: 6),
                for (final category in filtered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _CategoryPickerTile(
                      label: category,
                      count: widget.counts[category] ?? 0,
                      selected: widget.selected == category,
                      onTap: () => Navigator.pop(context, category),
                    ),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No categories match',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
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

class _CategoryPickerTile extends StatelessWidget {
  const _CategoryPickerTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .14)
          : colors.surfaceContainerHighest.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.circle(),
                size: 22,
                color: selected ? colors.primary : colors.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
