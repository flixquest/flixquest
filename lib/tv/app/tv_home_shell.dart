import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../services/app_session_state_store.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_screen_focus_controller.dart';
import '../models/tv_media_item.dart';
import '../navigation/tv_back_dispatcher.dart';
import '../controllers/tv_catalog_controller.dart';
import '../controllers/tv_title_logos.dart';
import '../screens/tv_catalog_screen.dart';
import '../screens/tv_collection_screen.dart';
import '../screens/tv_discover_screen.dart';
import '../screens/tv_home_screen.dart';
import '../screens/tv_library_screen.dart';
import '../screens/tv_media_details_screen.dart';
import '../screens/tv_new_and_hot_screen.dart';
import '../screens/tv_search_screen.dart';
import '../screens/tv_settings_screen.dart';
import '../screens/tv_wellness_screen.dart';
import '../widgets/tv_navigation_rail.dart';
import '../widgets/tv_telegram_channel_prompt.dart';
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
  List<TvNavigationDestination> get _destinations => <TvNavigationDestination>[
        TvNavigationDestination(
          id: 'home',
          label: tr('home'),
          icon: PhosphorIcons.house(),
          selectedIcon: PhosphorIcons.house(PhosphorIconsStyle.fill),
        ),
        TvNavigationDestination(
            id: 'search',
            label: tr('search'),
            icon: PhosphorIcons.magnifyingGlass()),
        TvNavigationDestination(
            id: 'movies',
            label: tr('movies'),
            icon: PhosphorIcons.filmSlate(),
            selectedIcon: PhosphorIcons.filmSlate(PhosphorIconsStyle.fill)),
        TvNavigationDestination(
            id: 'series',
            label: tr('series'),
            icon: PhosphorIcons.television(),
            selectedIcon: PhosphorIcons.television(PhosphorIconsStyle.fill)),
        TvNavigationDestination(
            id: 'new',
            label: tr('new_and_hot'),
            icon: PhosphorIcons.fire(),
            selectedIcon: PhosphorIcons.fire(PhosphorIconsStyle.fill)),
        TvNavigationDestination(
            id: 'discover',
            label: tr('discover'),
            icon: PhosphorIcons.compass(),
            selectedIcon: PhosphorIcons.compass(PhosphorIconsStyle.fill)),
        TvNavigationDestination(
            id: 'library',
            label: tr('my_list'),
            icon: PhosphorIcons.bookmarkSimple(),
            selectedIcon:
                PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill)),
        TvNavigationDestination(
            id: 'wellness',
            label: tr('tv_insights'),
            icon: PhosphorIcons.chartDonut(),
            selectedIcon: PhosphorIcons.chartDonut(PhosphorIconsStyle.fill)),
        TvNavigationDestination(
            id: 'settings',
            label: tr('settings'),
            icon: PhosphorIcons.gear(),
            selectedIcon: PhosphorIcons.gear(PhosphorIconsStyle.fill)),
      ];

  /// Browse pages whose artwork runs under the rail to the screen edge.
  static const _fullBleedDestinations = <String>{
    'home',
    'search',
    'movies',
    'series',
    'new',
    'library',
  };
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
      // A link can be what started the app, before there was a shell to hear it.
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
    final logos = _titleLogos;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        // Routes sit beside the shell, not under it, so the logos go along.
        builder: (_) => logos == null
            ? TvMediaDetailsScreen(item: item)
            : TvTitleLogoScope(
                logos: logos,
                child: TvMediaDetailsScreen(item: item),
              ),
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

  Future<void> _continueWatching(TvMediaItem item) => _openMedia(item);

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
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
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
              backgroundColor: palette.page,
              body: ColoredBox(
                color: palette.page,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = TvShellMetrics.fromConstraints(constraints);
                    // The layout keeps its controls inside the TV-safe margins
                    // itself, so full-bleed artwork can still reach the edges.
                    return TvTelegramChannelPrompt(
                      enabled: selectedId == 'home',
                      child: TvShellLayout(
                        key: _layoutKey,
                        destinations: destinations,
                        selectedId: selectedId,
                        metrics: metrics,
                        fullBleedDestinations: _fullBleedDestinations,
                        onDestinationSelected: _selectDestination,
                        screenBuilder: (context, id, focusController) =>
                            _buildScreen(id, metrics, focusController),
                      ),
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
          onOpenCollection: _openCollection,
          focusController: focusController,
        ),
      'search' => TvSearchScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          onOpenCollection: _openCollection,
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
      'new' => TvNewAndHotScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          focusController: focusController,
        ),
      'discover' => TvDiscoverScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          focusController: focusController,
        ),
      'library' => TvLibraryScreen(
          metrics: metrics,
          onOpenMedia: _openMedia,
          onContinueWatching: _continueWatching,
          onOpenCollection: _openCollection,
          revision: _libraryRevision,
          focusController: focusController,
        ),
      'wellness' => TvWellnessScreen(
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
