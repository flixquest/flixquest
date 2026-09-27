import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/catalog_controller.dart';
import '../../catalog/continue_watching.dart';
import '../../catalog/home_feed_controller.dart';
import '../../catalog/home_hero.dart';
import '../../catalog/media_item.dart';
import '../../catalog/title_logos.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/genres.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/bookmark_screen.dart';
import '../../screens/common/live_tv_screen.dart';
import '../../services/ambient_theme_service.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/common_widgets.dart'
    show AppStreamingService, appStreamingServices;
import '../../widgets/hosted_ads_banner.dart';
import '../app/mobile_tabs.dart';
import '../collections.dart';
import '../my_list.dart';
import '../../screens/common/update_screen.dart';
import '../widgets/category_section.dart';
import '../widgets/filter_chips.dart';
import '../widgets/genre_sheet.dart';
import '../widgets/hero_card.dart';
import '../widgets/media_art.dart';
import '../widgets/media_rows.dart';
import '../widgets/pill_button.dart';
import '../widgets/skeletons.dart';
import 'collection_screen.dart';

/// Finds a colour to tint the top of Home with, from an image URL.
typedef TintFinder = Future<Color?> Function(String imageUrl);

/// The phone's Home: a featured title, then rows of what to watch next, all
/// narrowed by the filter chips at the top.
///
/// Each filter's rows are fetched once and kept for the session; pulling down
/// refreshes the rows on show but not the featured title, which stays put so
/// the page doesn't shift under the viewer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.source,
    this.findTint = DominantImageColor.extract,
    this.showTitleLogos = true,
    this.now,
    super.key,
  });

  /// Where the rows come from; TMDB by default.
  final HomeFeedSource? source;
  final TintFinder? findTint;

  /// Whether to look up logo artwork for the featured title.
  final bool showTitleLogos;

  /// The time the featured-title rules are judged at, for tests.
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late HomeFilter _filter;
  bool _started = false;

  /// Fades the rows in on a new filter; the outgoing rows just go, as the
  /// tabs do, so there is never two pages' worth of rows to draw.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  final Map<HomeFilter, HomeFeed> _feeds = <HomeFilter, HomeFeed>{};
  final Map<HomeFilter, Future<void>> _loading = <HomeFilter, Future<void>>{};
  final Set<HomeFilter> _failed = <HomeFilter>{};
  final Map<HomeFilter, List<HomeHero>> _heroes =
      <HomeFilter, List<HomeHero>>{};
  final Map<String, Color?> _tints = <String, Color?>{};

  /// The colour of the hero on show, washing down the top of the page. A
  /// notifier, so the hero turning doesn't rebuild the rows.
  final ValueNotifier<Color?> _tint = ValueNotifier<Color?>(null);
  MediaItem? _shownHero;

  /// Each category row's titles, fetched once for the session.
  final Map<String, Future<List<MediaItem>>> _categoryItems =
      <String, Future<List<MediaItem>>>{};
  MobileTabController? _tabs;
  TitleLogos? _logos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = MobileTabScope.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs?.removeResetListener(MobileTab.home, _reset);
      _tabs = tabs?..addResetListener(MobileTab.home, _reset);
    }
    if (!_started) {
      _started = true;
      _filter = tabs?.initialHomeFilter ?? HomeFilter.all;
      _load(_filter);
    }
    if (widget.showTitleLogos) _logos = _logosFor(context);
  }

  @override
  void dispose() {
    _tabs?.removeResetListener(MobileTab.home, _reset);
    _logos?.dispose();
    _fade.dispose();
    _tint.dispose();
    super.dispose();
  }

  /// Logos found this session; a new language or proxy starts over, since
  /// both change what TMDB returns.
  TitleLogos _logosFor(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    final current = _logos;
    if (current != null &&
        current.language == TitleLogos.languageCode(settings.appLanguage) &&
        current.proxyEnabled == settings.enableProxy &&
        current.proxyUrl == dependencies.tmdbProxy) {
      return current;
    }
    current?.dispose();
    return TitleLogos(
      language: settings.appLanguage,
      proxyEnabled: settings.enableProxy,
      proxyUrl: dependencies.tmdbProxy,
    );
  }

  HomeFeedSource _source() =>
      widget.source ??
      CatalogHomeFeedSource(
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );

  HomeFeedController _controller() => HomeFeedController(_source());

  Future<List<MediaItem>> _category(HomeCategory category) =>
      _categoryItems.putIfAbsent(
        '${category.kind.name}-${category.genre.genreID}',
        () => _source()
            .genre(category.kind, category.genre.genreID!)
            .catchError((Object _) => const <MediaItem>[]),
      );

  void _openCategory(HomeCategory category) =>
      openGenreCollection(context, category.kind, category.genre);

  Future<void> _load(HomeFilter filter) {
    _failed.remove(filter);
    return _loading[filter] = _controller().load(filter).then((feed) {
      if (!mounted) return;
      final first = _feeds[filter] == null;
      setState(() {
        if (feed.isEmpty && first) {
          _failed.add(filter);
        } else if (!feed.isEmpty) {
          _feeds[filter] = feed;
        }
      });
      if (first && filter == _filter) _fade.forward(from: 0);
    }, onError: (Object _) {
      if (mounted && _feeds[filter] == null) {
        setState(() => _failed.add(filter));
      }
    });
  }

  void _select(HomeFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _fade.forward(from: 0);
    if (!_feeds.containsKey(filter) && !_failed.contains(filter)) {
      _load(filter);
    }
  }

  /// A second press on Home: back to All.
  void _reset() => _select(HomeFilter.all);

  Future<void> _refresh() => _load(_filter);

  /// Back to the skeleton while the failed filter loads again.
  void _retry() {
    setState(() => _failed.remove(_filter));
    _load(_filter);
  }

  List<MediaItem> _continueWatching(BuildContext context) {
    final recent = context.watch<RecentProvider?>();
    if (recent == null) return const <MediaItem>[];
    return continueWatchingItems(
      movies: recent.movies,
      episodes: recent.episodes,
      upNext: recent.upNext,
      filter: _filter,
    );
  }

  /// The hero's titles for the current filter, chosen once.
  List<HomeHero> _heroesFor(HomeFeed feed, List<MediaItem> continueWatching) =>
      _heroes.putIfAbsent(
        _filter,
        () => chooseHomeHeroes(
          filter: _filter,
          feed: feed,
          continueWatching: continueWatching,
          now: widget.now?.call(),
        ),
      );

  void _onHeroShown(HomeHero hero) {
    _shownHero = hero.item;
    _tint.value = _tints[hero.item.stableId];
    _findTint(hero.item);
  }

  void _findTint(MediaItem item) {
    final findTint = widget.findTint;
    final key = item.stableId;
    if (findTint == null || _tints.containsKey(key)) return;
    _tints[key] = null;
    // Called as the hero turns, outside build.
    final url = tmdbImageUrl(
      context,
      item.posterPath ?? item.backdropPath,
      size: 'w185/',
      listen: false,
    );
    if (url == null) return;
    findTint(url).then((color) {
      if (!mounted || color == null) return;
      _tints[key] = color;
      if (_shownHero?.stableId == key) _tint.value = color;
    }, onError: (Object _) {});
  }

  MediaCollection _translated(
    MediaCollection collection,
    String kicker, {
    String? adPlacement,
  }) =>
      MediaCollection(
        id: collection.id,
        title: collection.title,
        kicker: kicker.toUpperCase(),
        logoAsset: collection.logoAsset,
        adPlacement: adPlacement ?? collection.adPlacement,
        loadPage: collection.loadPage,
      );

  Future<void> _openCollection(MediaCollection collection) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(collection: collection),
        ),
      );

  /// A row's whole list, from its "See all".
  void _openList(MediaKind kind, HomeList list, String title) {
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    final url = CatalogHomeFeedSource(
      settings: settings,
      dependencies: dependencies,
    ).urlFor(kind, list);
    if (url == null) return;
    _openCollection(
      const CatalogController().listCollection(
        id: 'home-${kind.name}-${list.name}',
        kind: kind,
        url: url,
        title: title,
        kicker: tr(kind == MediaKind.movie ? 'movies' : 'series').toUpperCase(),
        settings: settings,
        dependencies: dependencies,
        // The placements of the old Movies and Series list pages.
        adPlacement: kind == MediaKind.movie ? 'movie_list' : 'tv_list',
      ),
    );
  }

  /// A service's catalog: under All, its movies and its series under a
  /// switch, never mixed in one grid.
  void _openService(AppStreamingService service) {
    const catalog = CatalogController();
    final settings = context.read<SettingsProvider>();
    final dependencies = context.read<AppDependencyProvider>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionScreen.tabbed(
          tabs: <(String, MediaCollection)>[
            for (final kind in _filter.kinds)
              (
                tr(kind == MediaKind.movie ? 'movies' : 'series'),
                _translated(
                  catalog.serviceCollection(
                    kind: kind,
                    service: service,
                    settings: settings,
                    dependencies: dependencies,
                  ),
                  tr('streaming_services'),
                  // The placements of the old streaming service pages.
                  adPlacement: kind == MediaKind.movie
                      ? 'streaming_movies'
                      : 'streaming_tv',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategories(HomeFeed? feed) async {
    final picked = await showGenreSheet(
      context,
      movieGenres: feed?.movieGenres ?? const <Genres>[],
      seriesGenres: feed?.seriesGenres ?? const <Genres>[],
    );
    if (picked == null || !mounted) return;
    final (kind, genre) = picked;
    await openGenreCollection(context, kind, genre);
  }

  List<String> _genreNames(HomeFeed feed, MediaItem item) {
    final genres =
        item.kind == MediaKind.movie ? feed.movieGenres : feed.seriesGenres;
    final names = <int, String>{
      for (final genre in genres)
        if (genre.genreID != null && genre.genreName != null)
          genre.genreID!: genre.genreName!,
    };
    return item.genreIds
        .map((id) => names[id])
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final feed = _feeds[_filter];
    final continueWatching = _continueWatching(context);
    final heroes =
        feed == null ? const <HomeHero>[] : _heroesFor(feed, continueWatching);
    final media = MediaQuery.of(context);
    final gutter = AppSpace.gutter(context);
    final headerHeight = media.padding.top + _HomeHeader.barHeight;

    final List<Widget> content;
    if (feed != null) {
      final rows = homeRows(
        context,
        filter: _filter,
        feed: feed,
        continueWatching: continueWatching,
        myList: MyList.items(context, filter: _filter),
        heroes: heroes,
        genresFor: (item) => _genreNames(feed, item),
        onHeroShown: _onHeroShown,
        loadCategory: _category,
        onOpenCategory: _openCategory,
        onOpenService: _openService,
        onOpenList: _openList,
      );
      content = <Widget>[
        SliverFadeTransition(
          opacity: _fade,
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) => rows[index] is HomeOptionalRow
                ? rows[index]
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.rowGap),
                    child: rows[index],
                  ),
          ),
        ),
      ];
    } else if (_failed.contains(_filter)) {
      content = <Widget>[
        SliverToBoxAdapter(
          child: _HomeError(onRetry: _retry),
        ),
      ];
    } else {
      content = const <Widget>[SliverToBoxAdapter(child: HomeSkeleton())];
    }

    final page = Stack(
      children: <Widget>[
        // The featured title's colour washes down from the top of the
        // page, behind everything.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight + HeroCard.heightFor(media.size.width, gutter),
          child: IgnorePointer(
            child: ValueListenableBuilder<Color?>(
              valueListenable: _tint,
              builder: (context, tint, _) => TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: tint == null || feed == null
                      ? palette.page
                      : Color.lerp(
                          palette.page,
                          tint,
                          palette.dark ? .42 : .24,
                        ),
                ),
                duration: const Duration(milliseconds: 700),
                builder: (context, color, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[color ?? palette.page, palette.page],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        RefreshIndicator(
          edgeOffset: headerHeight,
          color: palette.foreground,
          backgroundColor: palette.raisedSurface,
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _tabs?.scrollController(MobileTab.home),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeHeaderDelegate(
                  topInset: media.padding.top,
                  palette: palette,
                  reduceMotion: media.disableAnimations,
                  chips: _chips(feed),
                  onSearch: () => _tabs?.select(MobileTab.search),
                  onProfile: () => _tabs?.select(MobileTab.mine),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),
              ...content,
              SliverToBoxAdapter(
                child: SizedBox(height: media.padding.bottom + AppSpace.sm),
              ),
            ],
          ),
        ),
      ],
    );

    final logos = _logos;
    return ColoredBox(
      color: palette.page,
      child: logos == null ? page : TitleLogoScope(logos: logos, child: page),
    );
  }

  List<FilterChipSpec> _chips(HomeFeed? feed) {
    final showLiveTv =
        context.watch<AppDependencyProvider?>()?.displayLiveTV ?? false;
    return <FilterChipSpec>[
      FilterChipSpec(
        label: tr('filter_all'),
        selected: _filter == HomeFilter.all,
        onTap: () => _select(HomeFilter.all),
      ),
      FilterChipSpec(
        label: tr('movies'),
        selected: _filter == HomeFilter.movies,
        onTap: () => _select(HomeFilter.movies),
      ),
      FilterChipSpec(
        label: tr('series'),
        selected: _filter == HomeFilter.series,
        onTap: () => _select(HomeFilter.series),
      ),
      if (showLiveTv)
        FilterChipSpec(
          label: tr('live_tv'),
          icon: PhosphorIcons.broadcast(),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const ChannelList()),
          ),
        ),
      FilterChipSpec(
        label: tr('categories'),
        dropdown: true,
        onTap: () => _openCategories(feed),
      ),
    ];
  }
}

/// Home's top: the logo, Search and My FlixQuest, and the filter chips. It
/// sits clear over the featured title's wash, and takes on the page colour,
/// frosted, once the page scrolls under it.
class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeHeaderDelegate({
    required this.topInset,
    required this.palette,
    required this.reduceMotion,
    required this.chips,
    required this.onSearch,
    required this.onProfile,
  });

  final double topInset;
  final AppPalette palette;
  final bool reduceMotion;
  final List<FilterChipSpec> chips;
  final VoidCallback onSearch;
  final VoidCallback onProfile;

  /// Scrolled this far, the bar is fully solid.
  static const _solidAfter = 80.0;

  @override
  double get maxExtent => topInset + _HomeHeader.barHeight;

  @override
  double get minExtent => maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final solid = (shrinkOffset / _solidAfter).clamp(0.0, 1.0);
    final header = _HomeHeader(
      topInset: topInset,
      chips: chips,
      onSearch: onSearch,
      onProfile: onProfile,
    );
    final background = ColoredBox(
      color: palette.scrim(solid * (reduceMotion ? 1 : .94)),
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (solid > 0 && !reduceMotion)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 12 * solid,
                sigmaY: 12 * solid,
              ),
              child: background,
            ),
          )
        else
          background,
        header,
      ],
    );
  }

  @override
  bool shouldRebuild(_HomeHeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      !identical(palette, oldDelegate.palette) ||
      reduceMotion != oldDelegate.reduceMotion ||
      chips != oldDelegate.chips;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.topInset,
    required this.chips,
    required this.onSearch,
    required this.onProfile,
  });

  final double topInset;
  final List<FilterChipSpec> chips;
  final VoidCallback onSearch;
  final VoidCallback onProfile;

  static const _appBarHeight = 52.0;
  static const barHeight = _appBarHeight + FilterChips.height + 12;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: _appBarHeight,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter - 8, 0),
              child: Row(
                children: <Widget>[
                  // The mark in the theme's colour, as the TV rail has it (a
                  // logo set remotely still takes its place), and the name
                  // in heavy type in the text colour beside it.
                  Flexible(
                    child: Semantics(
                      header: true,
                      label: 'FlixQuest',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AppLogo(
                            fallbackAsset: 'assets/images/fq_svg.svg',
                            height: 26,
                            fallbackColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          // A logo, so it keeps its size at any text size,
                          // and gives way only if the bar runs out of room.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'FLIXQUEST',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: palette.foreground,
                                  fontFamily: 'FigtreeBlack',
                                  fontSize: 20,
                                  height: 1,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('search'),
                    color: palette.foreground,
                    onPressed: onSearch,
                    icon: Icon(PhosphorIcons.magnifyingGlass(), size: 24),
                  ),
                  IconButton(
                    tooltip: tr('my_flixquest'),
                    color: palette.foreground,
                    onPressed: onProfile,
                    icon: Icon(PhosphorIcons.userCircle(), size: 26),
                  ),
                ],
              ),
            ),
          ),
          FilterChips(chips: chips),
        ],
      ),
    );
  }
}

/// The upcoming row's badge: its release date, "MAY 3", in the app's
/// language where the date formats for it are loaded.
String? _releaseBadge(BuildContext context, MediaItem item) {
  final date = DateTime.tryParse(item.releaseDate ?? '');
  if (date == null) return null;
  final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
  try {
    return DateFormat.MMMd(locale).format(date).toUpperCase();
  } catch (_) {
    return DateFormat.MMMd().format(date).toUpperCase();
  }
}

/// Home's rows for a loaded feed, top to bottom: the hero, then what to
/// watch next. Under All each chart comes as a pair, movies then series, so
/// no catalogue row mixes the two; only the viewer's own rows (Continue
/// Watching, My List) hold both. The two ads sit well below the first screen
/// and never above Continue Watching.
@visibleForTesting
List<Widget> homeRows(
  BuildContext context, {
  required HomeFilter filter,
  required HomeFeed feed,
  required List<MediaItem> continueWatching,
  required List<MediaItem> myList,
  required List<HomeHero> heroes,
  required List<String> Function(MediaItem item) genresFor,
  required ValueChanged<HomeHero> onHeroShown,
  required Future<List<MediaItem>> Function(HomeCategory category) loadCategory,
  required ValueChanged<HomeCategory> onOpenCategory,
  required ValueChanged<AppStreamingService> onOpenService,
  required void Function(MediaKind kind, HomeList list, String title)
      onOpenList,
}) {
  final kinds = filter.kinds;
  final both = kinds.length > 1;
  String titled(MediaKind kind, String movies, String series) =>
      tr(kind == MediaKind.movie ? movies : series);

  // The rows that share the first screens; keep them from repeating the
  // same few titles.
  final lead = limitRepeats(<List<MediaItem>>[
    continueWatching,
    for (final kind in kinds) feed.of(kind).topTen,
    for (final kind in kinds) feed.of(kind).trending,
    myList,
    for (final kind in kinds) feed.of(kind).newReleases,
  ]);
  var next = 0;
  List<MediaItem> take() => lead[next++];
  final shownContinue = take();
  final topTen = <MediaKind, List<MediaItem>>{for (final k in kinds) k: take()};
  final trending = <MediaKind, List<MediaItem>>{
    for (final k in kinds) k: take(),
  };
  final shownMyList = take();
  final newReleases = <MediaKind, List<MediaItem>>{
    for (final k in kinds) k: take(),
  };

  PosterRow listRow(
    MediaKind kind,
    HomeList list,
    String title,
    List<MediaItem> items, {
    String? Function(MediaItem item) badgeFor = recencyBadge,
  }) =>
      PosterRow(
        title: title,
        items: items,
        badgeFor: badgeFor,
        onSeeAll: () => onOpenList(kind, list, title),
      );

  // The placements the old Movies and Series pages reported.
  final ad = HomeAdSlot(
    placement: filter == HomeFilter.series ? 'home_tv' : 'home_movies',
  );
  return <Widget>[
    if (heroes.isNotEmpty)
      HeroCarousel(
        key: ValueKey<HomeFilter>(filter),
        heroes: heroes,
        genresFor: genresFor,
        onShown: onHeroShown,
      ),
    // Only there when an update is out.
    const HomeOptionalRow(child: UpdateBottom()),
    if (shownContinue.isNotEmpty)
      ContinueRow(title: tr('continue_watching'), items: shownContinue),
    for (final kind in kinds)
      if (topTen[kind]!.isNotEmpty)
        TopTenRow(
          title: titled(kind, 'top_10_movies_today', 'top_10_series_today'),
          items: topTen[kind]!,
        ),
    for (final kind in kinds)
      if (trending[kind]!.isNotEmpty)
        listRow(
          kind,
          HomeList.trendingWeek,
          titled(kind, 'trending_movies_week', 'trending_series_week'),
          trending[kind]!,
        ),
    ad,
    if (shownMyList.isNotEmpty)
      PosterRow(
        title: tr('my_list'),
        items: shownMyList,
        onSeeAll: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const BookmarkScreen()),
        ),
      ),
    for (final kind in kinds)
      if (newReleases[kind]!.isNotEmpty)
        listRow(
          kind,
          HomeList.newReleases,
          titled(kind, 'new_movies', 'new_episodes'),
          newReleases[kind]!,
          // The row's title already says the episodes are new.
          badgeFor: (item) =>
              kind == MediaKind.series ? null : recencyBadge(item),
        ),
    for (final kind in kinds)
      if (feed.of(kind).popular.isNotEmpty)
        listRow(
          kind,
          HomeList.popular,
          titled(kind, 'popular_movies', 'popular_series'),
          feed.of(kind).popular,
        ),
    for (final kind in kinds)
      for (final shelf in feed.of(kind).serviceShelves)
        PosterRow(
          title: tr(
            kind == MediaKind.movie ? 'popular_movies_on' : 'popular_series_on',
            namedArgs: <String, String>{'service': shelf.service.name},
          ),
          items: shelf.items,
          onSeeAll: () => onOpenService(shelf.service),
        ),
    ServiceRow(
      title: tr('streaming_services'),
      services: appStreamingServices,
      onOpen: onOpenService,
    ),
    ad,
    for (final kind in kinds)
      if (feed.of(kind).topRated.isNotEmpty)
        listRow(
          kind,
          HomeList.topRated,
          titled(kind, 'top_rated_movies', 'top_rated_series'),
          feed.of(kind).topRated,
        ),
    if (feed.of(MediaKind.movie).upcoming.isNotEmpty)
      listRow(
        MediaKind.movie,
        HomeList.upcoming,
        tr('upcoming_movies'),
        feed.of(MediaKind.movie).upcoming,
        badgeFor: (item) => _releaseBadge(context, item),
      ),
    // FlixQuest's categorized feed: a few genres at random, each laid out its
    // own way, labelled with its kind where both are on show.
    for (final category in feed.categories)
      CategorySection(
        key: ValueKey<String>(
          'category-${category.kind.name}-${category.genre.genreID}',
        ),
        category: category,
        kicker: both ? titled(category.kind, 'movies', 'series') : null,
        load: () => loadCategory(category),
        onSeeAll: () => onOpenCategory(category),
      ),
  ];
}

/// A row that may have nothing to show (an ad, the update notice): the gap
/// under it appears only when it does.
class HomeOptionalRow extends StatelessWidget {
  const HomeOptionalRow({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _GapBelowIfShown(gap: AppSpace.rowGap, child: child);
}

/// A hosted ad between Home's rows.
class HomeAdSlot extends HomeOptionalRow {
  HomeAdSlot({required this.placement, super.key})
      : super(
          child: _HostedAd(placement: placement),
        );

  final String placement;
}

class _HostedAd extends StatelessWidget {
  const _HostedAd({required this.placement});

  final String placement;

  @override
  Widget build(BuildContext context) => RemoteHostedAdsBanner(
        placement: placement,
        loadAds: () => ScraperApi(
          context.read<AppDependencyProvider>().flixquestAPIURL,
        ).getAds(),
      );
}

/// Puts [gap] under [child] only when the child takes up room, so an ad slot
/// with no ad leaves no hole between rows.
class _GapBelowIfShown extends SingleChildRenderObjectWidget {
  const _GapBelowIfShown({required this.gap, super.child});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGapBelowIfShown(gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGapBelowIfShown renderObject,
  ) =>
      renderObject.gap = gap;
}

class _RenderGapBelowIfShown extends RenderShiftedBox {
  _RenderGapBelowIfShown(this._gap) : super(null);

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size.zero);
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset.zero;
    final height = child.size.height;
    size = constraints.constrain(
      Size(child.size.width, height > 0 ? height + _gap : 0),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
      child: Column(
        children: <Widget>[
          Icon(PhosphorIcons.wifiSlash(), size: 36, color: palette.mutedText),
          const SizedBox(height: AppSpace.md),
          Text(
            tr('home_load_failed'),
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.lg),
          PillButton(label: tr('retry'), onPressed: onRetry),
        ],
      ),
    );
  }
}
