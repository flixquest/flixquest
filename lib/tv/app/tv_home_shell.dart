import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/tv_stream_metadata.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/movie/movie_video_loader.dart';
import '../../screens/tv/tv_video_loader.dart';
import '../../services/app_session_state_store.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../navigation/tv_back_dispatcher.dart';
import '../controllers/tv_catalog_controller.dart';
import '../controllers/tv_title_logos.dart';
import '../screens/tv_catalog_screen.dart';
import '../screens/tv_collection_screen.dart';
import '../screens/tv_home_screen.dart';
import '../screens/tv_library_screen.dart';
import '../screens/tv_live_screen.dart';
import '../screens/tv_media_details_screen.dart';
import '../screens/tv_profile_screen.dart';
import '../screens/tv_search_screen.dart';
import '../screens/tv_settings_screen.dart';
import '../screens/tv_wellness_screen.dart';
import '../widgets/tv_navigation_rail.dart';
import 'tv_design.dart';
import 'tv_shell_layout.dart';

class TvHomeShell extends StatefulWidget {
  const TvHomeShell({super.key});

  static const shellKey = Key('tv-home-shell');

  @override
  State<TvHomeShell> createState() => _TvHomeShellState();
}

class _TvHomeShellState extends State<TvHomeShell> with RestorationMixin {
  /// Destination hidden when Remote Config turns Live TV off.
  static const _liveDestinationId = 'live';

  final TvFocusMemory _focusMemory = TvFocusMemory();
  final GlobalKey<TvShellLayoutState> _layoutKey =
      GlobalKey<TvShellLayoutState>();
  late final FocusScopeNode _shellFocusScope;
  late final List<TvNavigationDestination> _destinations;

  /// Browse pages whose artwork runs under the rail to the screen edge.
  static const _fullBleedDestinations = <String>{'home', 'movies', 'series'};
  late final AppSessionStateStore _sessionState;
  late final RestorableString _selectedDestinationId;
  int _libraryRevision = 0;

  /// Title logos found this session, shared by every browse page; a new
  /// language or proxy starts over, since both change what TMDB returns.
  TvTitleLogos? _titleLogos;

  TvTitleLogos _titleLogosFor({
    required String language,
    required bool proxyEnabled,
    required String proxyUrl,
  }) {
    final current = _titleLogos;
    if (current != null &&
        current.language == TvTitleLogos.languageCode(language) &&
        current.proxyEnabled == proxyEnabled &&
        current.proxyUrl == proxyUrl) {
      return current;
    }
    current?.dispose();
    return _titleLogos = TvTitleLogos(
      language: language,
      proxyEnabled: proxyEnabled,
      proxyUrl: proxyUrl,
    );
  }

  @override
  String get restorationId => 'television_home';

  @override
  void initState() {
    super.initState();
    _shellFocusScope = FocusScopeNode(debugLabel: 'TV home shell');
    _destinations = <TvNavigationDestination>[
      TvNavigationDestination(
        id: 'home',
        label: 'Home',
        icon: PhosphorIcons.house(),
        selectedIcon: PhosphorIcons.house(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'search',
        label: 'Search',
        icon: PhosphorIcons.magnifyingGlass(),
      ),
      TvNavigationDestination(
        id: 'movies',
        label: 'Movies',
        icon: PhosphorIcons.filmSlate(),
        selectedIcon: PhosphorIcons.filmSlate(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'series',
        label: 'Series',
        icon: PhosphorIcons.television(),
        selectedIcon: PhosphorIcons.television(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'live',
        label: 'Live TV',
        icon: PhosphorIcons.broadcast(),
        selectedIcon: PhosphorIcons.broadcast(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'library',
        label: 'My List',
        icon: PhosphorIcons.bookmarkSimple(),
        selectedIcon: PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'wellness',
        label: 'Insights',
        icon: PhosphorIcons.chartDonut(),
        selectedIcon: PhosphorIcons.chartDonut(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'profile',
        label: 'Profile',
        icon: PhosphorIcons.user(),
        selectedIcon: PhosphorIcons.user(PhosphorIconsStyle.fill),
      ),
      TvNavigationDestination(
        id: 'settings',
        label: 'Settings',
        icon: PhosphorIcons.gear(),
        selectedIcon: PhosphorIcons.gear(PhosphorIconsStyle.fill),
      ),
    ];
    _sessionState = AppSessionStateStore(sharedPrefsSingleton);
    _selectedDestinationId = RestorableString(
      _sessionState.televisionDestination ?? 'home',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().analytics.trackNavigation(
            destination: _selectedDestinationId.value,
            surface: 'tv',
            source: 'restored',
          );
    });
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(
      _selectedDestinationId,
      'selected_destination',
    );
    if (!AppSessionStateStore.televisionDestinations
        .contains(_selectedDestinationId.value)) {
      _selectedDestinationId.value = 'home';
    }
  }

  @override
  void dispose() {
    _selectedDestinationId.dispose();
    _shellFocusScope.dispose();
    _titleLogos?.dispose();
    super.dispose();
  }

  void _selectDestination(String destinationId) {
    if (_selectedDestinationId.value == destinationId) return;
    setState(() => _selectedDestinationId.value = destinationId);
    context.read<SettingsProvider>().analytics.trackNavigation(
          destination: destinationId,
          surface: 'tv',
        );
    unawaited(_sessionState.rememberTelevisionDestination(destinationId));
  }

  Future<bool> _handleBack() async {
    final layout = _layoutKey.currentState;
    if (layout != null && !layout.railHasFocus) {
      layout.focusRail();
      return true;
    }
    if (_selectedDestinationId.value == 'home') return false;
    setState(() => _selectedDestinationId.value = 'home');
    context.read<SettingsProvider>().analytics.trackNavigation(
          destination: 'home',
          surface: 'tv',
          source: 'back',
        );
    unawaited(_sessionState.rememberTelevisionDestination('home'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutKey.currentState?.focusRail('home');
    });
    return true;
  }

  void _restoreFocusAfterRoute(FocusNode? previousFocus) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (previousFocus != null &&
          previousFocus.context != null &&
          previousFocus.canRequestFocus) {
        previousFocus.requestFocus();
        return;
      }
      final layout = _layoutKey.currentState;
      if (layout != null && !layout.enterContent()) layout.focusRail();
    });
  }

  Future<void> _openMedia(TvMediaItem item) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TvMediaDetailsScreen(item: item),
      ),
    );
    if (mounted) {
      setState(() => _libraryRevision++);
      _restoreFocusAfterRoute(previousFocus);
    }
  }

  Future<void> _openCollection(TvCollection collection) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TvCollectionScreen(
          collection: collection,
          onOpenMedia: _openMedia,
        ),
      ),
    );
    if (mounted) _restoreFocusAfterRoute(previousFocus);
  }

  Future<void> _continueWatching(TvMediaItem item) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    final recentMovie = item.recentMovie;
    final recentEpisode = item.recentEpisode;
    Widget? loader;

    if (recentMovie?.id != null) {
      loader = MovieVideoLoader(
        download: false,
        useTvPlayer: true,
        onTvPlayerExit: () {
          if (!mounted) return;
          setState(() => _libraryRevision++);
          _restoreFocusAfterRoute(previousFocus);
        },
        metadata: MovieStreamMetadata(
          backdropPath: recentMovie!.backdropPath,
          elapsed: recentMovie.elapsed,
          movieId: recentMovie.id,
          movieName: recentMovie.title,
          posterPath: recentMovie.posterPath,
          releaseYear: recentMovie.releaseYear,
          isAdult: null,
          releaseDate: null,
        ),
      );
    } else if (recentEpisode?.id != null &&
        recentEpisode?.seriesId != null &&
        recentEpisode?.seasonNum != null &&
        recentEpisode?.episodeNum != null) {
      loader = TVVideoLoader(
        download: false,
        useTvPlayer: true,
        onTvPlayerExit: () {
          if (!mounted) return;
          setState(() => _libraryRevision++);
          _restoreFocusAfterRoute(previousFocus);
        },
        metadata: TVStreamMetadata(
          elapsed: recentEpisode!.elapsed,
          episodeId: recentEpisode.id,
          episodeName: recentEpisode.episodeName,
          episodeNumber: recentEpisode.episodeNum,
          posterPath: recentEpisode.posterPath,
          backdropPath: recentEpisode.backdropPath,
          seasonNumber: recentEpisode.seasonNum,
          seriesName: recentEpisode.seriesName,
          tvId: recentEpisode.seriesId,
          airDate: null,
        ),
      );
    }

    if (loader == null) {
      await _openMedia(item);
      return;
    }
    if (!await checkConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your internet connection.')),
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => loader!),
    );
  }

  /// Drops the Live TV destination while the Remote Config toggle is off.
  List<TvNavigationDestination> _visibleDestinations({
    required bool showLiveTv,
  }) {
    if (showLiveTv) return _destinations;
    return _destinations
        .where((destination) => destination.id != _liveDestinationId)
        .toList(growable: false);
  }

  /// A restored selection has to fall back once a toggle hides its destination.
  String _resolveSelectedId(List<TvNavigationDestination> destinations) {
    final selected = _selectedDestinationId.value;
    final isVisible =
        destinations.any((destination) => destination.id == selected);
    return isVisible ? selected : destinations.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = context.watch<AppDependencyProvider>();
    final showLiveTv = dependencies.displayLiveTV;
    final destinations = _visibleDestinations(showLiveTv: showLiveTv);
    final selectedId = _resolveSelectedId(destinations);
    final titleLogos = _titleLogosFor(
      language: context.select<SettingsProvider, String>(
        (settings) => settings.appLanguage,
      ),
      proxyEnabled: context.select<SettingsProvider, bool>(
        (settings) => settings.enableProxy,
      ),
      proxyUrl: dependencies.tmdbProxy,
    );
    return TvTitleLogoScope(
      logos: titleLogos,
      child: TvFocusMemoryScope(
        memory: _focusMemory,
        child: TvBackDispatcher(
          onBack: _handleBack,
          child: FocusScope(
            node: _shellFocusScope,
            child: Scaffold(
              key: TvHomeShell.shellKey,
              backgroundColor: TvDesign.pageBackground,
              body: ColoredBox(
                color: TvDesign.pageBackground,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = TvShellMetrics.fromConstraints(constraints);
                    // The layout keeps its controls inside the TV-safe margins
                    // itself, so full-bleed artwork can still reach the edges.
                    return TvShellLayout(
                      key: _layoutKey,
                      destinations: destinations,
                      selectedId: selectedId,
                      metrics: metrics,
                      fullBleedDestinations: _fullBleedDestinations,
                      onDestinationSelected: _selectDestination,
                      screenBuilder: (context, id, focusController) =>
                          _buildScreen(id, metrics, focusController),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(
    String destinationId,
    TvShellMetrics metrics,
    TvScreenFocusController focusController,
  ) {
    return switch (destinationId) {
      'home' => TvHomeScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          onContinueWatching: _continueWatching,
          focusController: focusController,
        ),
      'search' => TvSearchScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          focusController: focusController,
        ),
      'movies' => TvCatalogScreen(
          kind: TvMediaKind.movie,
          metrics: metrics,
          onOpenMedia: _openMedia,
          onOpenCollection: _openCollection,
          focusController: focusController,
        ),
      'series' => TvCatalogScreen(
          kind: TvMediaKind.series,
          metrics: metrics,
          onOpenMedia: _openMedia,
          onOpenCollection: _openCollection,
          focusController: focusController,
        ),
      _liveDestinationId => TvLiveScreen(
          metrics: metrics,
          focusController: focusController,
        ),
      'library' => TvLibraryScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          revision: _libraryRevision,
          focusController: focusController,
        ),
      'wellness' => TvWellnessScreen(
          metrics: metrics,
          focusController: focusController,
        ),
      'profile' => TvProfileScreen(
          metrics: metrics,
          focusController: focusController,
        ),
      'settings' => TvSettingsScreen(
          metrics: metrics,
          focusController: focusController,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
