import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/live_tv_database_controller.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../functions/function.dart';
import '../../functions/live_channel_letters.dart';
import '../../functions/live_schedule_sports.dart';
import '../../models/live_tv.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../services/daddylive_service.dart';
import '../../services/media_link.dart';
import '../../services/start_io_ads_service.dart';
// EthioTV source (commented out - disabled):
// import '../../services/ethio_sports_service.dart';
import '../../services/analytics_service.dart';
import '../../mobile/widgets/filter_chips.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../mobile/widgets/pill_button.dart';
import 'live_player.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

enum _ChannelScope { all, favorites, recent }

enum _LiveTvMode { channels, schedule }

// EthioTV source (commented out - disabled):
// enum _LiveTvSource { daddyLive, ethioSports }

const _allCategoriesKey = '__all_categories__';

class ChannelList extends StatefulWidget {
  const ChannelList({this.initialChannelId, super.key});

  /// A channel to start playing as soon as the list has loaded, for a flix.quest/l/… link.
  final String? initialChannelId;

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
      _load().then((_) => _playInitialChannel());
    });
  }

  /// Plays the channel a link asked for. The catalog supplies its name when it is listed; a channel
  /// that isn't (a stale cache, say) is still tried by id, and a failure says so like any other.
  Future<void> _playInitialChannel() async {
    final id = widget.initialChannelId;
    if (id == null || !mounted) return;
    final channel = _channels.firstWhere(
      (channel) => channel.id == id,
      orElse: () => Channel(id: id, name: id),
    );
    await _play(channel);
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

  Future<void> _shareChannel(Channel channel) async {
    final url = MediaLink.liveChannelUrl(channel.id);
    if (url == null) return;
    await Share.share(
      '${tr('watch_channel_live', namedArgs: {'name': channel.name})}\n$url',
    );
  }

  Future<void> _play(Channel channel) async {
    setState(() => _resolvingId = channel.id);
    final dependencies = context.read<AppDependencyProvider>();
    await StartIoAdsService.instance.showInterstitial(
      enabled: dependencies.startIoInterstitialEnabled,
      testMode: dependencies.unityTestMode,
      adTag: 'live_watch_now',
    );
    if (!mounted) return;
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
      await StartIoAdsService.instance.showRewarded(
        enabled: dependencies.startIoRewardedEnabled,
        testMode: dependencies.unityTestMode,
        adTag: 'live_stream_ready',
      );
      if (!mounted) return;
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
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('live_tv'),
        actions: <Widget>[
          IconButton(
            tooltip: tr('refresh'),
            onPressed: _loading ? null : () => _load(refresh: true),
            icon: Icon(PhosphorIcons.arrowsClockwise()),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(SegmentSwitch.height + 12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
            child: SegmentSwitch<_LiveTvMode>(
              segments: <Segment<_LiveTvMode>>[
                Segment(
                  _LiveTvMode.channels,
                  tr('channels'),
                  icon: PhosphorIcons.televisionSimple(),
                ),
                Segment(
                  _LiveTvMode.schedule,
                  tr('schedule'),
                  icon: PhosphorIcons.calendarDots(),
                ),
              ],
              selected: _mode,
              onChanged: _selectMode,
            ),
          ),
        ),
      ),
      body: SkeletonSwitcher(
        loading: _loading && _channels.isEmpty,
        skeleton: _LiveTvSkeleton(schedule: _mode == _LiveTvMode.schedule),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final palette = AppPalette.of(context);
    final error = _error;
    if (error != null) {
      return EmptyState(
        icon: PhosphorIcons.broadcast(),
        title: tr('live_tv_unavailable'),
        message: error,
        actionLabel: tr('retry'),
        actionIcon: PhosphorIcons.arrowClockwise(),
        onAction: _load,
      );
    }
    return RefreshIndicator(
      color: palette.foreground,
      backgroundColor: palette.raisedSurface,
      onRefresh: () => _load(refresh: true),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeader()),
          _bannerSliver('live_tv_1'),
          if (_mode == _LiveTvMode.channels)
            ..._buildChannelSlivers()
          else
            ..._buildScheduleSlivers(),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).bottom + AppSpace.xxl,
            ),
          ),
        ],
      ),
    );
  }

  /// Live TV ads use the larger MREC unit; it is the best-paying placement
  /// the Start.io plugin exposes.
  Widget _bannerSliver(String placement) => SliverToBoxAdapter(
        child: RemoteHostedAdsBanner(
          placement: placement,
          variant: HostedBannerVariant.tall,
          loadAds: () => ScraperApi(
            context.read<AppDependencyProvider>().flixquestAPIURL,
          ).getAds(),
        ),
      );

  /// Splits [items] into [parts] near-equal slices so banners can sit between
  /// them. Empty slices are kept so the banner positions never shift.
  static List<List<T>> _chunk<T>(List<T> items, int parts) {
    final size = (items.length / parts).ceil();
    return <List<T>>[
      for (var i = 0; i < parts; i++)
        items.sublist(
          math.min(i * size, items.length),
          math.min((i + 1) * size, items.length),
        ),
    ];
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  List<Widget> _buildChannelSlivers() {
    final visible = _visibleChannels;
    if (visible.isEmpty) {
      final searching = searchTokens(_query).isNotEmpty;
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: PhosphorIcons.televisionSimple(),
            title: tr('no_channels'),
            message: searching && _epg?.days.isNotEmpty == true
                ? tr('no_channels_match', namedArgs: {'query': _query})
                : tr('try_another_channel_filter'),
            actionLabel: searching ? tr('clear_search') : null,
            actionIcon: PhosphorIcons.x(),
            onAction: _clearSearch,
          ),
        ),
      ];
    }
    final gutter = AppSpace.gutter(context);
    final scale = MediaQuery.textScalerOf(context);

    Widget grid(List<Channel> channels) => SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
          sliver: SliverGrid.builder(
            itemCount: channels.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 520,
              // The row's two lines of text, grown with the text size.
              mainAxisExtent: math.max(68, scale.scale(39) + 30),
              crossAxisSpacing: AppSpace.md,
              mainAxisSpacing: AppSpace.sm,
            ),
            itemBuilder: (_, index) {
              final channel = channels[index];
              return _ChannelCard(
                channel: channel,
                favorite: _favoriteIds.contains(channel.id),
                resolving: _resolvingId == channel.id,
                onFavorite: () => _toggleFavorite(channel),
                onShare: MediaLink.liveChannelUrl(channel.id) == null
                    ? null
                    : () => _shareChannel(channel),
                onPlay: () => _play(channel),
              );
            },
          ),
        );

    // The header banner is `live_tv_1`; these three break the list up.
    final chunks = _chunk(visible, 4);
    return <Widget>[
      grid(chunks[0]),
      _bannerSliver('live_tv_2'),
      grid(chunks[1]),
      _bannerSliver('live_tv_3'),
      grid(chunks[2]),
      _bannerSliver('live_tv_4'),
      grid(chunks[3]),
    ];
  }

  List<Widget> _buildScheduleSlivers() {
    final sections = _scheduleSections;
    if (sections.isEmpty) {
      final epgAvailable = _epg?.days.isNotEmpty ?? false;
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: PhosphorIcons.calendarDots(),
            title: epgAvailable
                ? tr('no_matches_found')
                : tr('schedule_unavailable'),
            message: epgAvailable
                ? tr('try_another_match_filter')
                : tr('pull_to_refresh_schedule'),
            actionLabel: epgAvailable ? null : tr('refresh'),
            actionIcon: PhosphorIcons.arrowsClockwise(),
            onAction: () => _load(refresh: true),
          ),
        ),
      ];
    }
    final gutter = AppSpace.gutter(context);
    final palette = AppPalette.of(context);
    // The header banner is `live_tv_1`; spread the rest after the first
    // sections, then append any slots the schedule is too short to reach.
    final slivers = <Widget>[];
    var banner = 2;
    for (final section in sections) {
      slivers.addAll(<Widget>[
        SliverToBoxAdapter(
          child: KickerHeading(
            section.label,
            trailing: Text(
              _count(section.events.length),
              style: AppType.metadata.copyWith(color: palette.mutedText),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
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
      ]);
      if (banner <= 4) slivers.add(_bannerSliver('live_tv_$banner'));
      banner++;
    }
    while (banner <= 4) {
      slivers.add(_bannerSliver('live_tv_$banner'));
      banner++;
    }
    return slivers;
  }

  String _count(int n) => NumberFormat.decimalPattern(
        context.locale.toLanguageTag(),
      ).format(n);

  Widget _buildHeader() {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final isSchedule = _mode == _LiveTvMode.schedule;
    final selectedCategory = _selectedCategory;
    final epg = _epg;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: SearchPill(
              controller: _searchController,
              hint: isSchedule ? tr('search_matches') : tr('search_channels'),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          if (!isSchedule) ...<Widget>[
            FilterChips(
              chips: <FilterChipSpec>[
                for (final (scope, label) in <(_ChannelScope, String)>[
                  (_ChannelScope.all, tr('all')),
                  (_ChannelScope.favorites, tr('favorites')),
                  (_ChannelScope.recent, tr('recent')),
                ])
                  FilterChipSpec(
                    label: label,
                    selected: _scope == scope,
                    onTap: () => _selectScope(scope),
                  ),
                if (_categories.isNotEmpty)
                  FilterChipSpec(
                    label: selectedCategory ?? tr('all_categories'),
                    selected: selectedCategory != null,
                    dropdown: true,
                    onTap: _pickCategory,
                  ),
              ],
            ),
            if (_letters case final letters when letters.length > 1) ...<Widget>[
              const SizedBox(height: AppSpace.sm),
              FilterChips(
                chips: <FilterChipSpec>[
                  FilterChipSpec(
                    label: 'A–Z',
                    selected: _activeLetter == null,
                    onTap: () => _selectLetter(null),
                  ),
                  for (final letter in letters)
                    FilterChipSpec(
                      label: letter,
                      selected: _activeLetter == letter,
                      onTap: () => _selectLetter(letter),
                    ),
                ],
              ),
            ],
          ] else if (epg != null && epg.days.isNotEmpty) ...<Widget>[
            FilterChips(
              chips: <FilterChipSpec>[
                for (var i = 0; i < epg.days.length; i++)
                  FilterChipSpec(
                    label: _prettyDayLabel(epg.days[i].label),
                    selected: _selectedDayIndex == i,
                    onTap: () => _selectDay(i),
                  ),
              ],
            ),
            if (_sportSections case final sports when sports.isNotEmpty) ...<
                Widget>[
              const SizedBox(height: AppSpace.sm),
              FilterChips(
                chips: <FilterChipSpec>[
                  FilterChipSpec(
                    label: tr('all_sports'),
                    selected: _activeSport == null,
                    onTap: () => _selectSport(null),
                  ),
                  for (final sport in sports)
                    FilterChipSpec(
                      label: sport.label,
                      selected: _activeSport == sport.name,
                      onTap: () => _selectSport(sport.name),
                    ),
                ],
              ),
            ],
          ],
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              gutter,
              AppSpace.md,
              gutter,
              0,
            ),
            child: Text(
              isSchedule
                  ? '${plural('event_count', _visibleEventCount)} · '
                      '${tr('times_in_zone', namedArgs: {
                          'zone': _localTimeZoneLabel,
                        })}'
                  : plural('channel_count', _visibleChannels.length),
              style: AppType.metadata.copyWith(
                fontSize: 13,
                color: palette.mutedText,
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
    return DateFormat.MMMEd(context.locale.toLanguageTag()).format(parsed);
  }

  Future<void> _pickCategory() async {
    final counts = <String, int>{};
    for (final channel in _channels) {
      for (final category in channel.categories) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    final selected = await showAppSheet<String>(
      context,
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

/// A channel: its initial, its name and what's on, tapped to watch. Share
/// and favourite sit at the end.
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    required this.favorite,
    required this.resolving,
    required this.onFavorite,
    required this.onShare,
    required this.onPlay,
  });

  final Channel channel;
  final bool favorite;
  final bool resolving;
  final VoidCallback onFavorite;
  final VoidCallback? onShare;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final live = channel.nowPlaying != null;
    final subtitle = channel.nowPlaying ??
        channel.nextUp ??
        (channel.categories.isEmpty
            ? tr('channel_number', namedArgs: {'id': channel.id})
            : channel.categories.take(2).join(' · '));
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: resolving ? null : onPlay,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          child: Row(
            children: <Widget>[
              _ChannelAvatar(channel: channel, resolving: resolving),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.cardTitle.copyWith(
                        fontSize: 15,
                        height: 1.3,
                        color: palette.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        if (live) ...<Widget>[
                          const _LiveDot(),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.metadata.copyWith(
                              fontSize: 13,
                              height: 1.35,
                              color: live
                                  ? palette.secondaryText
                                  : palette.mutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onShare != null)
                IconButton(
                  tooltip: tr('share_channel'),
                  onPressed: onShare,
                  color: palette.mutedText,
                  icon: Icon(PhosphorIcons.shareNetwork(), size: 20),
                ),
              IconButton(
                tooltip: favorite
                    ? tr('remove_from_favorites')
                    : tr('add_to_favorites'),
                onPressed: onFavorite,
                color: favorite ? palette.foreground : palette.mutedText,
                icon: Icon(
                  favorite
                      ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                      : PhosphorIcons.heart(),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A channel's initial on a soft tile, or a small spinner while its stream
/// is found.
class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel, required this.resolving});

  final Channel channel;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final name = channel.name.trim();
    final initial =
        (channel.letter ?? (name.isEmpty ? '?' : name)).characters.first;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.idleFill,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: resolving
          ? SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.foreground,
              ),
            )
          : Text(
              initial.toUpperCase(),
              style: TextStyle(
                color: palette.foreground,
                fontFamily: AppType.semiBold,
                fontSize: 17,
                height: 1,
              ),
            ),
    );
  }
}

/// Live now: a small red dot, as broadcasters mark it.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) => Semantics(
        label: tr('live_now'),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            shape: BoxShape.circle,
          ),
        ),
      );
}

/// A match: its kick-off, its title and how many channels carry it; opened,
/// the channels to watch it on.
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
    final palette = AppPalette.of(context);
    final channelCount = event.channels.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: channelCount == 0 ? null : onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Row(
                  children: <Widget>[
                    Container(
                      constraints: const BoxConstraints(minWidth: 60),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: palette.idleFill,
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Text(
                        event.displayTime,
                        textAlign: TextAlign.center,
                        style: AppType.cardTitle.copyWith(
                          fontSize: 13,
                          color: palette.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.cardTitle.copyWith(
                              fontSize: 15,
                              height: 1.3,
                              color: palette.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plural('channel_count', channelCount),
                            style: AppType.metadata.copyWith(
                              fontSize: 13,
                              color: palette.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (channelCount > 0) ...<Widget>[
                      const SizedBox(width: AppSpace.sm),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          PhosphorIcons.caretDown(),
                          size: 18,
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
              alignment: AlignmentDirectional.topCenter,
              child: expanded && channelCount > 0
                  ? Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpace.md,
                        0,
                        AppSpace.md,
                        AppSpace.md,
                      ),
                      child: Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: <Widget>[
                          for (final channel in event.channels)
                            _ChannelChip(
                              channel: channel,
                              resolving: resolvingChannelId == channel.id,
                              onPlay: () => onPlay(channel),
                            ),
                        ],
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
    final palette = AppPalette.of(context);
    return Material(
      color: palette.idleFill,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: resolving ? null : onPlay,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (resolving)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.foreground,
                  ),
                )
              else
                PlaybackIcon(
                  PhosphorIcons.play(PhosphorIconsStyle.fill),
                  size: 14,
                  color: palette.foreground,
                ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.cardTitle.copyWith(
                    fontSize: 13,
                    color: palette.foreground,
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
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final needle = normalizeSearchText(_query);
    final filtered = needle.isEmpty
        ? widget.categories
        : widget.categories
            .where((category) => normalizeSearchText(category).contains(needle))
            .toList(growable: false);
    final count = NumberFormat.decimalPattern(context.locale.toLanguageTag());
    Widget tile(String label, int n, bool selected, String value) => ListRow(
          label: label,
          value: count.format(n),
          trailing: selected
              ? Icon(
                  PhosphorIcons.check(PhosphorIconsStyle.bold),
                  size: 18,
                  color: palette.foreground,
                )
              : null,
          showsNext: false,
          onTap: () => Navigator.pop(context, value),
        );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.md),
              child: Text(
                tr('categories'),
                style: AppType.sectionHeader.copyWith(
                  fontFamily: AppType.bold,
                  color: palette.foreground,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpace.sm),
              child: SearchPill(
                controller: _searchController,
                hint: tr('search_categories'),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpace.xxl),
                children: <Widget>[
                  if (needle.isEmpty)
                    tile(
                      tr('all_categories'),
                      widget.totalChannels,
                      widget.selected == null,
                      _allCategoriesKey,
                    ),
                  for (final category in filtered)
                    tile(
                      category,
                      widget.counts[category] ?? 0,
                      widget.selected == category,
                      category,
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        tr('no_categories_match'),
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: palette.mutedText),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live TV's shape while the catalog loads: the search pill, a row of
/// chips and the first channels (or matches).
class _LiveTvSkeleton extends StatelessWidget {
  const _LiveTvSkeleton({required this.schedule});

  final bool schedule;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SkeletonPulse(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SkeletonBlock(
              height: SearchPill.height,
              radius: AppRadii.hero,
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: <Widget>[
                for (final width in const <double>[48, 84, 70, 124])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpace.sm,
                    ),
                    child: SkeletonBlock(
                      width: width,
                      height: FilterChips.height,
                      radius: AppRadii.chip,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            const SkeletonBlock.line(width: 96),
            const SizedBox(height: AppSpace.lg),
            for (var i = 0; i < 8; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: <Widget>[
                    SkeletonBlock(
                      width: schedule ? 60 : 44,
                      height: schedule ? 30 : 44,
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FractionallySizedBox(
                            widthFactor: i.isEven ? .6 : .45,
                            child: const SkeletonBlock.line(height: 14),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          FractionallySizedBox(
                            widthFactor: i.isEven ? .35 : .5,
                            child: const SkeletonBlock.line(height: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
