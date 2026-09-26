// ignore_for_file: avoid_unnecessary_containers
import 'dart:async';
import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/services/globle_method.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:readmore/readmore.dart';
import '../controllers/bookmark_database_controller.dart';
import '../provider/bookmark_provider.dart';
import '../functions/function.dart';
import '../models/recently_watched.dart';
import '../models/tv_stream_metadata.dart';
import '../provider/app_dependency_provider.dart';
import '../provider/recently_watched_provider.dart';
import '../screens/tv/tv_video_loader.dart';
import '../screens/common/live_tv_screen.dart';
import '../screens/tv/tv_episode_picker_sheet.dart';
import '../screens/tv/tvdetail_castandcrew.dart';
import '../screens/tv/tvepisode_castandcrew.dart';
import '../screens/tv/tvseason_castandcrew.dart';
import '../ui_components/tv_ui_components.dart';
import '../ui_components/app_ui_components.dart';
import '/models/dropdown_select.dart';
import '/models/filter_chip.dart';
import '/provider/settings_provider.dart';
import '/screens/person/guest_star_detail.dart';
import 'package:provider/provider.dart';
import '/api/endpoints.dart';
import '/constants/api_constants.dart';
import '../constants/app_constants.dart';
import '/models/credits.dart';
import '../functions/network.dart';
import '/models/genres.dart';
import '/models/images.dart';
import '/models/movie.dart';
import '/models/social_icons_icons.dart';
import '/models/tv.dart';
import '/models/videos.dart';
import '/models/watch_providers.dart';
import '/screens/person/cast_detail.dart';
import '/screens/person/createdby_detail.dart';
import '/screens/tv/episode_detail.dart';
import '/screens/tv/seasons_detail.dart';
import '/screens/tv/streaming_services_tvshows.dart';
import '/screens/tv/tv_detail.dart';
import '/screens/tv/genre_tv.dart';
import 'categorized_feed.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '/screens/person/crew_detail.dart';
import '/screens/common/photoview.dart';
import '/screens/tv/main_tv_list.dart';
import 'movie_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/widgets/common_widgets.dart';
import 'app_logo.dart';
import '../video_providers/scraper_api.dart';
import 'hosted_ads_banner.dart';

class MainTVDisplay extends StatefulWidget {
  const MainTVDisplay({
    this.onSearchPressed,
    this.onBookmarksPressed,
    super.key,
  });

  final VoidCallback? onSearchPressed;
  final VoidCallback? onBookmarksPressed;

  @override
  State<MainTVDisplay> createState() => _MainTVDisplayState();
}

class _MainTVDisplayState extends State<MainTVDisplay> {
  final ScrollController _feedController = ScrollController();
  bool _showCompactHeader = false;

  @override
  void initState() {
    super.initState();
    _feedController.addListener(_updateCompactHeader);
  }

  void _updateCompactHeader() {
    if (!mounted) return;
    final heroHeight =
        (MediaQuery.sizeOf(context).height * .48).clamp(410.0, 500.0);
    final threshold = heroHeight - MediaQuery.paddingOf(context).top;
    final shouldShow = _feedController.offset >= threshold;
    if (shouldShow != _showCompactHeader) {
      setState(() => _showCompactHeader = shouldShow);
    }
  }

  @override
  void dispose() {
    _feedController
      ..removeListener(_updateCompactHeader)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var rEpisodes = Provider.of<RecentProvider>(context).episodes;
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    final showLiveTV = context.watch<AppDependencyProvider>().displayLiveTV;
    void openLiveTV() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ChannelList()),
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _feedController,
          slivers: [
            SliverToBoxAdapter(
              child: DiscoverTV(
                discoverType: 'discover',
                includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                onSearchPressed: widget.onSearchPressed,
                onLiveTVPressed: showLiveTV ? openLiveTV : null,
                onBookmarksPressed: widget.onBookmarksPressed,
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                RemoteHostedAdsBanner(
                  placement: 'home_tv',
                  loadAds: () => ScraperApi(
                    context.read<AppDependencyProvider>().flixquestAPIURL,
                  ).getAds(),
                ),
                ScrollingTV(
                  includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                  title: tr('popular'),
                  api: Endpoints.popularTVUrl(lang),
                  discoverType: 'popular',
                  isTrending: false,
                ),
                rEpisodes.isEmpty
                    ? Container()
                    : ScrollingRecentEpisodes(episodesList: rEpisodes),
                ScrollingTV(
                  includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                  title: tr('trending_this_week'),
                  api: Endpoints.trendingTVUrl(lang),
                  discoverType: 'trending',
                  isTrending: true,
                ),
                RemoteHostedAdsBanner(
                  placement: 'home_tv',
                  loadAds: () => ScraperApi(
                    context.read<AppDependencyProvider>().flixquestAPIURL,
                  ).getAds(),
                ),
                ScrollingTV(
                  includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                  title: tr('top_rated'),
                  api: Endpoints.topRatedTVUrl(lang),
                  discoverType: 'top_rated',
                  isTrending: false,
                ),
                ScrollingTV(
                  includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                  title: tr('airing_today'),
                  api: Endpoints.airingTodayUrl(lang),
                  discoverType: 'airing_today',
                  isTrending: false,
                ),
                ScrollingTV(
                  includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                  title: tr('on_the_air'),
                  api: Endpoints.onTheAirUrl(lang),
                  discoverType: 'on_the_air',
                  isTrending: false,
                ),
                TVGenreListGrid(api: Endpoints.tvGenresUrl(lang)),
                RemoteHostedAdsBanner(
                  placement: 'home_tv',
                  loadAds: () => ScraperApi(
                    context.read<AppDependencyProvider>().flixquestAPIURL,
                  ).getAds(),
                ),
                const RandomCategorizedFeed(isTv: true),
                const TVShowsFromWatchProviders(),
              ]),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_showCompactHeader,
            child: AnimatedSlide(
              offset: _showCompactHeader ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showCompactHeader ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: AppFeedOverlayHeader(
                  title: tr('tv_series'),
                  onSearchPressed: widget.onSearchPressed,
                  actionLabel: showLiveTV ? tr('live_tv') : null,
                  actionIcon: showLiveTV ? PhosphorIcons.broadcast() : null,
                  onActionPressed: showLiveTV ? openLiveTV : null,
                  utilityIcon: PhosphorIcons.bookmarkSimple(),
                  utilityTooltip: 'Bookmarks',
                  onUtilityPressed: widget.onBookmarksPressed,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DiscoverTV extends StatefulWidget {
  final bool includeAdult;
  const DiscoverTV({
    required this.includeAdult,
    required this.discoverType,
    this.onSearchPressed,
    this.onLiveTVPressed,
    this.onBookmarksPressed,
    super.key,
  });

  final String discoverType;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTVPressed;
  final VoidCallback? onBookmarksPressed;
  @override
  DiscoverTVState createState() => DiscoverTVState();
}

class DiscoverTVState extends State<DiscoverTV>
    with AutomaticKeepAliveClientMixin {
  late double deviceHeight;
  late double deviceWidth;
  late double deviceAspectRatio;
  List<TV>? tvList;
  YearDropdownData yearDropdownData = YearDropdownData();
  final TVDatabaseController _bookmarkController = TVDatabaseController();
  final Set<int> _bookmarkedIds = <int>{};

  @override
  void initState() {
    super.initState();
    getData();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final items = await _bookmarkController.getTVList();
    if (!mounted) return;
    setState(() {
      _bookmarkedIds
        ..clear()
        ..addAll(items.map((item) => item.id).whereType<int>());
    });
  }

  Future<void> _toggleBookmark(TV item) async {
    final id = item.id;
    if (id == null) return;
    final saved = _bookmarkedIds.contains(id);
    final provider = Provider.of<BookmarkProvider>(context, listen: false);
    if (saved) {
      await provider.removeTV(id);
    } else {
      await provider.addTV(item);
    }
    if (!mounted) return;
    setState(() => saved ? _bookmarkedIds.remove(id) : _bookmarkedIds.add(id));
  }

  List<TVGenreFilterChipWidget> tvGenreList = <TVGenreFilterChipWidget>[
    TVGenreFilterChipWidget(
        genreName: tr('action_and_adventure'), genreValue: '10759'),
    TVGenreFilterChipWidget(genreName: tr('animation'), genreValue: '16'),
    TVGenreFilterChipWidget(genreName: tr('comedy'), genreValue: '35'),
    TVGenreFilterChipWidget(genreName: tr('crime'), genreValue: '80'),
    TVGenreFilterChipWidget(genreName: tr('documentary'), genreValue: '99'),
    TVGenreFilterChipWidget(genreName: tr('drama'), genreValue: '18'),
    TVGenreFilterChipWidget(genreName: tr('family'), genreValue: '10751'),
    TVGenreFilterChipWidget(genreName: tr('kids'), genreValue: '10762'),
    TVGenreFilterChipWidget(genreName: tr('mystery'), genreValue: '9648'),
    TVGenreFilterChipWidget(genreName: tr('news'), genreValue: '10763'),
    TVGenreFilterChipWidget(genreName: tr('reality'), genreValue: '10764'),
    TVGenreFilterChipWidget(
        genreName: tr('scifi_and_fantasy'), genreValue: '10765'),
    TVGenreFilterChipWidget(genreName: tr('soap'), genreValue: '10766'),
    TVGenreFilterChipWidget(genreName: tr('talk'), genreValue: '10767'),
    TVGenreFilterChipWidget(
        genreName: tr('war_and_politics'), genreValue: '10768'),
    TVGenreFilterChipWidget(genreName: tr('western'), genreValue: '37'),
  ];

  Future<void> getData() async {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final lang =
        Provider.of<SettingsProvider>(context, listen: false).appLanguage;

    final random = Random();
    final randomYear =
        (1990 + random.nextInt(DateTime.now().year - 1990 + 1)).toString();
    final randomGenre = tvGenreList.isNotEmpty
        ? tvGenreList[random.nextInt(tvGenreList.length)].genreValue
        : null;
    final randomPage = random.nextInt(5) + 1;

    final trendingFuture = fetchTV(
      Endpoints.trendingTVUrl(lang),
      isProxyEnabled,
      proxyUrl,
    );

    final randomDiscoverFuture = fetchTV(
      Endpoints.randomDiscoverTVUrl(
        lang,
        page: randomPage,
        year: randomYear,
        genreId: randomGenre,
      ),
      isProxyEnabled,
      proxyUrl,
    );

    try {
      final results = await Future.wait([trendingFuture, randomDiscoverFuture]);
      final trendingList = results[0];
      final randomList = results[1];

      final combined = <TV>[];
      final seenIds = <int>{};

      final validTrending = trendingList
          .where((item) =>
              (item.backdropPath != null || item.posterPath != null) &&
              item.id != null)
          .toList();

      final validRandom = randomList
          .where((item) =>
              (item.backdropPath != null || item.posterPath != null) &&
              item.id != null)
          .toList()
        ..shuffle(random);

      int tIndex = 0;
      int rIndex = 0;

      while ((tIndex < validTrending.length || rIndex < validRandom.length) &&
          combined.length < 10) {
        if (tIndex < validTrending.length) {
          final item = validTrending[tIndex++];
          if (seenIds.add(item.id!)) {
            combined.add(item);
          }
        }
        if (rIndex < validRandom.length && combined.length < 10) {
          final item = validRandom[rIndex++];
          if (seenIds.add(item.id!)) {
            combined.add(item);
          }
        }
      }

      if (mounted) {
        setState(() {
          tvList = combined.isNotEmpty ? combined : trendingList;
        });
      }
    } catch (_) {
      final fallback = await trendingFuture.catchError((_) => <TV>[]);
      if (mounted) {
        setState(() {
          tvList = fallback;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    deviceHeight = MediaQuery.of(context).size.height;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final appDependency = Provider.of<AppDependencyProvider>(context);
    final proxyUrl = appDependency.tmdbProxy;
    final showWatchNow = appDependency.displayWatchNowButton;
    final heroHeight = (deviceHeight * .48).clamp(410.0, 500.0);
    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: tvList == null
          ? const AppShimmerBlock(radius: 0)
          : tvList!.isEmpty
              ? Center(child: Text(tr('wow_odd'), style: kTextSmallBodyStyle))
              : AppCrossfadeCarousel(
                  itemCount: tvList!.take(10).length,
                  onItemTap: (index) {
                    final selected = tvList![index];
                    if (selected.id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TVDetailPage(
                          tvSeries: selected,
                          heroId: 'home_tv_${selected.id}',
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final item = tvList![index];
                    final path = item.backdropPath ?? item.posterPath;
                    final saved = _bookmarkedIds.contains(item.id);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: path == null
                              ? ''
                              : '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context)}original$path',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          placeholder: (_, __) =>
                              const AppShimmerBlock(radius: 0),
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/images/na_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0, .42, 1],
                              colors: [
                                Color(0x52000000),
                                Color(0x15000000),
                                Color(0xE6000000),
                              ],
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: AppLogo(
                                      fallbackAsset: 'assets/images/fq_svg.svg',
                                      width: 28,
                                      height: 28,
                                      fallbackColor:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.onLiveTVPressed != null) ...[
                                    _TVHeroLiveButton(
                                      onPressed: widget.onLiveTVPressed!,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  _TVHeroIconButton(
                                    key:
                                        const ValueKey('tv_bookmarks_shortcut'),
                                    icon: PhosphorIcons.bookmarkSimple(),
                                    tooltip: 'Bookmarks',
                                    onPressed: widget.onBookmarksPressed,
                                  ),
                                  const SizedBox(width: 8),
                                  _TVHeroIconButton(
                                    icon: PhosphorIcons.magnifyingGlass(),
                                    onPressed: widget.onSearchPressed,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 28,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'FigtreeSB',
                                  fontSize: 30,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                [
                                  if ((item.firstAirDate ?? '').length >= 4)
                                    item.firstAirDate!.substring(0, 4),
                                  if (item.voteAverage != null)
                                    '\u2605 ${item.voteAverage!.toStringAsFixed(1)}',
                                  if ((item.originalLanguage ?? '').isNotEmpty)
                                    item.originalLanguage!.toUpperCase(),
                                ].join('  \u2022  '),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  if (showWatchNow) ...[
                                    FilledButton.icon(
                                      onPressed: () => _watchTV(item),
                                      icon: Icon(PhosphorIcons.play()),
                                      label: Text(tr('watch_now')),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  OutlinedButton.icon(
                                    onPressed: () => _toggleBookmark(item),
                                    icon: Icon(saved
                                        ? PhosphorIcons.check()
                                        : PhosphorIcons.plus()),
                                    label: Text(tr('bookmark_home')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Future<void> _watchTV(TV item) async {
    if (item.id == null) return;
    if (!await checkConnection()) {
      if (!mounted) return;
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(content: Text(tr('check_connection'), maxLines: 3)),
        context,
      );
      return;
    }
    if (!mounted) return;
    final metadata = await showTVEpisodePickerSheet(context, series: item);
    if (!mounted || metadata == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVVideoLoader(
          download: false,
          metadata: metadata,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _TVHeroIconButton extends StatelessWidget {
  const _TVHeroIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .22),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _TVHeroLiveButton extends StatelessWidget {
  const _TVHeroLiveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: const ValueKey('tv_live_tv_shortcut'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.broadcast(), color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                tr('live_tv'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScrollingTV extends StatefulWidget {
  final String api, title;
  final dynamic discoverType;
  final bool isTrending;
  final bool? includeAdult;
  const ScrollingTV({
    super.key,
    required this.api,
    required this.title,
    this.discoverType,
    required this.isTrending,
    required this.includeAdult,
  });
  @override
  ScrollingTVState createState() => ScrollingTVState();
}

class ScrollingTVState extends State<ScrollingTV>
    with AutomaticKeepAliveClientMixin {
  late int index;
  List<TV>? tvList;
  final ScrollController _scrollController = ScrollController();
  int pageNum = 2;
  bool isLoading = false;

  void getMoreData() async {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setState(() {
          isLoading = true;
        });

        fetchTV('${widget.api}&page=$pageNum&include_adult=${widget.includeAdult}',
                isProxyEnabled, proxyUrl)
            .then((value) {
          if (mounted) {
            setState(() {
              tvList!.addAll(value);
              isLoading = false;
              pageNum++;
            });
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTV('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          tvList = value;
        });
      }
    });
    getMoreData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final cardWidth = AppUI.horizontalCardWidth(context);
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                            fontFamily: 'FigtreeSB',
                            fontSize: 21,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 12, 0),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return MainTVList(
                          api: widget.api,
                          discoverType: widget.discoverType,
                          isTrending: widget.isTrending,
                          includeAdult: widget.includeAdult,
                          title: widget.title);
                    }));
                  },
                  style: ButtonStyle(
                      maximumSize: WidgetStateProperty.all(const Size(200, 60)),
                      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ))),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: Text(tr('view_all')),
                  ),
                )),
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: cardWidth * 1.5 + 62,
          child: tvList == null
              ? scrollingMoviesAndTVShimmer(themeMode)
              : Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: tvList!.length,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (BuildContext context, int index) {
                          return Padding(
                            padding: EdgeInsets.only(
                              left:
                                  index == 0 ? AppUI.pagePadding(context) : 10,
                              top: 8,
                              bottom: 8,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => TVDetailPage(
                                            tvSeries: tvList![index],
                                            heroId:
                                                '${tvList![index].id}${widget.title}-${widget.discoverType}')));
                              },
                              child: SizedBox(
                                width: cardWidth,
                                child: Column(
                                  children: <Widget>[
                                    SizedBox(
                                      height: cardWidth * 1.5,
                                      child: Hero(
                                        tag:
                                            '${tvList![index].id}${widget.title}-${widget.discoverType}',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(AppUI.cardRadius),
                                                child: tvList![index]
                                                            .posterPath ==
                                                        null
                                                    ? Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity)
                                                    : CachedNetworkImage(
                                                        cacheManager:
                                                            cacheProp(),
                                                        fadeOutDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        fadeOutCurve:
                                                            Curves.easeOut,
                                                        fadeInDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    700),
                                                        fadeInCurve:
                                                            Curves.easeIn,
                                                        imageUrl: tvList![index]
                                                                    .posterPath ==
                                                                null
                                                            ? ''
                                                            : buildImageUrl(
                                                                    TMDB_BASE_IMAGE_URL,
                                                                    proxyUrl,
                                                                    isProxyEnabled,
                                                                    context) +
                                                                imageQuality +
                                                                tvList![index]
                                                                    .posterPath!,
                                                        imageBuilder: (context,
                                                                imageProvider) =>
                                                            Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            image:
                                                                DecorationImage(
                                                              image:
                                                                  imageProvider,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                        placeholder: (context,
                                                                url) =>
                                                            scrollingImageShimmer(
                                                                themeMode),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Image.asset(
                                                                'assets/images/na_logo.png',
                                                                fit: BoxFit
                                                                    .cover,
                                                                width: double
                                                                    .infinity,
                                                                height: double
                                                                    .infinity),
                                                      ),
                                              ),
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: AppRatingBadge(
                                                    rating: tvList![index]
                                                        .voteAverage,
                                                    compact: true,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 46,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            2, 10, 2, 0),
                                        child: Text(
                                          tvList![index].name!,
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'FigtreeSB',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Visibility(
                      visible: isLoading,
                      child: SizedBox(
                        width: cardWidth,
                        child: horizontalLoadMoreShimmer(themeMode),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingRecentEpisodes extends StatefulWidget {
  const ScrollingRecentEpisodes({required this.episodesList, super.key});

  final List<RecentEpisode> episodesList;

  @override
  State<ScrollingRecentEpisodes> createState() =>
      _ScrollingRecentEpisodesState();
}

class _ScrollingRecentEpisodesState extends State<ScrollingRecentEpisodes> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final imageQuality = context.watch<SettingsProvider>().imageQuality;
    final isProxyEnabled = context.watch<SettingsProvider>().enableProxy;
    final proxyUrl = context.watch<AppDependencyProvider>().tmdbProxy;
    final cardWidth =
        (MediaQuery.sizeOf(context).width * .58).clamp(210.0, 270.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: tr('recently_watched')),
        SizedBox(
          height: cardWidth * .56 + 82,
          child: ListView.separated(
            controller: _scrollController,
            padding:
                EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: widget.episodesList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final episode = widget.episodesList[index];
              final elapsed = (episode.elapsed ?? 0).toDouble();
              final total = elapsed + (episode.remaining ?? 0).toDouble();
              final episodeLabel =
                  'S${episode.seasonNum.toString().padLeft(2, '0')} · E${episode.episodeNum.toString().padLeft(2, '0')}';
              return SizedBox(
                width: cardWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppUI.cardRadius),
                  onLongPress: () => _deleteEpisode(episode),
                  onTap: () => _openEpisode(episode),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppUI.cardRadius),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              (episode.backdropPath ?? episode.posterPath) ==
                                      null
                                  ? Image.asset('assets/images/na_logo.png',
                                      fit: BoxFit.cover)
                                  : CachedNetworkImage(
                                      cacheManager: cacheProp(),
                                      imageUrl: buildImageUrl(
                                            TMDB_BASE_IMAGE_URL,
                                            proxyUrl,
                                            isProxyEnabled,
                                            context,
                                          ) +
                                          imageQuality +
                                          (episode.backdropPath ??
                                              episode.posterPath)!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          const AppShimmerBlock(),
                                      errorWidget: (_, __, ___) => Image.asset(
                                        'assets/images/na_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black54
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .72),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    episodeLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: Icon(PhosphorIcons.play(),
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 30),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _deleteEpisode(episode),
                                  icon: Icon(PhosphorIcons.x(), size: 18),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: total > 0 ? elapsed / total : 0,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        episode.seriesName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        episode.episodeName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _deleteEpisode(RecentEpisode episode) {
    context.read<RecentProvider>().deleteEpisode(
          episode.id!,
          episode.episodeNum!,
          episode.seasonNum!,
        );
  }

  Future<void> _openEpisode(RecentEpisode episode) async {
    final online = await checkConnection();
    if (!mounted) return;
    if (!online) {
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(content: Text(tr('check_connection'), maxLines: 3)),
        context,
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TVVideoLoader(
          download: false,
          metadata: TVStreamMetadata(
            elapsed: episode.elapsed,
            episodeId: episode.id,
            episodeName: episode.episodeName,
            episodeNumber: episode.episodeNum,
            posterPath: episode.posterPath,
            backdropPath: episode.backdropPath,
            seasonNumber: episode.seasonNum,
            seriesName: episode.seriesName,
            tvId: episode.seriesId,
            airDate: null,
          ),
        ),
      ),
    );
  }

  // Kept temporarily as a behavior reference while the refreshed rail settles.
  // ignore: unused_element
}

class ScrollingTVArtists extends StatefulWidget {
  final String? api, title, tapButtonText;
  final int id;
  final int? episodeNumber;
  final int? seasonNumber;
  final String passedFrom;
  const ScrollingTVArtists(
      {super.key,
      this.api,
      this.title,
      this.tapButtonText,
      required this.id,
      this.episodeNumber,
      this.seasonNumber,
      required this.passedFrom});
  @override
  ScrollingTVArtistsState createState() => ScrollingTVArtistsState();
}

class ScrollingTVArtistsState extends State<ScrollingTVArtists>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(
                        tr('cast'),
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
                onPressed: () {
                  if (credits != null) {
                    if (widget.passedFrom == 'seasons_detail') {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return TVSeasonCastAndCrew(
                          passedFrom: widget.passedFrom,
                          id: widget.id,
                          seasonNumber: widget.seasonNumber!,
                        );
                      }));
                    } else {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) {
                        return TVDetailCastAndCrew(
                          passedFrom: widget.passedFrom,
                          id: widget.id,
                        );
                      }));
                    }
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.transparent),
                  maximumSize: WidgetStateProperty.all(const Size(200, 60)),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.0),
                    ),
                  ),
                ),
                child: Text(
                  tr('see_all_cast_crew'),
                  textAlign: TextAlign.center,
                ))
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? detailCastShimmer(themeMode)
              : credits!.cast!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Center(
                            child: Text(
                          tr('no_cast_tv'),
                        )),
                      ))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: credits!.cast!.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return CastDetailPage(
                                  cast: credits!.cast![index],
                                  heroId: '${credits!.cast![index].id}'
                                      '${credits!.cast![index].creditId}'
                                      '${credits!.cast![index].castId}',
                                );
                              }));
                            },
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    flex: 6,
                                    child: SizedBox(
                                      width: 75,
                                      child: Hero(
                                        tag: '${credits!.cast![index].id}',
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(100.0),
                                          child: credits!.cast![index]
                                                      .profilePath ==
                                                  null
                                              ? Image.asset(
                                                  'assets/images/na_rect.png',
                                                  fit: BoxFit.cover,
                                                )
                                              : CachedNetworkImage(
                                                  cacheManager: cacheProp(),
                                                  fadeOutDuration:
                                                      const Duration(
                                                          milliseconds: 300),
                                                  fadeOutCurve: Curves.easeOut,
                                                  fadeInDuration:
                                                      const Duration(
                                                          milliseconds: 700),
                                                  fadeInCurve: Curves.easeIn,
                                                  imageUrl: buildImageUrl(
                                                          TMDB_BASE_IMAGE_URL,
                                                          proxyUrl,
                                                          isProxyEnabled,
                                                          context) +
                                                      imageQuality +
                                                      credits!.cast![index]
                                                          .profilePath!,
                                                  imageBuilder: (context,
                                                          imageProvider) =>
                                                      Container(
                                                    decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  placeholder: (context, url) =>
                                                      detailCastImageShimmer(
                                                          themeMode),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/na_rect.png',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        credits!.cast![index].name!,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVEpisodeCasts extends StatefulWidget {
  final String? api;
  final int? id;
  final int episodeNumber;
  final int seasonNumber;
  final String passedFrom;
  const ScrollingTVEpisodeCasts({
    super.key,
    this.api,
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.passedFrom,
  });
  @override
  ScrollingTVEpisodeCastsState createState() => ScrollingTVEpisodeCastsState();
}

class ScrollingTVEpisodeCastsState extends State<ScrollingTVEpisodeCasts>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        credits == null
            ? Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(
                              tr('cast'),
                              style: kTextHeaderStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : credits!.cast!.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const LeadingDot(),
                            Expanded(
                              child: Text(
                                tr('cast'),
                                style: kTextHeaderStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Center(
                          child: Text(tr('no_cast_episode'),
                              textAlign: TextAlign.center)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              const LeadingDot(),
                              Expanded(
                                child: Text(
                                  tr('cast'),
                                  style: kTextHeaderStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                          onPressed: () {
                            if (credits != null) {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return TVEpisodeCastAndCrew(
                                  episodeNumber: widget.episodeNumber,
                                  seasonNumber: widget.seasonNumber,
                                  id: widget.id!,
                                );
                              }));
                            }
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.all(Colors.transparent),
                            maximumSize:
                                WidgetStateProperty.all(const Size(200, 60)),
                            shape:
                                WidgetStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                            ),
                          ),
                          child: Text(tr('see_all_cast_crew')))
                    ],
                  ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? detailCastShimmer(themeMode)
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: credits!.cast!.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return CastDetailPage(
                              cast: credits!.cast![index],
                              heroId: '${credits!.cast![index].id}',
                            );
                          }));
                        },
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  width: 75,
                                  child: Hero(
                                    tag: '${credits!.cast![index].id}',
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                      child: credits!
                                                  .cast![index].profilePath ==
                                              null
                                          ? Image.asset(
                                              'assets/images/na_rect.png',
                                              fit: BoxFit.cover,
                                            )
                                          : CachedNetworkImage(
                                              cacheManager: cacheProp(),
                                              fadeOutDuration: const Duration(
                                                  milliseconds: 300),
                                              fadeOutCurve: Curves.easeOut,
                                              fadeInDuration: const Duration(
                                                  milliseconds: 700),
                                              fadeInCurve: Curves.easeIn,
                                              imageUrl: buildImageUrl(
                                                      TMDB_BASE_IMAGE_URL,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  credits!.cast![index]
                                                      .profilePath!,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      Container(
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              placeholder: (context, url) =>
                                                  detailCastImageShimmer(
                                                      themeMode),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Image.asset(
                                                'assets/images/na_rect.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    credits!.cast![index].name!,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVEpisodeGuestStars extends StatefulWidget {
  final String? api;
  const ScrollingTVEpisodeGuestStars({
    super.key,
    this.api,
  });
  @override
  ScrollingTVEpisodeGuestStarsState createState() =>
      ScrollingTVEpisodeGuestStarsState();
}

class ScrollingTVEpisodeGuestStarsState
    extends State<ScrollingTVEpisodeGuestStars>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final analytics = Provider.of<SettingsProvider>(context).analytics;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        credits == null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        tr('guest_stars'),
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              )
            : credits!.episodeGuestStars == null ||
                    credits!.episodeGuestStars!.isEmpty
                ? const SizedBox()
                : Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          tr('guest_stars'),
                          style: kTextHeaderStyle,
                        ),
                      ),
                    ],
                  ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: credits!.episodeGuestStars!.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          analytics.trackPersonPageView(
                            personName: credits!.episodeGuestStars![index].name,
                            personId: credits!.episodeGuestStars![index].id,
                          );
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return GuestStarDetailPage(
                              cast: credits!.episodeGuestStars![index],
                              heroId:
                                  '${credits!.episodeGuestStars![index].id}',
                            );
                          }));
                        },
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  width: 75,
                                  child: Hero(
                                    tag:
                                        '${credits!.episodeGuestStars![index].id}',
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                      child: credits!.episodeGuestStars![index]
                                                  .profilePath ==
                                              null
                                          ? Image.asset(
                                              'assets/images/na_rect.png',
                                              fit: BoxFit.cover,
                                            )
                                          : CachedNetworkImage(
                                              cacheManager: cacheProp(),
                                              fadeOutDuration: const Duration(
                                                  milliseconds: 300),
                                              fadeOutCurve: Curves.easeOut,
                                              fadeInDuration: const Duration(
                                                  milliseconds: 700),
                                              fadeInCurve: Curves.easeIn,
                                              imageUrl: buildImageUrl(
                                                      TMDB_BASE_IMAGE_URL,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  credits!
                                                      .episodeGuestStars![index]
                                                      .profilePath!,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      Container(
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              placeholder: (context, url) =>
                                                  scrollingImageShimmer(
                                                      themeMode),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Image.asset(
                                                'assets/images/na_rect.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    credits!.episodeGuestStars![index].name!,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVEpisodeCrew extends StatefulWidget {
  final String? api;
  const ScrollingTVEpisodeCrew({
    super.key,
    this.api,
  });
  @override
  ScrollingTVEpisodeCrewState createState() => ScrollingTVEpisodeCrewState();
}

class ScrollingTVEpisodeCrewState extends State<ScrollingTVEpisodeCrew>
    with AutomaticKeepAliveClientMixin {
  Credits? credits;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          credits = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final analytics = Provider.of<SettingsProvider>(context).analytics;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        credits == null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        tr('crew'),
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              )
            : credits!.crew == null || credits!.crew!.isEmpty
                ? const SizedBox()
                : Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          tr('crew'),
                          style: kTextHeaderStyle,
                        ),
                      ),
                    ],
                  ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: credits == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: credits!.crew!.length,
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          analytics.trackPersonPageView(
                            personName: credits!.crew![index].name,
                            personId: credits!.crew![index].id,
                          );
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return CrewDetailPage(
                              crew: credits!.crew![index],
                              heroId: '${credits!.crew![index].id}',
                            );
                          }));
                        },
                        child: SizedBox(
                          width: 100,
                          child: Column(
                            children: <Widget>[
                              Expanded(
                                flex: 6,
                                child: SizedBox(
                                  width: 75,
                                  child: Hero(
                                    tag: '${credits!.crew![index].id}',
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                      child: credits!
                                                  .crew![index].profilePath ==
                                              null
                                          ? Image.asset(
                                              'assets/images/na_rect.png',
                                              fit: BoxFit.cover,
                                            )
                                          : CachedNetworkImage(
                                              cacheManager: cacheProp(),
                                              fadeOutDuration: const Duration(
                                                  milliseconds: 300),
                                              fadeOutCurve: Curves.easeOut,
                                              fadeInDuration: const Duration(
                                                  milliseconds: 700),
                                              fadeInCurve: Curves.easeIn,
                                              imageUrl: buildImageUrl(
                                                      TMDB_BASE_IMAGE_URL,
                                                      proxyUrl,
                                                      isProxyEnabled,
                                                      context) +
                                                  imageQuality +
                                                  credits!.crew![index]
                                                      .profilePath!,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      Container(
                                                decoration: BoxDecoration(
                                                  image: DecorationImage(
                                                    image: imageProvider,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              placeholder: (context, url) =>
                                                  scrollingImageShimmer(
                                                      themeMode),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Image.asset(
                                                'assets/images/na_rect.png',
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    credits!.crew![index].name!,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class ScrollingTVCreators extends StatefulWidget {
  final String? api, title, tapButtonText;
  const ScrollingTVCreators({
    super.key,
    this.api,
    this.title,
    this.tapButtonText,
  });
  @override
  ScrollingTVCreatorsState createState() => ScrollingTVCreatorsState();
}

class ScrollingTVCreatorsState extends State<ScrollingTVCreators>
    with AutomaticKeepAliveClientMixin {
  TVDetails? tvDetails;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTVDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvDetails = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(
                        tr('created_by'),
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: 160,
          child: tvDetails == null
              ? detailCastShimmer(themeMode)
              : tvDetails!.createdBy!.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                          child: Text(tr('no_creators'),
                              textAlign: TextAlign.center)),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tvDetails!.createdBy!.length,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) {
                                return CreatedByPersonDetailPage(
                                  createdBy: tvDetails!.createdBy![index],
                                  heroId: '${tvDetails!.createdBy![index].id}'
                                      '${tvDetails!.createdBy![index].name}',
                                );
                              }));
                            },
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: <Widget>[
                                  Expanded(
                                    flex: 6,
                                    child: Hero(
                                      tag:
                                          '${tvDetails!.createdBy![index].id!}',
                                      child: SizedBox(
                                        width: 75,
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(100.0),
                                          child: tvDetails!.createdBy![index]
                                                      .profilePath ==
                                                  null
                                              ? Image.asset(
                                                  'assets/images/na_rect.png',
                                                  fit: BoxFit.cover,
                                                )
                                              : CachedNetworkImage(
                                                  cacheManager: cacheProp(),
                                                  fadeOutDuration:
                                                      const Duration(
                                                          milliseconds: 300),
                                                  fadeOutCurve: Curves.easeOut,
                                                  fadeInDuration:
                                                      const Duration(
                                                          milliseconds: 700),
                                                  fadeInCurve: Curves.easeIn,
                                                  imageUrl: buildImageUrl(
                                                          TMDB_BASE_IMAGE_URL,
                                                          proxyUrl,
                                                          isProxyEnabled,
                                                          context) +
                                                      imageQuality +
                                                      tvDetails!
                                                          .createdBy![index]
                                                          .profilePath!,
                                                  imageBuilder: (context,
                                                          imageProvider) =>
                                                      Container(
                                                    decoration: BoxDecoration(
                                                      image: DecorationImage(
                                                        image: imageProvider,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  placeholder: (context, url) =>
                                                      detailCastImageShimmer(
                                                          themeMode),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          Image.asset(
                                                    'assets/images/na_rect.png',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        tvDetails!.createdBy![index].name!,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TVImagesDisplay extends StatefulWidget {
  final String? api, title, name;
  const TVImagesDisplay({super.key, this.api, this.name, this.title});

  @override
  TVImagesDisplayState createState() => TVImagesDisplayState();
}

class TVImagesDisplayState extends State<TVImagesDisplay> {
  Images? tvImages;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchImages(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvImages = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const LeadingDot(),
                      Expanded(
                        child: Text(
                          widget.title!,
                          style: kTextHeaderStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              height: 260,
              child: tvImages == null
                  ? detailImageShimmer(themeMode)
                  : CarouselSlider(
                      options: CarouselOptions(
                        enableInfiniteScroll: false,
                        viewportFraction: 1,
                      ),
                      items: [
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                      alignment:
                                          AlignmentDirectional.bottomStart,
                                      children: [
                                        SizedBox(
                                          height: 180,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(AppUI.cardRadius),
                                            child: tvImages!.poster!.isEmpty
                                                ? Image.asset(
                                                    'assets/images/na_logo.png',
                                                    fit: BoxFit.cover,
                                                  )
                                                : CachedNetworkImage(
                                                    cacheManager: cacheProp(),
                                                    fadeOutDuration:
                                                        const Duration(
                                                            milliseconds: 300),
                                                    fadeOutCurve:
                                                        Curves.easeOut,
                                                    fadeInDuration:
                                                        const Duration(
                                                            milliseconds: 700),
                                                    fadeInCurve: Curves.easeIn,
                                                    imageUrl: buildImageUrl(
                                                            TMDB_BASE_IMAGE_URL,
                                                            proxyUrl,
                                                            isProxyEnabled,
                                                            context) +
                                                        imageQuality +
                                                        tvImages!.poster![0]
                                                            .posterPath!,
                                                    imageBuilder: (context,
                                                            imageProvider) =>
                                                        GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(context,
                                                            MaterialPageRoute(
                                                                builder:
                                                                    ((context) {
                                                          return HeroPhotoView(
                                                            posters: tvImages!
                                                                .poster!,
                                                            name: widget.name,
                                                            imageType: 'poster',
                                                          );
                                                        })));
                                                      },
                                                      child: Hero(
                                                        tag: buildImageUrl(
                                                                TMDB_BASE_IMAGE_URL,
                                                                proxyUrl,
                                                                isProxyEnabled,
                                                                context) +
                                                            imageQuality +
                                                            tvImages!.poster![0]
                                                                .posterPath!,
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            image:
                                                                DecorationImage(
                                                              image:
                                                                  imageProvider,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    placeholder: (context,
                                                            url) =>
                                                        detailImageImageSimmer(
                                                            themeMode),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Image.asset(
                                                      'assets/images/na_logo.png',
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            color: Colors.black38,
                                            child: Text(
                                                tvImages!.poster!.length == 1
                                                    ? tr('poster_singular',
                                                        namedArgs: {
                                                            'poster': tvImages!
                                                                .poster!.length
                                                                .toString()
                                                          })
                                                    : tr('poster_plural',
                                                        namedArgs: {
                                                            'poster': tvImages!
                                                                .poster!.length
                                                                .toString()
                                                          })),
                                          ),
                                        )
                                      ]),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                      alignment:
                                          AlignmentDirectional.bottomStart,
                                      children: [
                                        SizedBox(
                                          height: 180,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(AppUI.cardRadius),
                                            child: tvImages!.backdrop!.isEmpty
                                                ? Image.asset(
                                                    'assets/images/na_logo.png',
                                                    fit: BoxFit.cover,
                                                  )
                                                : CachedNetworkImage(
                                                    cacheManager: cacheProp(),
                                                    fadeOutDuration:
                                                        const Duration(
                                                            milliseconds: 300),
                                                    fadeOutCurve:
                                                        Curves.easeOut,
                                                    fadeInDuration:
                                                        const Duration(
                                                            milliseconds: 700),
                                                    fadeInCurve: Curves.easeIn,
                                                    imageUrl: buildImageUrl(
                                                            TMDB_BASE_IMAGE_URL,
                                                            proxyUrl,
                                                            isProxyEnabled,
                                                            context) +
                                                        imageQuality +
                                                        tvImages!.backdrop![0]
                                                            .filePath!,
                                                    imageBuilder: (context,
                                                            imageProvider) =>
                                                        GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(context,
                                                            MaterialPageRoute(
                                                                builder:
                                                                    ((context) {
                                                          return HeroPhotoView(
                                                            backdrops: tvImages!
                                                                .backdrop!,
                                                            name: widget.name,
                                                            imageType:
                                                                'backdrop',
                                                          );
                                                        })));
                                                      },
                                                      child: Hero(
                                                        tag: buildImageUrl(
                                                                TMDB_BASE_IMAGE_URL,
                                                                proxyUrl,
                                                                isProxyEnabled,
                                                                context) +
                                                            imageQuality +
                                                            tvImages!
                                                                .backdrop![0]
                                                                .filePath!,
                                                        child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            image:
                                                                DecorationImage(
                                                              image:
                                                                  imageProvider,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    placeholder: (context,
                                                            url) =>
                                                        detailImageImageSimmer(
                                                            themeMode),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Image.asset(
                                                      'assets/images/na_logo.png',
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            color: Colors.black38,
                                            child: Text(
                                                tvImages!.backdrop!.length == 1
                                                    ? tr('backdrop_singular',
                                                        namedArgs: {
                                                            'backdrop':
                                                                tvImages!
                                                                    .backdrop!
                                                                    .length
                                                                    .toString()
                                                          })
                                                    : tr('backdrop_plural',
                                                        namedArgs: {
                                                            'backdrop':
                                                                tvImages!
                                                                    .backdrop!
                                                                    .length
                                                                    .toString()
                                                          })),
                                          ),
                                        )
                                      ]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class TVSeasonImagesDisplay extends StatefulWidget {
  final String? api, title, name;
  const TVSeasonImagesDisplay({super.key, this.api, this.name, this.title});

  @override
  TVSeasonImagesDisplayState createState() => TVSeasonImagesDisplayState();
}

class TVSeasonImagesDisplayState extends State<TVSeasonImagesDisplay> {
  Images? tvImages;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchImages(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvImages = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: [
        tvImages == null
            ? Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(widget.title!,
                                style:
                                    kTextHeaderStyle /* style: widget.themeData!.textTheme.bodyText1*/
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(widget.title!,
                                style:
                                    kTextHeaderStyle /*style: widget.themeData!.textTheme.bodyText1*/
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        Container(
          child: SizedBox(
            width: double.infinity,
            height: 200,
            child: tvImages == null
                ? detailImageShimmer(themeMode)
                : CarouselSlider(
                    options: CarouselOptions(
                      disableCenter: false,
                      viewportFraction: 0.4,
                      enlargeCenterPage: false,
                      autoPlay: false,
                      enableInfiniteScroll: false,
                    ),
                    items: [
                      Container(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Stack(
                            alignment: Alignment.bottomLeft,
                            children: [
                              SizedBox(
                                width: 125,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppUI.cardRadius),
                                  child: tvImages!.poster!.isEmpty
                                      ? Image.asset('assets/images/na_logo.png',
                                          fit: BoxFit.cover,
                                          height: double.infinity)
                                      : CachedNetworkImage(
                                          cacheManager: cacheProp(),
                                          fadeOutDuration:
                                              const Duration(milliseconds: 300),
                                          fadeOutCurve: Curves.easeOut,
                                          fadeInDuration:
                                              const Duration(milliseconds: 700),
                                          fadeInCurve: Curves.easeIn,
                                          imageUrl: buildImageUrl(
                                                  TMDB_BASE_IMAGE_URL,
                                                  proxyUrl,
                                                  isProxyEnabled,
                                                  context) +
                                              imageQuality +
                                              tvImages!.poster![0].posterPath!,
                                          imageBuilder:
                                              (context, imageProvider) =>
                                                  GestureDetector(
                                            onTap: () {
                                              Navigator.push(context,
                                                  MaterialPageRoute(
                                                      builder: (context) {
                                                return HeroPhotoView(
                                                  posters: tvImages!.poster!,
                                                  name: widget.name,
                                                  imageType: 'poster',
                                                );
                                              }));
                                            },
                                            child: Container(
                                              decoration: BoxDecoration(
                                                image: DecorationImage(
                                                  image: imageProvider,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                          placeholder: (context, url) =>
                                              scrollingImageShimmer(themeMode),
                                          errorWidget: (context, url, error) =>
                                              Image.asset(
                                                  'assets/images/na_logo.png',
                                                  fit: BoxFit.cover,
                                                  height: double.infinity),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  color: Colors.black38,
                                  child: Text(tvImages!.poster!.length == 1
                                      ? tr('poster_singular', namedArgs: {
                                          'poster': tvImages!.poster!.length
                                              .toString()
                                        })
                                      : tr('poster_plural', namedArgs: {
                                          'poster': tvImages!.poster!.length
                                              .toString()
                                        })),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class TVEpisodeImagesDisplay extends StatefulWidget {
  final String? api, title, name;
  const TVEpisodeImagesDisplay({super.key, this.api, this.name, this.title});

  @override
  TVEpisodeImagesDisplayState createState() => TVEpisodeImagesDisplayState();
}

class TVEpisodeImagesDisplayState extends State<TVEpisodeImagesDisplay> {
  Images? tvImages;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchImages(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvImages = value;
          // tvImages = Images(still: []);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: [
        tvImages == null
            ? Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(widget.title!,
                                style:
                                    kTextHeaderStyle /* style: widget.themeData!.textTheme.bodyText1*/
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(widget.title!,
                                style:
                                    kTextHeaderStyle /*style: widget.themeData!.textTheme.bodyText1*/
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        Container(
          child: SizedBox(
            width: double.infinity,
            height: 180,
            child: tvImages == null
                ? detailImageShimmer(themeMode)
                : CarouselSlider(
                    options: CarouselOptions(
                        disableCenter: false,
                        viewportFraction: 0.8,
                        enlargeCenterPage: false,
                        autoPlay: true,
                        enableInfiniteScroll: false),
                    items: [
                      Container(
                        child: Stack(
                          alignment: AlignmentDirectional.bottomStart,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppUI.cardRadius),
                                child: tvImages!.still!.isEmpty
                                    ? Image.asset('assets/images/na_logo.png',
                                        fit: BoxFit.cover,
                                        width: double.infinity)
                                    : CachedNetworkImage(
                                        cacheManager: cacheProp(),
                                        fadeOutDuration:
                                            const Duration(milliseconds: 300),
                                        fadeOutCurve: Curves.easeOut,
                                        fadeInDuration:
                                            const Duration(milliseconds: 700),
                                        fadeInCurve: Curves.easeIn,
                                        imageUrl: buildImageUrl(
                                                TMDB_BASE_IMAGE_URL,
                                                proxyUrl,
                                                isProxyEnabled,
                                                context) +
                                            imageQuality +
                                            tvImages!.still![0].stillPath!,
                                        imageBuilder:
                                            (context, imageProvider) =>
                                                GestureDetector(
                                          onTap: () {
                                            Navigator.push(context,
                                                MaterialPageRoute(
                                                    builder: (context) {
                                              return HeroPhotoView(
                                                stills: tvImages!.still!,
                                                name: widget.name,
                                                imageType: 'still',
                                              );
                                            }));
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              image: DecorationImage(
                                                image: imageProvider,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        ),
                                        placeholder: (context, url) =>
                                            detailImageImageSimmer(themeMode),
                                        errorWidget: (context, url, error) =>
                                            Image.asset(
                                                'assets/images/na_logo.png',
                                                fit: BoxFit.cover,
                                                width: double.infinity),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                color: Colors.black38,
                                child: Text(tvImages!.still!.length == 1
                                    ? tr('still_singular', namedArgs: {
                                        'still':
                                            tvImages!.still!.length.toString()
                                      })
                                    : tr('still_plural', namedArgs: {
                                        'still':
                                            tvImages!.still!.length.toString()
                                      })),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class TVVideosDisplay extends StatefulWidget {
  final String? api, title, api2;
  const TVVideosDisplay({super.key, this.api, this.title, this.api2});

  @override
  TVVideosDisplayState createState() => TVVideosDisplayState();
}

class TVVideosDisplayState extends State<TVVideosDisplay> {
  Videos? tvVideos;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchVideos(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvVideos = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool playButtonVisibility = true;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return Column(
      children: [
        tvVideos == null
            ? Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(widget.title!,
                                style:
                                    kTextHeaderStyle /* style: widget.themeData!.textTheme.bodyText1*/
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(widget.title!,
                                style:
                                    kTextHeaderStyle /*style: widget.themeData!.textTheme.bodyText1*/
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        Container(
          child: SizedBox(
            width: double.infinity,
            height: 230,
            child: tvVideos == null
                ? detailVideoShimmer(themeMode)
                : tvVideos!.result!.isEmpty
                    ? SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: Center(
                            child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child:
                              Text(tr('no_video'), textAlign: TextAlign.center),
                        )),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: CarouselSlider.builder(
                          options: CarouselOptions(
                            disableCenter: true,
                            viewportFraction: 0.8,
                            enlargeCenterPage: false,
                            autoPlay: true,
                          ),
                          itemBuilder:
                              (BuildContext context, int index, pageViewIndex) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: () {
                                  launchUrl(
                                      Uri.parse(YOUTUBE_BASE_URL +
                                          tvVideos!.result![index].videoLink!),
                                      mode: LaunchMode.externalApplication);
                                },
                                child: SizedBox(
                                  height: 150,
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 130,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(AppUI.cardRadius),
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  CachedNetworkImage(
                                                    cacheManager: cacheProp(),
                                                    fadeOutDuration:
                                                        const Duration(
                                                            milliseconds: 300),
                                                    fadeOutCurve:
                                                        Curves.easeOut,
                                                    fadeInDuration:
                                                        const Duration(
                                                            milliseconds: 700),
                                                    fadeInCurve: Curves.easeIn,
                                                    imageUrl:
                                                        '$YOUTUBE_THUMBNAIL_URL${tvVideos!.result![index].videoLink!}/hqdefault.jpg',
                                                    imageBuilder: (context,
                                                            imageProvider) =>
                                                        Container(
                                                      decoration: BoxDecoration(
                                                        image: DecorationImage(
                                                          image: imageProvider,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    ),
                                                    placeholder: (context,
                                                            url) =>
                                                        detailVideoImageShimmer(
                                                            themeMode),
                                                    errorWidget:
                                                        (context, url, error) =>
                                                            Image.asset(
                                                      'assets/images/na_logo.png',
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  Visibility(
                                                    visible:
                                                        playButtonVisibility,
                                                    child: SizedBox(
                                                      height: 90,
                                                      width: 90,
                                                      child: Icon(
                                                        PhosphorIcons.play(),
                                                        size: 90,
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          tvVideos!.result![index].name!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          itemCount: tvVideos!.result!.length,
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}

class TVCastTab extends StatefulWidget {
  final String? api;
  const TVCastTab({
    super.key,
    this.api,
  });

  @override
  TVCastTabState createState() => TVCastTabState();
}

class TVCastTabState extends State<TVCastTab>
    with AutomaticKeepAliveClientMixin<TVCastTab> {
  Credits? credits;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) setState(() => credits = value);
    }).onError((Object e, _) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (error != null) {
      return AppEmptyState(
        icon: PhosphorIcons.cloudSlash(),
        title: tr('error_occured'),
        message: tr('check_connection'),
        action: FilledButton(
          onPressed: () => setState(() {
            error = null;
            _load();
          }),
          child: Text(tr('retry')),
        ),
      );
    }
    if (credits == null) return const AppPersonListShimmer();
    final cast = credits!.cast ?? const <Cast>[];
    if (cast.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.usersThree(),
        title: tr('cast'),
        message: tr('no_cast_tv'),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        24,
      ),
      itemCount: cast.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final person = cast[index];
        final roles = person.roles;
        final episodeCount =
            roles == null || roles.isEmpty ? null : roles.first.episodeCount;
        return AppPersonTile(
          name: person.name ?? tr('not_available'),
          subtitle: (person.character ?? '').isEmpty
              ? tr('as_empty')
              : tr('as', namedArgs: {'character': person.character!}),
          detail: episodeCount == null
              ? null
              : episodeCount == 1
                  ? tr('single_episode', namedArgs: {'count': '$episodeCount'})
                  : tr('multi_episode', namedArgs: {'count': '$episodeCount'}),
          avatar: Hero(
            tag: 'tv_cast_${person.creditId}',
            child: PersonAvatar(profilePath: person.profilePath),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CastDetailPage(
                cast: person,
                heroId: 'tv_cast_${person.creditId}',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TVSeasonsTab extends StatefulWidget {
  final String? api;
  final int? tvId;
  final String? seriesName;
  final bool? adult;
  const TVSeasonsTab(
      {super.key, this.api, this.tvId, this.seriesName, required this.adult});

  @override
  TVSeasonsTabState createState() => TVSeasonsTabState();
}

class TVSeasonsTabState extends State<TVSeasonsTab>
    with AutomaticKeepAliveClientMixin<TVSeasonsTab> {
  TVDetails? tvDetails;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTVDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvDetails = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    super.build(context);
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return tvDetails == null
        ? Container(child: tvDetailsSeasonsTabShimmer(themeMode))
        : tvDetails!.seasons!.isEmpty
            ? Center(
                child: Text(
                  tr('no_season_tv'),
                  style: kTextSmallHeaderStyle,
                  textAlign: TextAlign.center,
                ),
              )
            : Container(
                child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                        itemCount: tvDetails!.seasons!.length,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SeasonsDetail(
                                          seriesName: widget.seriesName,
                                          tvId: widget.tvId,
                                          tvDetails: tvDetails!,
                                          seasons: tvDetails!.seasons![index],
                                          heroId:
                                              '${tvDetails!.seasons![index].seasonId}')));
                            },
                            child: Container(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 0.0,
                                  bottom: 5.0,
                                  left: 15,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      // crossAxisAlignment:
                                      //     CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right: 30.0),
                                          child: SizedBox(
                                            width: 85,
                                            height: 130,
                                            child: Hero(
                                              tag:
                                                  '${tvDetails!.seasons![index].seasonId}',
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(AppUI.cardRadius),
                                                child: tvDetails!
                                                            .seasons![index]
                                                            .posterPath ==
                                                        null
                                                    ? Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                      )
                                                    : CachedNetworkImage(
                                                        cacheManager:
                                                            cacheProp(),
                                                        fadeOutDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    300),
                                                        fadeOutCurve:
                                                            Curves.easeOut,
                                                        fadeInDuration:
                                                            const Duration(
                                                                milliseconds:
                                                                    700),
                                                        fadeInCurve:
                                                            Curves.easeIn,
                                                        imageUrl: buildImageUrl(
                                                                TMDB_BASE_IMAGE_URL,
                                                                proxyUrl,
                                                                isProxyEnabled,
                                                                context) +
                                                            imageQuality +
                                                            tvDetails!
                                                                .seasons![index]
                                                                .posterPath!,
                                                        imageBuilder: (context,
                                                                imageProvider) =>
                                                            Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            image:
                                                                DecorationImage(
                                                              image:
                                                                  imageProvider,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                        placeholder: (context,
                                                                url) =>
                                                            recommendationAndSimilarTabImageShimmer(
                                                                themeMode),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Image.asset(
                                                          'assets/images/na_logo.png',
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tvDetails!
                                                    .seasons![index].name!,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    fontFamily: 'FigtreeSB',
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                    Divider(
                                      color: themeMode == 'light'
                                          ? Colors.black54
                                          : Colors.white54,
                                      thickness: 1,
                                      endIndent: 20,
                                      indent: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              ));
  }

  @override
  bool get wantKeepAlive => true;
}

class TVCrewTab extends StatefulWidget {
  final String? api;
  const TVCrewTab({super.key, this.api});

  @override
  TVCrewTabState createState() => TVCrewTabState();
}

class TVCrewTabState extends State<TVCrewTab>
    with AutomaticKeepAliveClientMixin<TVCrewTab> {
  Credits? credits;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) setState(() => credits = value);
    }).onError((Object e, _) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (error != null) {
      return AppEmptyState(
        icon: PhosphorIcons.cloudSlash(),
        title: tr('error_occured'),
        message: tr('check_connection'),
        action: FilledButton(
          onPressed: () => setState(() {
            error = null;
            _load();
          }),
          child: Text(tr('retry')),
        ),
      );
    }
    if (credits == null) return const AppPersonListShimmer();
    final crew = credits!.crew ?? const <Crew>[];
    if (crew.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.wrench(),
        title: tr('crew'),
        message: tr('no_crew_movie'),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        24,
      ),
      itemCount: crew.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final person = crew[index];
        return AppPersonTile(
          name: person.name ?? tr('not_available'),
          subtitle: (person.department ?? '').isEmpty
              ? tr('job_empty')
              : tr('job', namedArgs: {'job': person.department!}),
          detail: (person.job ?? '').isEmpty ? null : person.job,
          avatar: Hero(
            tag: 'tv_crew_${person.creditId}',
            child: PersonAvatar(profilePath: person.profilePath),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CrewDetailPage(
                crew: person,
                heroId: 'tv_crew_${person.creditId}',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TVRecommendationsTab extends StatefulWidget {
  final String api;
  final int tvId;
  final bool? includeAdult;
  const TVRecommendationsTab(
      {super.key,
      required this.api,
      required this.tvId,
      required this.includeAdult});

  @override
  TVRecommendationsTabState createState() => TVRecommendationsTabState();
}

class TVRecommendationsTabState extends State<TVRecommendationsTab>
    with AutomaticKeepAliveClientMixin {
  List<TV>? tvList;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTV('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          tvList = value;
        });
      }
    });
    getMoreData();
  }

  final _scrollController = ScrollController();

  int pageNum = 2;
  bool isLoading = false;

  void getMoreData() async {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setState(() {
          isLoading = true;
        });
        final isProxyEnabled =
            Provider.of<SettingsProvider>(context, listen: false).enableProxy;
        final proxyUrl =
            Provider.of<AppDependencyProvider>(context, listen: false)
                .tmdbProxy;
        fetchTV('${widget.api}&page=$pageNum&include_adult=${widget.includeAdult}',
                isProxyEnabled, proxyUrl)
            .then((value) {
          if (mounted) {
            setState(() {
              tvList!.addAll(value);
              isLoading = false;
              pageNum++;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const LeadingDot(),
                      Expanded(
                        child: Text(
                          tr('tv_recommendations'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kTextHeaderStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 250,
            child: tvList == null || widget.includeAdult == null
                ? scrollingMoviesAndTVShimmer(themeMode)
                : tvList!.isEmpty
                    ? Text(
                        tr('no_recommendations_tv'),
                        textAlign: TextAlign.center,
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: HorizontalScrollingTVList(
                                scrollController: _scrollController,
                                tvList: tvList,
                                imageQuality: imageQuality,
                                themeMode: themeMode),
                          ),
                          Visibility(
                            visible: isLoading,
                            child: SizedBox(
                              width: 110,
                              child: horizontalLoadMoreShimmer(themeMode),
                            ),
                          ),
                        ],
                      ),
          ),
          Divider(
            color: themeMode == 'light' ? Colors.black54 : Colors.white54,
            thickness: 1,
            endIndent: 20,
            indent: 10,
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class SimilarTVTab extends StatefulWidget {
  final String api;
  final int tvId;
  final bool? includeAdult;
  final String tvName;
  const SimilarTVTab(
      {super.key,
      required this.api,
      required this.tvId,
      required this.includeAdult,
      required this.tvName});

  @override
  SimilarTVTabState createState() => SimilarTVTabState();
}

class SimilarTVTabState extends State<SimilarTVTab>
    with AutomaticKeepAliveClientMixin {
  List<TV>? tvList;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTV('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          tvList = value;
        });
      }
    });
    getMoreData();
  }

  final _scrollController = ScrollController();

  int pageNum = 2;
  bool isLoading = false;

  void getMoreData() async {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        setState(() {
          isLoading = true;
        });
        final isProxyEnabled =
            Provider.of<SettingsProvider>(context, listen: false).enableProxy;
        final proxyUrl =
            Provider.of<AppDependencyProvider>(context, listen: false)
                .tmdbProxy;
        fetchTV('${widget.api}&page=$pageNum&include_adult=${widget.includeAdult}',
                isProxyEnabled, proxyUrl)
            .then((value) {
          if (mounted) {
            setState(() {
              tvList!.addAll(value);
              isLoading = false;
              pageNum++;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      const LeadingDot(),
                      Expanded(
                        child: Text(
                          tr('tv_similar_with',
                              namedArgs: {'show': widget.tvName}),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: kTextHeaderStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 250,
            child: tvList == null || widget.includeAdult == null
                ? scrollingMoviesAndTVShimmer(themeMode)
                : tvList!.isEmpty
                    ? Text(
                        tr('no_similars_tv'),
                        textAlign: TextAlign.center,
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: HorizontalScrollingTVList(
                                scrollController: _scrollController,
                                tvList: tvList,
                                imageQuality: imageQuality,
                                themeMode: themeMode),
                          ),
                          Visibility(
                            visible: isLoading,
                            child: SizedBox(
                              width: 110,
                              child: horizontalLoadMoreShimmer(themeMode),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TVGenreDisplay extends StatefulWidget {
  final String? api;
  const TVGenreDisplay({super.key, this.api});

  @override
  TVGenreDisplayState createState() => TVGenreDisplayState();
}

class TVGenreDisplayState extends State<TVGenreDisplay>
    with AutomaticKeepAliveClientMixin<TVGenreDisplay> {
  List<Genres>? genres;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchGenre(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          genres = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return Container(
        child: genres == null
            ? SizedBox(
                height: 80,
                child: detailGenreShimmer(themeMode),
              )
            : genres!.isEmpty
                ? Container()
                : SizedBox(
                    height: 80,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: genres!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => TVGenre(
                                            genres: genres![index],
                                          )));
                            },
                            child: Chip(
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 2,
                                  style: BorderStyle.solid,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              label: Text(
                                genres![index].genreName!,
                                style: const TextStyle(fontFamily: 'Figtree'),
                                // style: widget.themeData.textTheme.bodyText1,
                              ),
                              backgroundColor:
                                  themeMode == 'dark' || themeMode == 'amoled'
                                      ? const Color(0xFF2b2c30)
                                      : const Color(0xFFDFDEDE),
                            ),
                          ),
                        );
                      },
                    ),
                  ));
  }

  @override
  bool get wantKeepAlive => true;
}

class ParticularGenreTV extends StatefulWidget {
  final String api;
  final int genreId;
  final bool? includeAdult;
  const ParticularGenreTV(
      {super.key,
      required this.api,
      required this.genreId,
      required this.includeAdult});
  @override
  ParticularGenreTVState createState() => ParticularGenreTVState();
}

class ParticularGenreTVState extends State<ParticularGenreTV> {
  List<TV>? tvList;
  final _scrollController = ScrollController();
  int pageNum = 2;
  bool isLoading = false;
  bool hasMore = true;

  String _requestUrl({int? page}) {
    final uri = Uri.parse(widget.api);
    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..['include_adult'] = widget.includeAdult.toString();

    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    return uri.replace(queryParameters: queryParameters).toString();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (isLoading || !hasMore || tvList == null) return;

    setState(() => isLoading = true);
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final value =
        await fetchTV(_requestUrl(page: pageNum), isProxyEnabled, proxyUrl);

    if (!mounted) return;
    setState(() {
      tvList!.addAll(value);
      isLoading = false;
      hasMore = value.isNotEmpty;
      if (value.isNotEmpty) pageNum++;
    });
  }

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTV(_requestUrl(), isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvList = value;
        });
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final viewType = Provider.of<SettingsProvider>(context).defaultView;
    return tvList == null && viewType == 'grid'
        ? const AppMediaGridShimmer()
        : tvList == null && viewType == 'list'
            ? const AppMediaListShimmer()
            : tvList!.isEmpty
                ? AppEmptyState(
                    icon: PhosphorIcons.televisionSimple(),
                    title: tr('tv_series'),
                    message: tr('no_genre_tv'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: viewType == 'grid'
                            ? TVGridView(
                                tvList: tvList,
                                imageQuality: imageQuality,
                                themeMode: themeMode,
                                scrollController: _scrollController,
                              )
                            : TVListView(
                                scrollController: _scrollController,
                                tvList: tvList,
                                themeMode: themeMode,
                                imageQuality: imageQuality),
                      ),
                      AppLoadingFooter(visible: isLoading),
                    ],
                  );
  }
}

class TVInfoTable extends StatefulWidget {
  final String? api;
  const TVInfoTable({super.key, this.api});

  @override
  TVInfoTableState createState() => TVInfoTableState();
}

class TVInfoTableState extends State<TVInfoTable> {
  TVDetails? tvDetails;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTVDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvDetails = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LeadingDot(),
              Expanded(
                child: Text(
                  tr('tv_series_info'),
                  style: kTextHeaderStyle,
                ),
              ),
            ],
          ),
          Container(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tvDetails == null
                    ? detailInfoTableShimmer(themeMode)
                    : DataTable(dataRowMinHeight: 40, columns: [
                        DataColumn(
                            label: Text(
                          tr('original_title'),
                          style: kTableLeftStyle,
                        )),
                        DataColumn(
                          label: Text(
                            tvDetails!.originalTitle!,
                            style: kTableLeftStyle,
                          ),
                        ),
                      ], rows: [
                        DataRow(cells: [
                          DataCell(Text(
                            tr('status'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(Text(tvDetails!.status!.isEmpty
                              ? tr('unknown')
                              : tvDetails!.status!)),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('runtime'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(Text(tvDetails!.runtime!.isEmpty
                              ? '-'
                              : tvDetails!.runtime![0] == 0
                                  ? tr('not_available')
                                  : tr('runtime_mins', namedArgs: {
                                      'mins': tvDetails!.runtime![0].toString()
                                    }))),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('spoken_language'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(SizedBox(
                            height: 20,
                            width: 200,
                            child: tvDetails!.spokenLanguages!.isEmpty
                                ? const Text('-')
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        tvDetails!.spokenLanguages!.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5.0),
                                        child: Text(tvDetails!
                                                .spokenLanguages!.isEmpty
                                            ? tr('not_available')
                                            : '${tvDetails!.spokenLanguages![index].englishName},'),
                                      );
                                    },
                                  ),
                          )),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('total_seasons'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(Text(tvDetails!.numberOfSeasons! == 0
                              ? '-'
                              : '${tvDetails!.numberOfSeasons!}')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('total_episodes'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(Text(tvDetails!.numberOfEpisodes! == 0
                              ? '-'
                              : '${tvDetails!.numberOfEpisodes!}')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('tagline'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(
                            Text(
                              tvDetails!.tagline!.isEmpty
                                  ? '-'
                                  : tvDetails!.tagline!,
                              style: const TextStyle(
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('production_companies'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(SizedBox(
                            height: 20,
                            width: 200,
                            child: tvDetails!.productionCompanies!.isEmpty
                                ? const Text('-')
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        tvDetails!.productionCompanies!.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5.0),
                                        child: Text(tvDetails!
                                                .productionCompanies!.isEmpty
                                            ? tr('not_available')
                                            : '${tvDetails!.productionCompanies![index].name},'),
                                      );
                                    },
                                  ),
                          )),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('production_countries'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(SizedBox(
                            height: 20,
                            width: 200,
                            child: tvDetails!.productionCountries!.isEmpty
                                ? const Text('-')
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        tvDetails!.productionCountries!.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5.0),
                                        child: Text(tvDetails!
                                                .productionCountries!.isEmpty
                                            ? tr('not_available')
                                            : '${tvDetails!.productionCountries![index].name},'),
                                      );
                                    },
                                  ),
                          )),
                        ]),
                      ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TVSocialLinks extends StatefulWidget {
  final String? api;
  const TVSocialLinks({
    super.key,
    this.api,
  });

  @override
  TVSocialLinksState createState() => TVSocialLinksState();
}

class TVSocialLinksState extends State<TVSocialLinks> {
  ExternalLinks? externalLinks;
  bool? isAllNull;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchSocialLinks(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          externalLinks = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LeadingDot(),
                Expanded(
                  child: Text(
                    tr('social_media_links'),
                    style: kTextHeaderStyle,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 55,
              width: double.infinity,
              child: externalLinks == null
                  ? socialMediaShimmer(themeMode)
                  : externalLinks?.facebookUsername == null &&
                          externalLinks?.instagramUsername == null &&
                          externalLinks?.twitterUsername == null &&
                          externalLinks?.imdbId == null
                      ? Center(
                          child: Text(
                            tr('no_social_link_tv'),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: themeMode == 'dark' || themeMode == 'amoled'
                                ? Colors.transparent
                                : const Color(0xFFDFDEDE),
                          ),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              SocialIconWidget(
                                isNull: externalLinks?.facebookUsername == null,
                                url: externalLinks?.facebookUsername == null
                                    ? ''
                                    : FACEBOOK_BASE_URL +
                                        externalLinks!.facebookUsername!,
                                icon: const Icon(
                                  SocialIcons.facebook_f,
                                ),
                              ),
                              SocialIconWidget(
                                isNull:
                                    externalLinks?.instagramUsername == null,
                                url: externalLinks?.instagramUsername == null
                                    ? ''
                                    : INSTAGRAM_BASE_URL +
                                        externalLinks!.instagramUsername!,
                                icon: const Icon(
                                  SocialIcons.instagram,
                                ),
                              ),
                              SocialIconWidget(
                                isNull: externalLinks?.twitterUsername == null,
                                url: externalLinks?.twitterUsername == null
                                    ? ''
                                    : TWITTER_BASE_URL +
                                        externalLinks!.twitterUsername!,
                                icon: const Icon(
                                  SocialIcons.twitter,
                                ),
                              ),
                              SocialIconWidget(
                                isNull: externalLinks?.imdbId == null,
                                url: externalLinks?.imdbId == null
                                    ? ''
                                    : IMDB_BASE_URL + externalLinks!.imdbId!,
                                icon: Center(
                                  child: Icon(
                                    PhosphorIcons.filmSlate(),
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class SeasonsList extends StatefulWidget {
  final String? api;
  final String? title;
  final int? tvId;
  final String? seriesName;

  const SeasonsList({
    super.key,
    this.api,
    this.title,
    this.tvId,
    this.seriesName,
  });

  @override
  SeasonsListState createState() => SeasonsListState();
}

class SeasonsListState extends State<SeasonsList> {
  TVDetails? tvDetails;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTVDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvDetails = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const LeadingDot(),
                    Expanded(
                      child: Text(
                        widget.title!,
                        style: kTextHeaderStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          height: 250,
          child: tvDetails == null
              ? horizontalScrollingSeasonsList(themeMode)
              : tvDetails!.seasons!.isEmpty
                  ? Center(
                      child:
                          Text(tr('no_season_tv'), textAlign: TextAlign.center),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: tvDetails!.seasons!.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (BuildContext context, int index) {
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => SeasonsDetail(
                                                tvId: widget.tvId,
                                                seriesName: widget.seriesName,
                                                tvDetails: tvDetails!,
                                                seasons:
                                                    tvDetails!.seasons![index],
                                                heroId:
                                                    '${tvDetails!.seasons![index].seasonNumber}')));
                                  },
                                  child: SizedBox(
                                    width: 105,
                                    child: Column(
                                      children: <Widget>[
                                        Expanded(
                                          flex: 6,
                                          child: Hero(
                                            tag:
                                                '${tvDetails!.seasons![index].seasonNumber}',
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(AppUI.cardRadius),
                                              child: tvDetails!.seasons![index]
                                                          .posterPath ==
                                                      null
                                                  ? Image.asset(
                                                      'assets/images/na_logo.png',
                                                      fit: BoxFit.cover,
                                                    )
                                                  : CachedNetworkImage(
                                                      cacheManager: cacheProp(),
                                                      fadeOutDuration:
                                                          const Duration(
                                                              milliseconds:
                                                                  300),
                                                      fadeOutCurve:
                                                          Curves.easeOut,
                                                      fadeInDuration:
                                                          const Duration(
                                                              milliseconds:
                                                                  700),
                                                      fadeInCurve:
                                                          Curves.easeIn,
                                                      imageUrl: buildImageUrl(
                                                              TMDB_BASE_IMAGE_URL,
                                                              proxyUrl,
                                                              isProxyEnabled,
                                                              context) +
                                                          imageQuality +
                                                          tvDetails!
                                                              .seasons![index]
                                                              .posterPath!,
                                                      imageBuilder: (context,
                                                              imageProvider) =>
                                                          Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          image:
                                                              DecorationImage(
                                                            image:
                                                                imageProvider,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                      placeholder: (context,
                                                              url) =>
                                                          scrollingImageShimmer(
                                                              themeMode),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              tvDetails!.seasons![index].name!,
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

class EpisodeListWidget extends StatefulWidget {
  final int? tvId;
  final String? api;
  final String? seriesName;
  final String? posterPath;
  const EpisodeListWidget({
    super.key,
    this.api,
    this.tvId,
    this.seriesName,
    required this.posterPath,
  });

  @override
  EpisodeListWidgetState createState() => EpisodeListWidgetState();
}

class EpisodeListWidgetState extends State<EpisodeListWidget>
    with AutomaticKeepAliveClientMixin {
  TVDetails? tvDetails;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTVDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvDetails = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return Container(
        child: tvDetails == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 8.0, left: 8.0, right: 8.0),
                          child: Row(
                            children: [
                              const LeadingDot(),
                              Expanded(
                                child: Text(
                                  tr('episodes'),
                                  style: kTextHeaderStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView.builder(
                      shrinkWrap: true,
                      itemCount: 10,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          padding: const EdgeInsets.only(right: 10),
                          child: Column(
                            children: [
                              ShimmerBase(
                                themeMode: themeMode,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 10.0, left: 5.0),
                                      child: Container(
                                        height: 90.0,
                                        width: 160,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(3.0),
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2.0),
                                            child: Container(
                                                color: Colors.grey.shade600,
                                                height: 19,
                                                width: 150),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 2.0),
                                            child: Container(
                                                color: Colors.grey.shade600,
                                                height: 19,
                                                width: 110),
                                          ),
                                          Row(children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 3.0),
                                              child: Container(
                                                  color: Colors.grey.shade600,
                                                  height: 20,
                                                  width: 20),
                                            ),
                                            Container(
                                                color: Colors.grey.shade600,
                                                height: 20,
                                                width: 25),
                                          ]),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Divider(
                                color: Theme.of(context).colorScheme.primary,
                                thickness: 0.5,
                                endIndent: 5,
                                indent: 5,
                              ),
                            ],
                          ),
                        );
                      }),
                ],
              )
            : tvDetails!.episodes!.isEmpty
                ? Center(
                    child:
                        Text(tr('no_episodes'), style: kTextSmallHeaderStyle),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  top: 8.0, left: 8.0, right: 8.0),
                              child: Row(
                                children: [
                                  const LeadingDot(),
                                  Expanded(
                                    child: Text(
                                      tr('episodes'),
                                      style: kTextHeaderStyle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      ListView.builder(
                          shrinkWrap: true,
                          itemCount: tvDetails!.episodes!.length,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (BuildContext context, int index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return EpisodeDetailPage(
                                      seriesName: widget.seriesName,
                                      posterPath: widget.posterPath,
                                      tvId: widget.tvId,
                                      episodes: tvDetails!.episodes,
                                      episodeList: tvDetails!.episodes![index]);
                                }));
                              },
                              child: Container(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 10.0, left: 5.0),
                                            child: SizedBox(
                                              height: 90,
                                              width: 160,
                                              child: Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3.0),
                                                    child: tvDetails!
                                                                    .episodes![
                                                                        index]
                                                                    .stillPath ==
                                                                null ||
                                                            tvDetails!
                                                                .episodes![
                                                                    index]
                                                                .stillPath!
                                                                .isEmpty
                                                        ? Image.asset(
                                                            'assets/images/na_logo.png',
                                                            fit: BoxFit.cover,
                                                            width:
                                                                double.infinity,
                                                          )
                                                        : CachedNetworkImage(
                                                            cacheManager:
                                                                cacheProp(),
                                                            fadeOutDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        300),
                                                            fadeOutCurve:
                                                                Curves.easeOut,
                                                            fadeInDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        700),
                                                            fadeInCurve:
                                                                Curves.easeIn,
                                                            imageUrl: buildImageUrl(
                                                                    TMDB_BASE_IMAGE_URL,
                                                                    proxyUrl,
                                                                    isProxyEnabled,
                                                                    context) +
                                                                imageQuality +
                                                                tvDetails!
                                                                    .episodes![
                                                                        index]
                                                                    .stillPath!,
                                                            imageBuilder: (context,
                                                                    imageProvider) =>
                                                                Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                image:
                                                                    DecorationImage(
                                                                  image:
                                                                      imageProvider,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                              ),
                                                            ),
                                                            placeholder:
                                                                (context,
                                                                        url) =>
                                                                    ShimmerBase(
                                                              themeMode:
                                                                  themeMode,
                                                              child: Container(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600),
                                                            ),
                                                            errorWidget:
                                                                (context, url,
                                                                        error) =>
                                                                    Image.asset(
                                                              'assets/images/na_logo.png',
                                                              fit: BoxFit.cover,
                                                              width: double
                                                                  .infinity,
                                                            ),
                                                          ),
                                                  ),
                                                  Positioned(
                                                      bottom: 0,
                                                      left: 0,
                                                      child: Container(
                                                        color: Colors.black54,
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 4, bottom: 4),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 0.7,
                                                                horizontal: 6),
                                                        child: Text(
                                                            '${tvDetails!.episodes![index].episodeNumber! <= 9 ? tvDetails!.episodes![index].episodeNumber.toString().padLeft(2, '0') : tvDetails!.episodes![index].episodeNumber!}',
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 17)),
                                                      ))
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tvDetails!
                                                      .episodes![index].name!,
                                                  style: const TextStyle(
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  maxLines: 2,
                                                ),
                                                Text(
                                                  tvDetails!.episodes![index]
                                                                  .airDate ==
                                                              null ||
                                                          tvDetails!
                                                              .episodes![index]
                                                              .airDate!
                                                              .isEmpty
                                                      ? tr('air_date_unknown')
                                                      : '${DateTime.parse(tvDetails!.episodes![index].airDate!).day} ${DateFormat("MMMM").format(DateTime.parse(tvDetails!.episodes![index].airDate!))}, ${DateTime.parse(tvDetails!.episodes![index].airDate!).year}',
                                                  style: TextStyle(
                                                    color:
                                                        themeMode == 'dark' ||
                                                                themeMode ==
                                                                    'amoled'
                                                            ? Colors.white54
                                                            : Colors.black54,
                                                  ),
                                                ),
                                                Row(children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 3.0),
                                                    child: Icon(
                                                      PhosphorIcons.star(
                                                          PhosphorIconsStyle
                                                              .fill),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  Text(tvDetails!
                                                      .episodes![index]
                                                      .voteAverage!
                                                      .toStringAsFixed(1))
                                                ]),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                      Divider(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        thickness: 0.5,
                                        endIndent: 5,
                                        indent: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                    ],
                  ));
  }

  @override
  bool get wantKeepAlive => true;
}

class TVWatchProvidersDetails extends StatefulWidget {
  final String api;
  final String country;
  const TVWatchProvidersDetails(
      {super.key, required this.api, required this.country});

  @override
  State<TVWatchProvidersDetails> createState() =>
      _TVWatchProvidersDetailsState();
}

class _TVWatchProvidersDetailsState extends State<TVWatchProvidersDetails>
    with SingleTickerProviderStateMixin {
  WatchProviders? watchProviders;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 5, vsync: this);
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchWatchProviders(widget.api, widget.country, isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          watchProviders = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    return Container(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: themeMode == 'dark' || themeMode == 'amoled'
                  ? const Color(0xFF2b2c30)
                  : const Color(0xFFDFDEDE),
            ),
            child: Center(
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                indicatorWeight: 3,
                unselectedLabelColor: Colors.white54,
                labelColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Text(tr('buy'),
                        style: TextStyle(
                            fontFamily: 'Figtree',
                            color: themeMode == 'dark' || themeMode == 'amoled'
                                ? Colors.white
                                : Colors.black)),
                  ),
                  Tab(
                    child: Text(tr('stream'),
                        style: TextStyle(
                            fontFamily: 'Figtree',
                            color: themeMode == 'dark' || themeMode == 'amoled'
                                ? Colors.white
                                : Colors.black)),
                  ),
                  Tab(
                    child: Text(tr('ads'),
                        style: TextStyle(
                            fontFamily: 'Figtree',
                            color: themeMode == 'dark' || themeMode == 'amoled'
                                ? Colors.white
                                : Colors.black)),
                  ),
                  Tab(
                    child: Text(tr('rent'),
                        style: TextStyle(
                            fontFamily: 'Figtree',
                            color: themeMode == 'dark' || themeMode == 'amoled'
                                ? Colors.white
                                : Colors.black)),
                  ),
                  Tab(
                    child: Text(tr('free'),
                        style: TextStyle(
                            fontFamily: 'Figtree',
                            color: themeMode == 'dark' || themeMode == 'amoled'
                                ? Colors.white
                                : Colors.black)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: watchProviders == null
                  ? [
                      watchProvidersShimmer(themeMode),
                      watchProvidersShimmer(themeMode),
                      watchProvidersShimmer(themeMode),
                      watchProvidersShimmer(themeMode),
                      watchProvidersShimmer(themeMode),
                    ]
                  : [
                      watchProvidersTabData(
                          themeMode: themeMode,
                          imageQuality: imageQuality,
                          noOptionMessage: tr('no_buy_tv'),
                          watchOptions: watchProviders!.buy,
                          context: context),
                      watchProvidersTabData(
                          themeMode: themeMode,
                          imageQuality: imageQuality,
                          noOptionMessage: tr('no_stream_tv'),
                          watchOptions: watchProviders!.flatRate,
                          context: context),
                      watchProvidersTabData(
                          themeMode: themeMode,
                          imageQuality: imageQuality,
                          noOptionMessage: tr('no_ads_tv'),
                          watchOptions: watchProviders!.ads,
                          context: context),
                      watchProvidersTabData(
                          themeMode: themeMode,
                          imageQuality: imageQuality,
                          noOptionMessage: tr('no_rent_tv'),
                          watchOptions: watchProviders!.rent,
                          context: context),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 100,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                            ),
                            itemCount: 1,
                            itemBuilder: (BuildContext context, int index) {
                              return Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(AppUI.cardRadius),
                                        child: const AppLogo(
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Expanded(
                                        flex: 6,
                                        child: Text(
                                          tr('cinemax'),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                  ],
                                ),
                              );
                            }),
                      ),
                    ],
            ),
          )
        ],
      ),
    );
  }
}

class TVGenreListGrid extends StatefulWidget {
  final String api;
  const TVGenreListGrid({super.key, required this.api});

  @override
  TVGenreListGridState createState() => TVGenreListGridState();
}

class TVGenreListGridState extends State<TVGenreListGrid>
    with AutomaticKeepAliveClientMixin<TVGenreListGrid> {
  List<Genres>? genreList;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchGenre(widget.api, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          genreList = value;
        });
      }
    });
  }

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: tr('genres')),
        SizedBox(
          height: 126,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: AppUI.pagePadding(context),
            ),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 184,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: genreList?.length ?? 8,
            itemBuilder: (context, index) {
              if (genreList == null) {
                return const AppShimmerBlock(radius: 9);
              }
              final genre = genreList![index];
              return AppGenreTile(
                icon: PhosphorIcons.television(),
                label: genre.genreName ?? '',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TVGenre(genres: genre),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
}

class TVShowsFromWatchProviders extends StatefulWidget {
  const TVShowsFromWatchProviders({super.key});

  @override
  TVShowsFromWatchProvidersState createState() =>
      TVShowsFromWatchProvidersState();
}

class TVShowsFromWatchProvidersState extends State<TVShowsFromWatchProviders> {
  @override
  Widget build(BuildContext context) {
    return AppStreamingServicesRail(
      onSelected: (service) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StreamingServicesTVShows(
            providerId: service.providerId,
            providerName: service.name,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
}

class TVStreamingServicesWidget extends StatelessWidget {
  final String imagePath;
  final String title;
  final int providerID;
  const TVStreamingServicesWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.providerID,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StreamingServicesTVShows(
              providerId: providerID,
              providerName: title,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: .45),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppUI.cardRadius),
                  child: Image.asset(imagePath, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
}

class ParticularStreamingServiceTVShows extends StatefulWidget {
  final String api;
  final int providerID;
  final bool? includeAdult;
  const ParticularStreamingServiceTVShows({
    super.key,
    required this.api,
    required this.providerID,
    required this.includeAdult,
  });
  @override
  ParticularStreamingServiceTVShowsState createState() =>
      ParticularStreamingServiceTVShowsState();
}

class ParticularStreamingServiceTVShowsState
    extends State<ParticularStreamingServiceTVShows> {
  List<TV>? tvList;
  final _scrollController = ScrollController();
  int pageNum = 2;
  bool isLoading = false;

  String _requestUrl(int page) {
    final uri = Uri.parse(widget.api);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'page': '$page',
      'include_adult': '${widget.includeAdult}',
    }).toString();
  }

  void getMoreData() async {
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading) {
        setState(() {
          isLoading = true;
        });
        final isProxyEnabled =
            Provider.of<SettingsProvider>(context, listen: false).enableProxy;
        final proxyUrl =
            Provider.of<AppDependencyProvider>(context, listen: false)
                .tmdbProxy;
        fetchTV(_requestUrl(pageNum), isProxyEnabled, proxyUrl).then((value) {
          if (mounted) {
            setState(() {
              tvList!.addAll(value);
              isLoading = false;
              pageNum++;
            });
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchTV(_requestUrl(1), isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          tvList = value;
        });
      }
    });
    getMoreData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final viewType = Provider.of<SettingsProvider>(context).defaultView;
    return tvList == null && viewType == 'grid'
        ? const AppMediaGridShimmer()
        : tvList == null && viewType == 'list'
            ? const AppMediaListShimmer()
            : tvList!.isEmpty
                ? AppEmptyState(
                    icon: PhosphorIcons.playCircle(),
                    title: tr('streaming_services'),
                    message: tr('no_watchprovider_tv'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: viewType == 'grid'
                            ? TVGridView(
                                tvList: tvList,
                                imageQuality: imageQuality,
                                themeMode: themeMode,
                                scrollController: _scrollController,
                              )
                            : TVListView(
                                scrollController: _scrollController,
                                tvList: tvList,
                                themeMode: themeMode,
                                imageQuality: imageQuality),
                      ),
                      AppLoadingFooter(visible: isLoading),
                    ],
                  );
  }
}

class TVEpisodeCastTab extends StatefulWidget {
  final String? api;
  const TVEpisodeCastTab({super.key, this.api});

  @override
  TVEpisodeCastTabState createState() => TVEpisodeCastTabState();
}

class TVEpisodeCastTabState extends State<TVEpisodeCastTab>
    with AutomaticKeepAliveClientMixin<TVEpisodeCastTab> {
  Credits? credits;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) setState(() => credits = value);
    }).onError((Object e, _) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (error != null) {
      return AppEmptyState(
        icon: PhosphorIcons.cloudSlash(),
        title: tr('error_occured'),
        message: tr('check_connection'),
        action: FilledButton(
          onPressed: () => setState(() {
            error = null;
            _load();
          }),
          child: Text(tr('retry')),
        ),
      );
    }
    if (credits == null) return const AppPersonListShimmer();
    final cast = credits!.cast ?? const <Cast>[];
    if (cast.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.usersThree(),
        title: tr('cast'),
        message: tr('no_cast_episode'),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        24,
      ),
      itemCount: cast.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final person = cast[index];
        return AppPersonTile(
          name: person.name ?? tr('not_available'),
          subtitle: (person.character ?? '').isEmpty
              ? tr('as_empty')
              : tr('as', namedArgs: {'character': person.character!}),
          avatar: Hero(
            tag: 'episode_cast_tab_${person.creditId}',
            child: PersonAvatar(profilePath: person.profilePath),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CastDetailPage(
                cast: person,
                heroId: 'episode_cast_tab_${person.creditId}',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TVEpisodeGuestStarsTab extends StatefulWidget {
  final String? api;
  const TVEpisodeGuestStarsTab({super.key, this.api});

  @override
  TVEpisodeGuestStarsTabState createState() => TVEpisodeGuestStarsTabState();
}

class TVEpisodeGuestStarsTabState extends State<TVEpisodeGuestStarsTab>
    with AutomaticKeepAliveClientMixin<TVEpisodeGuestStarsTab> {
  Credits? credits;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCredits(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) setState(() => credits = value);
    }).onError((Object e, _) {
      if (mounted) setState(() => error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (error != null) {
      return AppEmptyState(
        icon: PhosphorIcons.cloudSlash(),
        title: tr('error_occured'),
        message: tr('check_connection'),
        action: FilledButton(
          onPressed: () => setState(() {
            error = null;
            _load();
          }),
          child: Text(tr('retry')),
        ),
      );
    }
    if (credits == null) return const AppPersonListShimmer();
    final guests = credits!.episodeGuestStars ?? const <TVEpisodeGuestStars>[];
    if (guests.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.star(),
        title: tr('guest_stars'),
        message: tr('no_guest_episode'),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppUI.pagePadding(context),
        12,
        AppUI.pagePadding(context),
        24,
      ),
      itemCount: guests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final person = guests[index];
        return AppPersonTile(
          name: person.name ?? tr('not_available'),
          subtitle: (person.character ?? '').isEmpty
              ? tr('as_empty')
              : tr('as', namedArgs: {'character': person.character!}),
          avatar: Hero(
            tag: 'guest_star_${person.creditId}',
            child: PersonAvatar(profilePath: person.profilePath),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuestStarDetailPage(
                cast: person,
                heroId: 'guest_star_${person.creditId}',
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class TVDetailQuickInfo extends StatelessWidget {
  const TVDetailQuickInfo({
    super.key,
    required this.tvSeries,
    required this.heroId,
  });

  final TV tvSeries;
  final String heroId;

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final watchCountry = Provider.of<SettingsProvider>(context).defaultCountry;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final appLang = Provider.of<SettingsProvider>(context).appLanguage;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return SizedBox(
      height: 310,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              alignment: AlignmentDirectional.bottomCenter,
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black,
                        Colors.black,
                        Colors.transparent
                      ],
                    ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Container(
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Colors.transparent)),
                    ),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemBuilder: (context, index) {
                              return tvSeries.backdropPath == null
                                  ? Image.asset(
                                      'assets/images/na_logo.png',
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      cacheManager: cacheProp(),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const AppCachedImagePlaceholder(),
                                      imageUrl:
                                          '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context)}original/${tvSeries.backdropPath!}',
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                        'assets/images/na_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    );
                            },
                          ),
                          Positioned(
                            top: -10,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              child: Container(
                                alignment: appLang == 'ar'
                                    ? Alignment.topLeft
                                    : Alignment.topRight,
                                child: GestureDetector(
                                  child: WatchProvidersButton(
                                    country: watchCountry,
                                    api: Endpoints.getMovieWatchProviders(
                                        tvSeries.id!, appLang),
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (builder) {
                                          return WatchProvidersDetails(
                                            country: watchCountry,
                                            api: Endpoints.getTVWatchProviders(
                                                tvSeries.id!, appLang),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // poster and title movie details
          Positioned(
            bottom: 0.0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // poster
                  Hero(
                    tag: heroId,
                    child: Material(
                      type: MaterialType.transparency,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppUI.cardRadius),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppUI.cardRadius),
                              child: SizedBox(
                                width: 94,
                                height: 140,
                                child: tvSeries.posterPath == null
                                    ? Image.asset(
                                        'assets/images/na_logo.png',
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        cacheManager: cacheProp(),
                                        fit: BoxFit.fill,
                                        placeholder: (context, url) =>
                                            scrollingImageShimmer(themeMode),
                                        errorWidget: (context, url, error) =>
                                            Image.asset(
                                          'assets/images/na_logo.png',
                                          fit: BoxFit.cover,
                                        ),
                                        imageUrl: buildImageUrl(
                                                TMDB_BASE_IMAGE_URL,
                                                proxyUrl,
                                                isProxyEnabled,
                                                context) +
                                            imageQuality +
                                            tvSeries.posterPath!,
                                      ),
                              ),
                            ),
                          )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  //  titles
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            // _utilityController.toggleTitleVisibility();
                          },
                          child: Text(
                            tvSeries.firstAirDate == ''
                                ? tvSeries.name!
                                : '${tvSeries.name!} (${DateTime.parse(tvSeries.firstAirDate!).year})',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18, fontFamily: 'FigtreeSB'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TVDetailOptions extends StatefulWidget {
  const TVDetailOptions({super.key, required this.tvSeries});

  final TV tvSeries;

  @override
  State<TVDetailOptions> createState() => _TVDetailOptionsState();
}

class _TVDetailOptionsState extends State<TVDetailOptions> {
  TVDatabaseController tvDatabaseController = TVDatabaseController();
  bool visible = false;
  bool? isBookmarked;

  @override
  void initState() {
    bookmarkChecker();
    super.initState();
  }

  void bookmarkChecker() async {
    var iB = await tvDatabaseController.contain(widget.tvSeries.id!);
    if (mounted) {
      setState(() {
        isBookmarked = iB;
      });
    }
    if (isBookmarked == true) {
      tvDatabaseController.updateTV(widget.tvSeries, widget.tvSeries.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // user score circle percent indicator
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 18, 0),
            child: Row(
              children: [
                CircularPercentIndicator(
                  radius: 30,
                  percent: (widget.tvSeries.voteAverage! / 10),
                  curve: Curves.ease,
                  animation: true,
                  animationDuration: 2500,
                  progressColor: Theme.of(context).colorScheme.primary,
                  center: Text(
                    '${widget.tvSeries.voteAverage!.toStringAsFixed(1).endsWith('0') ? widget.tvSeries.voteAverage!.toStringAsFixed(0) : widget.tvSeries.voteAverage!.toStringAsFixed(1)}/10',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('rating'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          flex: 2,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              // height: 46,
              // width: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                widget.tvSeries.voteCount!.toString(),
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('total_ratings'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 10, right: 8),
          child: Container(
            child: ElevatedButton(
                onPressed: () {
                  if (isBookmarked == false) {
                    tvDatabaseController.insertTV(widget.tvSeries);
                    if (mounted) {
                      setState(() {
                        isBookmarked = true;
                      });
                    }
                  } else if (isBookmarked == true) {
                    tvDatabaseController.deleteTV(widget.tvSeries.id!);
                    if (mounted) {
                      setState(() {
                        isBookmarked = false;
                      });
                    }
                  }
                },
                child: Row(
                  children: [
                    isBookmarked == false
                        ? Icon(PhosphorIcons.bookmarkSimple())
                        : Icon(PhosphorIcons.bookmarkSimple()),
                    Visibility(
                        visible: visible,
                        child: const CircularProgressIndicator())
                  ],
                )),
          ),
        ),
      ],
    );
  }
}

class TVAbout extends StatefulWidget {
  const TVAbout({super.key, required this.tvSeries});

  final TV tvSeries;

  @override
  State<TVAbout> createState() => _TVAboutState();
}

class _TVAboutState extends State<TVAbout> {
  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    return SingleChildScrollView(
      //  physics: const BouncingScrollPhysics(),
      child: Container(
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0))),
        child: Column(
          children: <Widget>[
            TVGenreDisplay(
              api: Endpoints.tvDetailsUrl(widget.tvSeries.id!, lang),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const LeadingDot(),
                        Expanded(
                          child: Text(
                            tr('overview'),
                            style: kTextHeaderStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.tvSeries.overview!.isEmpty ||
                      widget.tvSeries.overview == null
                  ? Text(tr('no_overview_tv'))
                  : ReadMoreText(
                      widget.tvSeries.overview!,
                      trimLines: 4,
                      style: const TextStyle(fontFamily: 'Figtree'),
                      colorClickableText: Theme.of(context).colorScheme.primary,
                      trimMode: TrimMode.Line,
                      trimCollapsedText: tr('read_more'),
                      trimExpandedText: tr('read_less'),
                      lessStyle: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                      moreStyle: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 8.0, bottom: 4.0, right: 8.0),
                    child: Text(
                      widget.tvSeries.firstAirDate == null ||
                              widget.tvSeries.firstAirDate!.isEmpty
                          ? tr('first_episode_air_empty')
                          : '${tr("first_episode_air")} ${DateTime.parse(widget.tvSeries.firstAirDate!).day} ${DateFormat("MMMM").format(DateTime.parse(widget.tvSeries.firstAirDate!))}, ${DateTime.parse(widget.tvSeries.firstAirDate!).year}',
                      style: const TextStyle(
                        fontFamily: 'FigtreeSB',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            ScrollingTVArtists(
              passedFrom: 'tv_detail',
              api: Endpoints.getTVCreditsUrl(widget.tvSeries.id!, lang),
              title: tr('cast'),
              id: widget.tvSeries.id!,
            ),
            ScrollingTVCreators(
              api: Endpoints.tvDetailsUrl(widget.tvSeries.id!, lang),
              title: tr('created_by'),
            ),
            SeasonsList(
              tvId: widget.tvSeries.id!,
              seriesName: widget.tvSeries.name!,
              title: tr('seasons'),
              api: Endpoints.getTVSeasons(widget.tvSeries.id!, lang),
            ),
            TVImagesDisplay(
              title: tr('images'),
              api: Endpoints.getTVImages(widget.tvSeries.id!),
              name: widget.tvSeries.originalName,
            ),
            TVVideosDisplay(
              api: Endpoints.getTVVideos(widget.tvSeries.id!),
              api2: Endpoints.tvDetailsUrl(widget.tvSeries.id!, lang),
              title: tr('videos'),
            ),
            TVSocialLinks(
              api: Endpoints.getExternalLinksForTV(widget.tvSeries.id!, lang),
            ),
            const SizedBox(
              height: 10,
            ),
            TVInfoTable(
              api: Endpoints.tvDetailsUrl(widget.tvSeries.id!, lang),
            ),
            const SizedBox(
              height: 10,
            ),
            TVRecommendationsTab(
                includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                tvId: widget.tvSeries.id!,
                api: Endpoints.getTVRecommendations(
                    widget.tvSeries.id!, 1, lang)),
            SimilarTVTab(
                includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                tvId: widget.tvSeries.id!,
                tvName: widget.tvSeries.name!,
                api: Endpoints.getSimilarTV(widget.tvSeries.id!, 1, lang)),
            // DidYouKnow(
            //   api: Endpoints.getExternalLinksForTV(
            //     widget.tvSeries.id!,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class EpisodeAbout extends StatefulWidget {
  const EpisodeAbout({
    super.key,
    required this.episodeList,
    this.episodes,
    this.tvId,
    required this.posterPath,
    this.seriesName,
  });
  final EpisodeList episodeList;
  final List<EpisodeList>? episodes;
  final int? tvId;
  final String? seriesName;
  final String? posterPath;

  @override
  State<EpisodeAbout> createState() => _EpisodeAboutState();
}

class _EpisodeAboutState extends State<EpisodeAbout> {
  late AppDependencyProvider appDependency =
      Provider.of<AppDependencyProvider>(context, listen: false);
  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    return Container(
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6),
                    child: Row(
                      children: [
                        const LeadingDot(),
                        Expanded(
                          child: Text(
                            tr('overview'),
                            style: kTextHeaderStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ReadMoreText(
                widget.episodeList.overview!.isEmpty
                    ? tr('no_episode_overview')
                    : widget.episodeList.overview!,
                trimLines: 4,
                style: const TextStyle(fontFamily: 'Figtree'),
                colorClickableText: Theme.of(context).colorScheme.primary,
                trimMode: TrimMode.Line,
                trimCollapsedText: tr('read_more'),
                trimExpandedText: tr('read_less'),
                lessStyle: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
                moreStyle: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.only(left: 8.0, bottom: 4.0, right: 8.0),
                  child: Text(
                    widget.episodeList.airDate == null ||
                            widget.episodeList.airDate!.isEmpty
                        ? tr('episode_air_empty')
                        : '${tr("episode_air")}  ${DateTime.parse(widget.episodeList.airDate!).day} ${DateFormat("MMMM").format(DateTime.parse(widget.episodeList.airDate!))}, ${DateTime.parse(widget.episodeList.airDate!).year}',
                    style: const TextStyle(
                      fontFamily: 'FigtreeSB',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              appDependency.displayWatchNowButton && widget.posterPath != null
                  ? WatchNowButton(
                      episode: widget.episodeList,
                      seriesName: widget.seriesName!,
                      tvId: widget.tvId!,
                      posterPath: widget.posterPath!,
                    )
                  : Container(),
            ]),

            const SizedBox(height: 15),
            ScrollingTVEpisodeCasts(
              passedFrom: 'episode_detail',
              seasonNumber: widget.episodeList.seasonNumber!,
              episodeNumber: widget.episodeList.episodeNumber!,
              id: widget.tvId,
              api: Endpoints.getEpisodeCredits(
                  widget.tvId!,
                  widget.episodeList.seasonNumber!,
                  widget.episodeList.episodeNumber!,
                  lang),
            ),
            TVEpisodeImagesDisplay(
              title: tr('images'),
              name: '${widget.seriesName}_${widget.episodeList.name}',
              api: Endpoints.getTVEpisodeImagesUrl(
                  widget.tvId!,
                  widget.episodeList.seasonNumber!,
                  widget.episodeList.episodeNumber!),
            ),
            // TVVideosDisplay(
            //   api: Endpoints.getTVEpisodeVideosUrl(
            //       widget.tvId!,
            //       widget.episodeList.seasonNumber!,
            //       widget.episodeList.episodeNumber!),
            //   title: 'Videos',
            // ),
          ],
        ),
      ),
    );
  }
}

class TVEpisodeQuickInfo extends StatelessWidget {
  const TVEpisodeQuickInfo({
    super.key,
    required this.episodeList,
    this.episodes,
    this.tvId,
    this.seriesName,
  });

  final EpisodeList episodeList;
  final List<EpisodeList>? episodes;
  final int? tvId;
  final String? seriesName;

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final appLang = Provider.of<SettingsProvider>(context).appLanguage;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return SizedBox(
      height: 310,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Stack(
              alignment: AlignmentDirectional.bottomCenter,
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black,
                        Colors.black,
                        Colors.transparent
                      ],
                    ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Container(
                    decoration: const BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: Colors.transparent)),
                    ),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemBuilder: (context, index) {
                              return episodeList.stillPath == null
                                  ? Image.asset(
                                      'assets/images/na_logo.png',
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      cacheManager: cacheProp(),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const AppCachedImagePlaceholder(),
                                      imageUrl:
                                          '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context)}original/${episodeList.stillPath!}',
                                      errorWidget: (context, url, error) =>
                                          Image.asset(
                                        'assets/images/na_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    );
                            },
                          ),
                          Positioned(
                            top: -10,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              child: Container(
                                alignment: appLang == 'ar'
                                    ? Alignment.topLeft
                                    : Alignment.topRight,
                                child: TopButton(buttonText: tr('open_season')),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // poster and title movie details
          Positioned(
              bottom: 0.0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  //  titles
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            // _utilityController.toggleTitleVisibility();
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(episodeSeasonFormatter(
                                  episodeList.episodeNumber!,
                                  episodeList.seasonNumber!)),
                              Text(
                                episodeList.airDate == null ||
                                        episodeList.airDate == ''
                                    ? episodeList.name!
                                    : episodeList.name!,
                                style: kTextSmallHeaderStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 15.0),
                                child: Column(
                                  children: [
                                    Text(
                                      seriesName!,
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: themeMode == 'dark' ||
                                                  themeMode == 'amoled'
                                              ? Colors.white54
                                              : Colors.black54),
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
                ]),
              ))
        ],
      ),
    );
  }
}

class TVEpisodeOptions extends StatelessWidget {
  const TVEpisodeOptions({super.key, required this.episodeList});
  final EpisodeList episodeList;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // user score circle percent indicator
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 18, 0),
            child: Row(
              children: [
                CircularPercentIndicator(
                  radius: 30,
                  percent: (episodeList.voteAverage! / 10),
                  curve: Curves.ease,
                  animation: true,
                  animationDuration: 2500,
                  progressColor: Theme.of(context).colorScheme.primary,
                  center: Text(
                    '${episodeList.voteAverage!.toStringAsFixed(1).endsWith('0') ? episodeList.voteAverage!.toStringAsFixed(0) : episodeList.voteAverage!.toStringAsFixed(1)}/10',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('rating'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          flex: 2,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              // height: 46,
              // width: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                episodeList.voteCount!.toString(),
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr('total_ratings'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ]),
        ),
        const Expanded(child: SizedBox())
      ],
    );
  }
}

class WatchNowButton extends StatefulWidget {
  const WatchNowButton(
      {super.key,
      required this.episode,
      required this.seriesName,
      required this.tvId,
      required this.posterPath});

  final String seriesName, posterPath;
  final int tvId;
  final EpisodeList episode;

  @override
  State<WatchNowButton> createState() => _WatchNowButtonState();
}

class _WatchNowButtonState extends State<WatchNowButton> {
  TVDetails? tvDetails;

  Color _borderColor = Colors.red; // Initial border color
  Timer? _timer;
  Random random = Random();

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Generate random RGB values between 0 and 255
        int red = random.nextInt(256);
        int green = random.nextInt(256);
        int blue = random.nextInt(256);

        _borderColor = Color.fromRGBO(red, green, blue, 1.0);
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          // Add an outer box shadow here
          BoxShadow(
            color: _borderColor,
            spreadRadius: 2.5,
            blurRadius: 4.25,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () async {
          if (mounted) {
            if (mounted) {
              await checkConnection().then((value) {
                if (!context.mounted) {
                  return;
                }
                value
                    ? Navigator.push(context,
                        MaterialPageRoute(builder: ((context) {
                        return TVVideoLoader(
                            download: false,
                            metadata: TVStreamMetadata(
                                elapsed: null,
                                episodeId: widget.episode.episodeId,
                                episodeName: widget.episode.name,
                                episodeNumber: widget.episode.episodeNumber!,
                                posterPath: widget.posterPath,
                                backdropPath: widget.episode.stillPath,
                                seasonNumber: widget.episode.seasonNumber!,
                                seriesName: widget.seriesName,
                                tvId: widget.tvId,
                                airDate: widget.episode.airDate));
                      })))
                    : context.mounted
                        ? GlobalMethods.showCustomScaffoldMessage(
                            SnackBar(
                              content: Text(
                                tr('check_connection'),
                                maxLines: 3,
                                style: kTextSmallBodyStyle,
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                            context)
                        : {};
              });
            }
          }
        },
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(
                PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(tr('watch_now'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ))
            ])),
      ),
    );
  }
}
