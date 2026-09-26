// ignore_for_file: avoid_unnecessary_containers, use_build_context_synchronously
import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixquest/functions/function.dart';
import 'package:flixquest/services/globle_method.dart';
import '../models/movie_stream_metadata.dart';
import '/provider/app_dependency_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/recently_watched.dart';
import '../provider/recently_watched_provider.dart';
import '../screens/common/update_screen.dart';
import '../screens/common/live_tv_screen.dart';
import '../screens/movie/movie_castandcrew.dart';
import '../screens/movie/movie_video_loader.dart';
import '../ui_components/movie_ui_components.dart';
import '../ui_components/app_ui_components.dart';
import '/models/dropdown_select.dart';
import '/models/filter_chip.dart';
import '/screens/common/photoview.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:readmore/readmore.dart';
import '../controllers/bookmark_database_controller.dart';
import '../provider/settings_provider.dart';
import '../provider/bookmark_provider.dart';
import '/constants/app_constants.dart';
import '/models/social_icons_icons.dart';
import '/models/videos.dart';
import '/models/watch_providers.dart';
import '/screens/person/cast_detail.dart';
import '/screens/movie/streaming_services_movies.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../functions/network.dart';
import '/models/movie.dart';
import '/api/endpoints.dart';
import '/models/genres.dart';
import '/constants/api_constants.dart';
import '/screens/movie/movie_detail.dart';
import '/models/credits.dart';
import '/screens/movie/collection_detail.dart';
import '/screens/person/crew_detail.dart';
import '/models/images.dart';
import 'package:url_launcher/url_launcher.dart';
import '/screens/movie/genremovies.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '/screens/movie/main_movies_list.dart';
import 'package:provider/provider.dart';
import 'categorized_feed.dart';
import 'common_widgets.dart';
import 'app_logo.dart';
import '../video_providers/scraper_api.dart';
import 'hosted_ads_banner.dart';

class MainMoviesDisplay extends StatefulWidget {
  const MainMoviesDisplay({
    this.onSearchPressed,
    this.onBookmarksPressed,
    super.key,
  });

  final VoidCallback? onSearchPressed;
  final VoidCallback? onBookmarksPressed;

  @override
  State<MainMoviesDisplay> createState() => _MainMoviesDisplayState();
}

class _MainMoviesDisplayState extends State<MainMoviesDisplay> {
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
    bool includeAdult = Provider.of<SettingsProvider>(context).isAdult;
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    var rMovies = Provider.of<RecentProvider>(context).movies;
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
              child: DiscoverMovies(
                includeAdult: includeAdult,
                discoverType: 'discover',
                onSearchPressed: widget.onSearchPressed,
                onLiveTVPressed: showLiveTV ? openLiveTV : null,
                onBookmarksPressed: widget.onBookmarksPressed,
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                const UpdateBottom(),
                RemoteHostedAdsBanner(
                  placement: 'home_movies',
                  loadAds: () => ScraperApi(
                    context.read<AppDependencyProvider>().flixquestAPIURL,
                  ).getAds(),
                ),
                ScrollingMovies(
                  title: tr('popular'),
                  api: Endpoints.popularMoviesUrl(lang),
                  discoverType: 'popular',
                  isTrending: false,
                  includeAdult: includeAdult,
                ),
                rMovies.isEmpty
                    ? Container()
                    : ScrollingRecentMovies(moviesList: rMovies),
                ScrollingMovies(
                  title: tr('trending_this_week'),
                  api: Endpoints.trendingMoviesUrl(lang),
                  discoverType: 'Trending',
                  isTrending: true,
                  includeAdult: includeAdult,
                ),
                RemoteHostedAdsBanner(
                  placement: 'home_movies',
                  loadAds: () => ScraperApi(
                    context.read<AppDependencyProvider>().flixquestAPIURL,
                  ).getAds(),
                ),
                ScrollingMovies(
                  title: tr('top_rated'),
                  api: Endpoints.topRatedUrl(lang),
                  discoverType: 'top_rated',
                  isTrending: false,
                  includeAdult: includeAdult,
                ),
                ScrollingMovies(
                  title: tr('now_playing'),
                  api: Endpoints.nowPlayingMoviesUrl(1, lang),
                  discoverType: 'now_playing',
                  isTrending: false,
                  includeAdult: includeAdult,
                ),
                ScrollingMovies(
                  title: tr('upcoming'),
                  api: Endpoints.upcomingMoviesUrl(lang),
                  discoverType: 'upcoming',
                  isTrending: false,
                  includeAdult: includeAdult,
                ),
                GenreListGrid(api: Endpoints.movieGenresUrl(lang)),
                RemoteHostedAdsBanner(
                  placement: 'home_movies',
                  loadAds: () => ScraperApi(
                    context.read<AppDependencyProvider>().flixquestAPIURL,
                  ).getAds(),
                ),
                const RandomCategorizedFeed(isTv: false),
                const MoviesFromWatchProviders(),
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
                  title: tr('movies'),
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

class DiscoverMovies extends StatefulWidget {
  const DiscoverMovies(
      {super.key,
      required this.includeAdult,
      required this.discoverType,
      this.onSearchPressed,
      this.onLiveTVPressed,
      this.onBookmarksPressed});
  final bool includeAdult;
  final String discoverType;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onLiveTVPressed;
  final VoidCallback? onBookmarksPressed;
  @override
  DiscoverMoviesState createState() => DiscoverMoviesState();
}

class DiscoverMoviesState extends State<DiscoverMovies>
    with AutomaticKeepAliveClientMixin {
  List<Movie>? moviesList;
  late double deviceHeight;
  YearDropdownData yearDropdownData = YearDropdownData();
  final MovieDatabaseController _bookmarkController = MovieDatabaseController();
  final Set<int> _bookmarkedMovieIds = <int>{};
  @override
  void initState() {
    super.initState();
    getData();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _bookmarkController.getMovieList();
    if (!mounted) return;
    setState(() {
      _bookmarkedMovieIds
        ..clear()
        ..addAll(bookmarks.map((movie) => movie.id).whereType<int>());
    });
  }

  Future<void> _toggleBookmark(Movie movie) async {
    final id = movie.id;
    if (id == null) return;
    final isBookmarked = _bookmarkedMovieIds.contains(id);
    final provider = Provider.of<BookmarkProvider>(context, listen: false);
    if (isBookmarked) {
      await provider.removeMovie(id);
    } else {
      await provider.addMovie(movie);
    }
    if (!mounted) return;
    setState(() {
      isBookmarked
          ? _bookmarkedMovieIds.remove(id)
          : _bookmarkedMovieIds.add(id);
    });
  }

  List<MovieGenreFilterChipWidget> movieGenreFilterdata =
      <MovieGenreFilterChipWidget>[
    MovieGenreFilterChipWidget(genreName: tr('action'), genreValue: '28'),
    MovieGenreFilterChipWidget(genreName: tr('adventure'), genreValue: '12'),
    MovieGenreFilterChipWidget(genreName: tr('animation'), genreValue: '16'),
    MovieGenreFilterChipWidget(genreName: tr('comedy'), genreValue: '35'),
    MovieGenreFilterChipWidget(genreName: tr('crime'), genreValue: '80'),
    MovieGenreFilterChipWidget(genreName: tr('documentary'), genreValue: '99'),
    MovieGenreFilterChipWidget(genreName: tr('drama'), genreValue: '18'),
    MovieGenreFilterChipWidget(genreName: tr('family'), genreValue: '10751'),
    MovieGenreFilterChipWidget(genreName: tr('fantasy'), genreValue: '14'),
    MovieGenreFilterChipWidget(genreName: tr('history'), genreValue: '36'),
    MovieGenreFilterChipWidget(genreName: tr('horror'), genreValue: '27'),
    MovieGenreFilterChipWidget(genreName: tr('music'), genreValue: '10402'),
    MovieGenreFilterChipWidget(genreName: tr('mystery'), genreValue: '9648'),
    MovieGenreFilterChipWidget(genreName: tr('romance'), genreValue: '10749'),
    MovieGenreFilterChipWidget(
        genreName: tr('science_fiction'), genreValue: '878'),
    MovieGenreFilterChipWidget(genreName: tr('tv_movie'), genreValue: '10770'),
    MovieGenreFilterChipWidget(genreName: tr('thriller'), genreValue: '53'),
    MovieGenreFilterChipWidget(genreName: tr('war'), genreValue: '10752'),
    MovieGenreFilterChipWidget(genreName: tr('western'), genreValue: '37'),
  ];

  Future<void> getData() async {
    final lang =
        Provider.of<SettingsProvider>(context, listen: false).appLanguage;
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;

    final random = Random();
    final randomYear =
        (1990 + random.nextInt(DateTime.now().year - 1990 + 1)).toString();
    final randomGenre = movieGenreFilterdata.isNotEmpty
        ? movieGenreFilterdata[random.nextInt(movieGenreFilterdata.length)]
            .genreValue
        : null;
    final randomPage = random.nextInt(5) + 1;

    final trendingFuture = fetchMovies(
      Endpoints.trendingMoviesUrl(lang),
      isProxyEnabled,
      proxyUrl,
    );

    final randomDiscoverFuture = fetchMovies(
      Endpoints.randomDiscoverMoviesUrl(
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

      final combined = <Movie>[];
      final seenIds = <int>{};

      final validTrending = trendingList
          .where((m) =>
              (m.backdropPath != null || m.posterPath != null) && m.id != null)
          .toList();

      final validRandom = randomList
          .where((m) =>
              (m.backdropPath != null || m.posterPath != null) && m.id != null)
          .toList()
        ..shuffle(random);

      int tIndex = 0;
      int rIndex = 0;

      while ((tIndex < validTrending.length || rIndex < validRandom.length) &&
          combined.length < 10) {
        if (tIndex < validTrending.length) {
          final m = validTrending[tIndex++];
          if (seenIds.add(m.id!)) {
            combined.add(m);
          }
        }
        if (rIndex < validRandom.length && combined.length < 10) {
          final m = validRandom[rIndex++];
          if (seenIds.add(m.id!)) {
            combined.add(m);
          }
        }
      }

      if (mounted) {
        setState(() {
          moviesList = combined.isNotEmpty ? combined : trendingList;
        });
      }
    } catch (_) {
      final fallback = await trendingFuture.catchError((_) => <Movie>[]);
      if (mounted) {
        setState(() {
          moviesList = fallback;
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
      child: moviesList == null
          ? const AppShimmerBlock(radius: 0)
          : moviesList!.isEmpty
              ? Center(child: Text(tr('wow_odd'), style: kTextSmallBodyStyle))
              : AppCrossfadeCarousel(
                  itemCount: moviesList!.take(10).length,
                  onItemTap: (index) {
                    final selected = moviesList![index];
                    if (selected.id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MovieDetailPage(
                          movie: selected,
                          heroId: 'home_movie_${selected.id}',
                        ),
                      ),
                    );
                  },
                  itemBuilder: (context, index) {
                    final movie = moviesList![index];
                    final imagePath = movie.backdropPath ?? movie.posterPath;
                    final isBookmarked = _bookmarkedMovieIds.contains(movie.id);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: imagePath == null
                              ? ''
                              : '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context)}original$imagePath',
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
                                    _HeroLiveButton(
                                      onPressed: widget.onLiveTVPressed!,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  _HeroIconButton(
                                    key: const ValueKey(
                                        'movie_bookmarks_shortcut'),
                                    icon: PhosphorIcons.bookmarkSimple(),
                                    tooltip: 'Bookmarks',
                                    onPressed: widget.onBookmarksPressed,
                                  ),
                                  const SizedBox(width: 8),
                                  _HeroIconButton(
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
                                movie.title ?? '',
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
                                  if ((movie.releaseDate ?? '').length >= 4)
                                    movie.releaseDate!.substring(0, 4),
                                  if (movie.voteAverage != null)
                                    '\u2605 ${movie.voteAverage!.toStringAsFixed(1)}',
                                  if ((movie.originalLanguage ?? '').isNotEmpty)
                                    movie.originalLanguage!.toUpperCase(),
                                ].join('  \u2022  '),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  if (showWatchNow) ...[
                                    FilledButton.icon(
                                      onPressed: () => _watchMovie(movie),
                                      icon: Icon(PhosphorIcons.play()),
                                      label: Text(tr('watch_now')),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  OutlinedButton.icon(
                                    onPressed: () => _toggleBookmark(movie),
                                    icon: Icon(isBookmarked
                                        ? PhosphorIcons.check()
                                        : PhosphorIcons.plus()),
                                    label: Text(tr('bookmark_home')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white70),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
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

  Future<void> _watchMovie(Movie movie) async {
    final movieId = movie.id;
    if (movieId == null) return;
    if (!await checkConnection()) {
      if (!mounted) return;
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(content: Text(tr('check_connection'), maxLines: 3)),
        context,
      );
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieVideoLoader(
          download: false,
          metadata: MovieStreamMetadata(
            backdropPath: movie.backdropPath,
            elapsed: null,
            movieId: movieId,
            movieName: movie.title,
            posterPath: movie.posterPath,
            releaseYear: DateTime.tryParse(movie.releaseDate ?? '')?.year,
            isAdult: movie.adult,
            releaseDate: movie.releaseDate,
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
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

class _HeroLiveButton extends StatelessWidget {
  const _HeroLiveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: const ValueKey('movie_live_tv_shortcut'),
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

class ScrollingMovies extends StatefulWidget {
  final String api, title;
  final dynamic discoverType;
  final bool isTrending;
  final bool? includeAdult;

  const ScrollingMovies({
    super.key,
    required this.api,
    required this.title,
    this.discoverType,
    required this.isTrending,
    required this.includeAdult,
  });
  @override
  ScrollingMoviesState createState() => ScrollingMoviesState();
}

class ScrollingMoviesState extends State<ScrollingMovies>
    with AutomaticKeepAliveClientMixin {
  late int index;
  List<Movie>? moviesList;
  final ScrollController _scrollController = ScrollController();

  int pageNum = 2;
  bool isLoading = false;

  String _requestUrl({int? page}) {
    final uri = Uri.parse(widget.api);
    final queryParameters = Map<String, String>.from(uri.queryParameters);

    if (!widget.isTrending && widget.includeAdult != null) {
      queryParameters['include_adult'] = widget.includeAdult.toString();
    }
    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    return uri.replace(queryParameters: queryParameters).toString();
  }

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
        if (mounted) {
          fetchMovies(_requestUrl(page: pageNum), isProxyEnabled, proxyUrl)
              .then((value) {
            if (mounted) {
              setState(() {
                moviesList!.addAll(value);
                isLoading = false;
                pageNum++;
              });
            }
          });
        }
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
    fetchMovies(_requestUrl(), isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          moviesList = value;
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
                      return MainMoviesList(
                        title: widget.title,
                        api: widget.api,
                        includeAdult: widget.includeAdult,
                        discoverType: widget.discoverType.toString(),
                        isTrending: widget.isTrending,
                      );
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
          child: moviesList == null || widget.includeAdult == null
              ? scrollingMoviesAndTVShimmer(themeMode)
              : Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: moviesList!.length,
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
                                        builder: (context) => MovieDetailPage(
                                            movie: moviesList![index],
                                            heroId:
                                                '${moviesList![index].id}${widget.title}-${widget.discoverType}')));
                              },
                              child: SizedBox(
                                width: cardWidth,
                                child: Column(
                                  children: <Widget>[
                                    SizedBox(
                                      height: cardWidth * 1.5,
                                      child: Hero(
                                        tag:
                                            '${moviesList![index].id}${widget.title}-${widget.discoverType}',
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(AppUI.cardRadius),
                                                child: moviesList![index]
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
                                                        imageUrl: moviesList![
                                                                        index]
                                                                    .posterPath ==
                                                                null
                                                            ? ''
                                                            : buildImageUrl(
                                                                    TMDB_BASE_IMAGE_URL,
                                                                    proxyUrl,
                                                                    isProxyEnabled,
                                                                    context) +
                                                                imageQuality +
                                                                moviesList![
                                                                        index]
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
                                                    rating: moviesList![index]
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
                                          moviesList![index].title!,
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

class ScrollingRecentMovies extends StatefulWidget {
  const ScrollingRecentMovies({required this.moviesList, super.key});

  final List<RecentMovie> moviesList;

  @override
  State<ScrollingRecentMovies> createState() => _ScrollingRecentMoviesState();
}

class _ScrollingRecentMoviesState extends State<ScrollingRecentMovies> {
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
          height: cardWidth * .56 + 62,
          child: ListView.separated(
            controller: _scrollController,
            padding:
                EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: widget.moviesList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = widget.moviesList[index];
              final elapsed = (movie.elapsed ?? 0).toDouble();
              final total = elapsed + (movie.remaining ?? 0).toDouble();
              return SizedBox(
                width: cardWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppUI.cardRadius),
                  onLongPress: () =>
                      context.read<RecentProvider>().deleteMovie(movie.id!),
                  onTap: () => _openMovie(movie),
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
                              (movie.backdropPath ?? movie.posterPath) == null
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
                                          (movie.backdropPath ??
                                              movie.posterPath)!,
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
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
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
                                  onPressed: () => context
                                      .read<RecentProvider>()
                                      .deleteMovie(movie.id!),
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
                        movie.title ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
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

  Future<void> _openMovie(RecentMovie movie) async {
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
        builder: (_) => MovieVideoLoader(
          download: false,
          metadata: MovieStreamMetadata(
            backdropPath: movie.backdropPath,
            elapsed: movie.elapsed,
            isAdult: null,
            movieId: movie.id,
            movieName: movie.title,
            posterPath: movie.posterPath,
            releaseYear: movie.releaseYear,
            releaseDate: null,
          ),
        ),
      ),
    );
  }

  // Kept temporarily as a behavior reference while the refreshed rail settles.
  // ignore: unused_element
}

class SABTN extends StatefulWidget {
  final void Function()? onBack;

  const SABTN({super.key, this.onBack});

  @override
  // ignore: library_private_types_in_public_api
  _SABTNState createState() => _SABTNState();
}

class _SABTNState extends State<SABTN> {
  ScrollPosition? _position;
  bool? _visible;

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _removeListener();
    _addListener();
  }

  void _addListener() {
    _position = Scrollable.of(context).position;
    _position?.addListener(_positionListener);
    _positionListener();
  }

  void _removeListener() {
    _position?.removeListener(_positionListener);
  }

  void _positionListener() {
    final FlexibleSpaceBarSettings? settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    bool visible =
        settings == null || settings.currentExtent <= settings.minExtent;
    if (_visible != visible) {
      setState(() {
        _visible = visible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1,
      curve: Curves.easeIn,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50.0),
              color: themeMode == 'dark' || themeMode == 'amoled'
                  ? Colors.black12
                  : Colors.white38),
          child: IconButton(
            icon: Icon(
              PhosphorIcons.caretLeft(),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}

class SABT extends StatefulWidget {
  final Widget child;

  const SABT({
    required this.child,
    super.key,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SABTState createState() => _SABTState();
}

class _SABTState extends State<SABT> {
  ScrollPosition? _position;
  bool? _visible;

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _removeListener();
    _addListener();
  }

  void _addListener() {
    _position = Scrollable.of(context).position;
    _position?.addListener(_positionListener);
    _positionListener();
  }

  void _removeListener() {
    _position?.removeListener(_positionListener);
  }

  void _positionListener() {
    final FlexibleSpaceBarSettings? settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    bool visible =
        settings == null || settings.currentExtent <= settings.minExtent;
    if (_visible != visible) {
      setState(() {
        _visible = visible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _visible!,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1,
        curve: Curves.easeIn,
        child: widget.child,
      ),
    );
  }
}

class MovieDetailQuickInfo extends StatelessWidget {
  const MovieDetailQuickInfo({
    super.key,
    required this.movie,
    required this.heroId,
  });

  final Movie movie;
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
                              return movie.backdropPath == null
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
                                          '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context)}original/${movie.backdropPath!}',
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
                                    api: Endpoints.getMovieWatchProviders(
                                        movie.id!, appLang),
                                    country: watchCountry,
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (builder) {
                                          return WatchProvidersDetails(
                                            api: Endpoints
                                                .getMovieWatchProviders(
                                                    movie.id!, appLang),
                                            country: watchCountry,
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
                                child: movie.posterPath == null
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
                                            movie.posterPath!,
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
                            movie.releaseDate == null
                                ? movie.title!
                                : movie.releaseDate == ''
                                    ? movie.title!
                                    : '${movie.title!} (${DateTime.parse(movie.releaseDate!).year})',
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

class MovieDetailOptions extends StatefulWidget {
  const MovieDetailOptions({super.key, required this.movie});

  final Movie movie;

  @override
  State<MovieDetailOptions> createState() => _MovieDetailOptionsState();
}

class _MovieDetailOptionsState extends State<MovieDetailOptions> {
  MovieDatabaseController movieDatabaseController = MovieDatabaseController();
  bool visible = false;
  bool? isBookmarked;

  @override
  void initState() {
    bookmarkChecker();
    super.initState();
  }

  void bookmarkChecker() async {
    var iB = await movieDatabaseController.contain(widget.movie.id!);
    if (mounted) {
      setState(() {
        isBookmarked = iB;
      });
    }
    if (isBookmarked == true) {
      movieDatabaseController.updateMovie(widget.movie, widget.movie.id!);
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
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                // crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircularPercentIndicator(
                    radius: 30,
                    percent: (widget.movie.voteAverage! / 10),
                    curve: Curves.ease,
                    animation: true,
                    animationDuration: 2500,
                    progressColor: Theme.of(context).colorScheme.primary,
                    center: Text(
                      '${widget.movie.voteAverage!.toStringAsFixed(1).endsWith('0') ? widget.movie.voteAverage!.toStringAsFixed(0) : widget.movie.voteAverage!.toStringAsFixed(1)}/10',
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
        ),

        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
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
                  widget.movie.voteCount!.toString(),
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
        ),

        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: Container(
              child: ElevatedButton(
                  onPressed: () {
                    if (isBookmarked == false) {
                      movieDatabaseController.insertMovie(widget.movie);
                      if (mounted) {
                        setState(() {
                          isBookmarked = true;
                        });
                      }
                    } else if (isBookmarked == true) {
                      movieDatabaseController.deleteMovie(widget.movie.id!);
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
        ),
      ],
    );
  }
}

class MovieAbout extends StatefulWidget {
  const MovieAbout({required this.movie, super.key});
  final Movie movie;

  @override
  State<MovieAbout> createState() => _MovieAboutState();
}

class _MovieAboutState extends State<MovieAbout> {
  bool? isVisible = false;
  double? buttonWidth = 150;
  late AppDependencyProvider appDependency =
      Provider.of<AppDependencyProvider>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    return SingleChildScrollView(
      // physics: const BouncingScrollPhysics(),
      child: Container(
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0))),
        child: Column(
          children: <Widget>[
            GenreDisplay(
              api: Endpoints.movieDetailsUrl(widget.movie.id!, lang),
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
              child: widget.movie.overview == null ||
                      widget.movie.overview!.isEmpty
                  ? Text(tr('no_overview_movie'))
                  : ReadMoreText(
                      widget.movie.overview!,
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
                      widget.movie.releaseDate == null ||
                              widget.movie.releaseDate!.isEmpty
                          ? tr('no_release_date')
                          : '${tr("release_date")} : ${DateTime.parse(widget.movie.releaseDate!).day} ${DateFormat("MMMM").format(DateTime.parse(widget.movie.releaseDate!))}, ${DateTime.parse(widget.movie.releaseDate!).year}',
                      style: const TextStyle(fontFamily: 'FigtreeSB'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.movie.releaseDate!.isNotEmpty &&
                        appDependency.displayWatchNowButton
                    ? WatchNowButton(
                        releaseYear:
                            DateTime.parse(widget.movie.releaseDate!).year,
                        movieId: widget.movie.id!,
                        movieName: widget.movie.title,
                        adult: widget.movie.adult,
                        posterPath: widget.movie.posterPath,
                        backdropPath: widget.movie.backdropPath,
                        api: Endpoints.movieDetailsUrl(widget.movie.id!, lang),
                        releaseDate: widget.movie.releaseDate,
                      )
                    : Container()
                // const SizedBox(
                //   width: 15,
                // ),
                // DownloadMovie(
                //   releaseYear: DateTime.parse(widget.movie.releaseDate!).year,
                //   movieId: widget.movie.id!,
                //   movieName: widget.movie.title,
                //   adult: widget.movie.adult,
                //   thumbnail: widget.movie.backdropPath,
                //   api: Endpoints.movieDetailsUrl(widget.movie.id!),
                // )
              ],
            ),
            const SizedBox(height: 15),
            ScrollingArtists(
              api: Endpoints.getCreditsUrl(widget.movie.id!, lang),
              title: tr('cast'),
            ),
            MovieImagesDisplay(
              title: tr('images'),
              api: Endpoints.getImages(widget.movie.id!),
              name: widget.movie.title,
            ),
            MovieVideosDisplay(
              api: Endpoints.getVideos(widget.movie.id!),
              title: tr('videos'),
            ),
            MovieSocialLinks(
              api: Endpoints.getExternalLinksForMovie(widget.movie.id!, lang),
            ),
            const SizedBox(
              height: 10,
            ),
            BelongsToCollectionWidget(
              api: Endpoints.movieDetailsUrl(widget.movie.id!, lang),
            ),
            const SizedBox(
              height: 10,
            ),
            MovieInfoTable(
              api: Endpoints.movieDetailsUrl(widget.movie.id!, lang),
            ),
            const SizedBox(
              height: 10,
            ),
            MovieRecommendationsTab(
              includeAdult: Provider.of<SettingsProvider>(context).isAdult,
              api: Endpoints.getMovieRecommendations(widget.movie.id!, 1, lang),
              movieId: widget.movie.id!,
            ),
            SimilarMoviesTab(
                movieName: widget.movie.title!,
                includeAdult: Provider.of<SettingsProvider>(context).isAdult,
                movieId: widget.movie.id!,
                api: Endpoints.getSimilarMovies(widget.movie.id!, 1, lang)),
            // DidYouKnow(
            //   api: Endpoints.getExternalLinksForMovie(
            //     widget.movie.id!,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class DownloadMovie extends StatelessWidget {
  const DownloadMovie({
    super.key,
    required this.adult,
    required this.api,
    required this.movieId,
    this.movieImdbId,
    required this.movieName,
    required this.releaseYear,
    required this.thumbnail,
  });

  final String? movieName;
  final int movieId;
  final int? movieImdbId;
  final bool? adult;
  final String? api;
  final int releaseYear;
  final String? thumbnail;

  @override
  Widget build(BuildContext context) {
    bool? isVisible = false;
    double? buttonWidth = 150;
    return Container(
      child: TextButton(
        style: ButtonStyle(
          maximumSize: WidgetStateProperty.all(Size(buttonWidth, 50)),
        ).copyWith(
            backgroundColor: WidgetStateProperty.all(
          Theme.of(context).colorScheme.primary,
        )),
        onPressed: () async {
          // await checkConnection().then((value) {
          //   value
          //       ? Navigator.push(context,
          //           MaterialPageRoute(builder: ((context) {
          //           return MovieVideoLoader(
          //             download: true,
          //             route: fetchRoute == "flixHQ"
          //                 ? StreamRoute.flixHQ
          //                 : StreamRoute.tmDB,
          //             metadata: [
          //               movieId,
          //               movieName,
          //               thumbnail,
          //               releaseYear,
          //               0.0
          //             ],
          //           );
          //         })))
          //       : ScaffoldMessenger.of(context).showSnackBar(
          //           SnackBar(
          //             content: Text(
          //               tr("check_connection"),
          //               maxLines: 3,
          //               style: kTextSmallBodyStyle,
          //             ),
          //             duration: const Duration(seconds: 3),
          //           ),
          //         );
          // });
        },
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                PhosphorIcons.downloadSimple(),
                color: Colors.white,
              ),
            ),
            Text(
              tr('download'),
              style: const TextStyle(color: Colors.white),
            ),
            Visibility(
              visible: isVisible,
              child: const Padding(
                padding: EdgeInsets.only(
                  left: 10.0,
                ),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScrollingArtists extends StatefulWidget {
  final String? api, title, tapButtonText;
  const ScrollingArtists({
    super.key,
    this.api,
    this.title,
    this.tapButtonText,
  });
  @override
  ScrollingArtistsState createState() => ScrollingArtistsState();
}

class ScrollingArtistsState extends State<ScrollingArtists> {
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
                          child: Text(tr('no_cast_movie'),
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
                              return MovieCastAndCrew(credits: credits!);
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
                        child: Text(tr('see_all_cast_crew')),
                      )
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
                              heroId: '${credits!.cast![index].id}'
                                  '${credits!.cast![index].creditId}',
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
                                  tag: '${credits!.cast![index].id}',
                                  child: SizedBox(
                                    width: 75,
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
}

class MovieSocialLinks extends StatefulWidget {
  final String? api;
  const MovieSocialLinks({
    super.key,
    this.api,
  });

  @override
  MovieSocialLinksState createState() => MovieSocialLinksState();
}

class MovieSocialLinksState extends State<MovieSocialLinks> {
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
                            tr('no_social_link_movie'),
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

class BelongsToCollectionWidget extends StatefulWidget {
  final String? api;
  const BelongsToCollectionWidget({
    super.key,
    this.api,
  });

  @override
  BelongsToCollectionWidgetState createState() =>
      BelongsToCollectionWidgetState();
}

class BelongsToCollectionWidgetState extends State<BelongsToCollectionWidget> {
  BelongsToCollection? belongsToCollection;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchBelongsToCollection(widget.api!, isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          belongsToCollection = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return belongsToCollection == null
        ? ShimmerBase(
            themeMode: themeMode,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        : belongsToCollection?.id == null
            ? Container()
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                    width: double.infinity,
                    height: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppUI.cardRadius),
                              child: belongsToCollection!.backdropPath == null
                                  ? Image.asset(
                                      'assets/images/na_logo.png',
                                    )
                                  : FadeInImage(
                                      fit: BoxFit.fill,
                                      placeholder: const AssetImage(
                                          'assets/images/loading_5.gif'),
                                      image: NetworkImage(
                                          '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context)}w500/${belongsToCollection!.backdropPath!}')),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      tr('belongs_to_the', namedArgs: {
                                        'collection': belongsToCollection!.name!
                                      }),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: TextButton(
                                      style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStateProperty.all(
                                            Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.3),
                                          ),
                                          maximumSize: WidgetStateProperty.all(
                                              const Size(200, 40)),
                                          shape: WidgetStateProperty.all<
                                                  RoundedRectangleBorder>(
                                              RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          5.0),
                                                  side: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  )))),
                                      onPressed: () {
                                        Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (context) {
                                          return CollectionDetailsWidget(
                                              belongsToCollection:
                                                  belongsToCollection!);
                                        }));
                                      },
                                      child: Text(
                                        tr('view_collection'),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ],
                    )),
              );
  }
}

class SocialIconWidget extends StatelessWidget {
  const SocialIconWidget({
    super.key,
    this.url,
    this.icon,
    this.isNull,
  });

  final String? url;
  final Widget? icon;
  final bool? isNull;

  @override
  Widget build(BuildContext context) {
    return isNull == true
        ? Container()
        : Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                launchUrl(Uri.parse(url!),
                    mode: LaunchMode.externalApplication);
              },
              child: Container(
                height: 50,
                width: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                ),
                child: icon,
              ),
            ),
          );
  }
}

class MovieImagesDisplay extends StatefulWidget {
  final String? api, title, name;
  const MovieImagesDisplay({super.key, this.api, this.name, this.title});

  @override
  MovieImagesState createState() => MovieImagesState();
}

class MovieImagesState extends State<MovieImagesDisplay> {
  Images? movieImages;
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
          movieImages = value;
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
                          style:
                              kTextHeaderStyle, /*style: widget.themeData!.textTheme.bodyText1*/
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
              height: 220,
              child: movieImages == null
                  ? detailImageShimmer(themeMode)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: CarouselSlider(
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
                                                child: movieImages!
                                                        .poster!.isEmpty
                                                    ? Image.asset(
                                                        'assets/images/na_logo.png',
                                                        fit: BoxFit.cover,
                                                        height: double.infinity,
                                                        width: double.infinity)
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
                                                            movieImages!
                                                                .poster![0]
                                                                .posterPath!,
                                                        imageBuilder: (context,
                                                                imageProvider) =>
                                                            GestureDetector(
                                                          onTap: () {
                                                            Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                    builder:
                                                                        ((context) {
                                                              return HeroPhotoView(
                                                                posters:
                                                                    movieImages!
                                                                        .poster!,
                                                                name:
                                                                    widget.name,
                                                                imageType:
                                                                    'poster',
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
                                                                movieImages!
                                                                    .poster![0]
                                                                    .posterPath!,
                                                            child: Container(
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
                                                          ),
                                                        ),
                                                        placeholder: (context,
                                                                url) =>
                                                            detailImageImageSimmer(
                                                                themeMode),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            Image.asset(
                                                                'assets/images/na_logo.png',
                                                                fit: BoxFit
                                                                    .cover,
                                                                height: double
                                                                    .infinity,
                                                                width: double
                                                                    .infinity),
                                                      ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Container(
                                                color: Colors.black38,
                                                child: Text(movieImages!
                                                            .poster!.length ==
                                                        1
                                                    ? tr('poster_singular',
                                                        namedArgs: {
                                                            'poster':
                                                                movieImages!
                                                                    .poster!
                                                                    .length
                                                                    .toString()
                                                          })
                                                    : tr('poster_plural',
                                                        namedArgs: {
                                                            'poster':
                                                                movieImages!
                                                                    .poster!
                                                                    .length
                                                                    .toString()
                                                          })),
                                              ),
                                            )
                                          ]),
                                    ),
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
                                              child: movieImages!
                                                      .backdrop!.isEmpty
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
                                                          movieImages!
                                                              .backdrop![0]
                                                              .filePath!,
                                                      imageBuilder: (context,
                                                              imageProvider) =>
                                                          GestureDetector(
                                                        onTap: () {
                                                          Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder:
                                                                      ((context) {
                                                            return HeroPhotoView(
                                                              backdrops:
                                                                  movieImages!
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
                                                              movieImages!
                                                                  .backdrop![0]
                                                                  .filePath!,
                                                          child: Container(
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
                                                        ),
                                                      ),
                                                      placeholder: (context,
                                                              url) =>
                                                          detailImageImageSimmer(
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
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              color: Colors.black38,
                                              child: Text(movieImages!
                                                          .backdrop!.length ==
                                                      1
                                                  ? tr('backdrop_singular',
                                                      namedArgs: {
                                                          'backdrop':
                                                              movieImages!
                                                                  .backdrop!
                                                                  .length
                                                                  .toString()
                                                        })
                                                  : tr('backdrop_plural',
                                                      namedArgs: {
                                                          'backdrop':
                                                              movieImages!
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
          ),
        ],
      ),
    );
  }
}

class MovieVideosDisplay extends StatefulWidget {
  final String? api, title;
  const MovieVideosDisplay({super.key, this.api, this.title});

  @override
  MovieVideosState createState() => MovieVideosState();
}

class MovieVideosState extends State<MovieVideosDisplay> {
  Videos? movieVideos;

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
          movieVideos = value;
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
        movieVideos == null
            ? Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const LeadingDot(),
                          Expanded(
                            child: Text(
                              widget.title!,
                              style:
                                  kTextHeaderStyle, /* style: widget.themeData!.textTheme.bodyText1*/
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
                            child: Text(
                              widget.title!,
                              style:
                                  kTextHeaderStyle, /*style: widget.themeData!.textTheme.bodyText1*/
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
            child: movieVideos == null
                ? detailVideoShimmer(themeMode)
                : movieVideos!.result!.isEmpty
                    ? SizedBox(
                        width: double.infinity,
                        height: 80,
                        child: Center(
                          child: Text(tr('no_video_movie'),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
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
                                          movieVideos!
                                              .result![index].videoLink!),
                                      mode: LaunchMode.externalApplication);
                                },
                                child: SizedBox(
                                  height: 205,
                                  width: double.infinity,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 200,
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
                                                        '$YOUTUBE_THUMBNAIL_URL${movieVideos!.result![index].videoLink!}/hqdefault.jpg',
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
                                                      'assets/images/na_rect.png',
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
                                          movieVideos!.result![index].name!,
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
                          itemCount: movieVideos!.result!.length,
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}

class WatchNowButton extends StatefulWidget {
  const WatchNowButton({
    super.key,
    required this.posterPath,
    required this.movieId,
    this.movieName,
    this.movieImdbId,
    this.api,
    required this.releaseYear,
    required this.backdropPath,
    required this.releaseDate,
    this.adult,
  });
  final String? movieName;
  final int movieId;
  final int? movieImdbId;
  final bool? adult;
  final String? api;
  final int releaseYear;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;

  @override
  WatchNowButtonState createState() => WatchNowButtonState();
}

class WatchNowButtonState extends State<WatchNowButton> {
  bool? isVisible = false;
  double? buttonWidth = 160;

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
    _timer?.cancel();
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
            await checkConnection().then((value) {
              value
                  ? Navigator.push(context,
                      MaterialPageRoute(builder: ((context) {
                      return MovieVideoLoader(
                        download: false,
                        metadata: MovieStreamMetadata(
                            backdropPath: widget.backdropPath,
                            elapsed: null,
                            isAdult: widget.adult,
                            movieId: widget.movieId,
                            movieName: widget.movieName,
                            posterPath: widget.posterPath,
                            releaseYear: widget.releaseYear,
                            releaseDate: widget.releaseDate),
                      );
                    })))
                  : GlobalMethods.showCustomScaffoldMessage(
                      SnackBar(
                        content: Text(
                          tr('check_connection'),
                          maxLines: 3,
                          style: kTextSmallBodyStyle,
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                      context);
            });
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
        ));
  }
}

class GenreDisplay extends StatefulWidget {
  final String? api;
  const GenreDisplay({super.key, this.api});

  @override
  GenreDisplayState createState() => GenreDisplayState();
}

class GenreDisplayState extends State<GenreDisplay>
    with AutomaticKeepAliveClientMixin<GenreDisplay> {
  List<Genres>? genreList;
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
          genreList = value;
        });
      }
    });
  }

  // void getGenreWithoutData() {
  //   genreList = [];
  //   for (int i = 0; i < widget.movieGenres!.length; i++) {
  //     print(i);
  //     for (int k = 0; k < genreData.movieGenres.length; k++) {
  //       if (widget.movieGenres![i] == genreData.movieGenres[k].genreValue) {
  //         setState(() {
  //           genreList!.add(Genres(
  //               genreID: genreData.movieGenres[k].genreValue,
  //               genreName: genreData.movieGenres[k].genreName));
  //         });
  //       } else {
  //         print('inv: ${widget.movieGenres![i]}');
  //       }
  //     }
  //   }
  //   print(genreList);
  // }

  // void genreGet() {
  //   print(widget.movieGenres);
  //   widget.movieGenres == null
  //       ? fetchGenre(widget.api!).then((value) {
  //           if (mounted) {
  //             setState(() {
  //               genreList = value;
  //             });
  //           }
  //         })
  //       : getGenreWithoutData();
  // }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    super.build(context);
    return Container(
        child: genreList == null
            ? SizedBox(
                height: 80,
                child: detailGenreShimmer(themeMode),
              )
            : genreList!.isEmpty
                ? Container()
                : SizedBox(
                    height: 80,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      itemCount: genreList!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => GenreMovies(
                                            genres: genreList![index],
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
                                genreList![index].genreName!,
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

class MovieInfoTable extends StatefulWidget {
  final String? api;
  const MovieInfoTable({super.key, this.api});

  @override
  MovieInfoTableState createState() => MovieInfoTableState();
}

class MovieInfoTableState extends State<MovieInfoTable> {
  MovieDetails? movieDetails;
  final formatCurrency = NumberFormat.simpleCurrency();

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchMovieDetails(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          movieDetails = value;
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
                  tr('movie_info'),
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
                child: movieDetails == null
                    ? detailInfoTableShimmer(themeMode)
                    : DataTable(dataRowMinHeight: 40, columns: [
                        DataColumn(
                            label: Text(
                          tr('original_title'),
                          style: kTableLeftStyle,
                        )),
                        DataColumn(
                          label: Text(
                            movieDetails!.originalTitle!,
                            style: const TextStyle(
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ], rows: [
                        DataRow(cells: [
                          DataCell(Text(
                            tr('status'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(Text(movieDetails!.status!.isEmpty
                              ? tr('unknown')
                              : movieDetails!.status!)),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('runtime'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(Text(movieDetails!.runtime! == 0
                              ? tr('not_available')
                              : tr('runtime_mins', namedArgs: {
                                  'mins': movieDetails!.runtime!.toString()
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
                            child: movieDetails!.spokenLanguages!.isEmpty
                                ? const Text('-')
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        movieDetails!.spokenLanguages!.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5.0),
                                        child: Text(movieDetails!
                                                .spokenLanguages!.isEmpty
                                            ? tr('not_available')
                                            : '${movieDetails!.spokenLanguages![index].englishName},'),
                                      );
                                    },
                                  ),
                          )),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('budget'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(movieDetails!.budget == 0
                              ? const Text('-')
                              : Text(formatCurrency
                                  .format(movieDetails!.budget!)
                                  .toString())),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('revenue'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(movieDetails!.budget == 0
                              ? const Text('-')
                              : Text(formatCurrency
                                  .format(movieDetails!.revenue!)
                                  .toString())),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('tagline'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(
                            Text(
                              movieDetails!.tagline!.isEmpty
                                  ? '-'
                                  : movieDetails!.tagline!,
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
                            child: movieDetails!.productionCompanies!.isEmpty
                                ? const Text('-')
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: movieDetails!
                                        .productionCompanies!.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5.0),
                                        child: Text(movieDetails!
                                                .productionCompanies!.isEmpty
                                            ? tr('not_available')
                                            : '${movieDetails!.productionCompanies![index].name},'),
                                      );
                                    },
                                  ),
                          )
                              // movieDetails!.productionCompanies!.isEmpty
                              //     ? const Text('-')
                              //     : Text(
                              //         movieDetails!.productionCompanies![0].name!),
                              ),
                        ]),
                        DataRow(cells: [
                          DataCell(Text(
                            tr('production_countries'),
                            style: kTableLeftStyle,
                          )),
                          DataCell(SizedBox(
                            height: 20,
                            width: 200,
                            child: movieDetails!.productionCountries!.isEmpty
                                ? const Text('-')
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: movieDetails!
                                        .productionCountries!.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 5.0),
                                        child: Text(movieDetails!
                                                .productionCountries!.isEmpty
                                            ? tr('not_available')
                                            : '${movieDetails!.productionCountries![index].name},'),
                                      );
                                    },
                                  ),
                          )
                              // movieDetails!.productionCompanies!.isEmpty
                              //     ? const Text('-')
                              //     : Text(
                              //         movieDetails!.productionCountries![0].name!),
                              ),
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

class CastTab extends StatefulWidget {
  final Credits credits;
  const CastTab({super.key, required this.credits});

  @override
  CastTabState createState() => CastTabState();
}

class CastTabState extends State<CastTab>
    with AutomaticKeepAliveClientMixin<CastTab> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cast = widget.credits.cast ?? const <Cast>[];
    if (cast.isEmpty) {
      return AppEmptyState(
        icon: PhosphorIcons.usersThree(),
        title: tr('cast'),
        message: tr('no_cast_movie'),
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
            tag: '${person.creditId}',
            child: PersonAvatar(profilePath: person.profilePath),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CastDetailPage(cast: person, heroId: '${person.creditId}'),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class CrewTab extends StatefulWidget {
  const CrewTab({super.key, required this.credits});

  final Credits credits;

  @override
  CrewTabState createState() => CrewTabState();
}

class CrewTabState extends State<CrewTab>
    with AutomaticKeepAliveClientMixin<CrewTab> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final crew = widget.credits.crew ?? const <Crew>[];
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
          avatar: Hero(
            tag: '${person.creditId}',
            child: PersonAvatar(profilePath: person.profilePath),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CrewDetailPage(crew: person, heroId: '${person.creditId}'),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class MovieRecommendationsTab extends StatefulWidget {
  final String api;
  final int movieId;
  final bool? includeAdult;
  const MovieRecommendationsTab(
      {super.key,
      required this.api,
      required this.movieId,
      required this.includeAdult});

  @override
  MovieRecommendationsTabState createState() => MovieRecommendationsTabState();
}

class MovieRecommendationsTabState extends State<MovieRecommendationsTab>
    with AutomaticKeepAliveClientMixin {
  List<Movie>? movieList;
  final _scrollController = ScrollController();
  int pageNum = 2;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchMovies('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          movieList = value;
        });
      }
    });
    getMoreData();
  }

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
        if (mounted) {
          fetchMovies(
                  '${widget.api}&include_adult=${widget.includeAdult}&page=$pageNum',
                  isProxyEnabled,
                  proxyUrl)
              .then((value) {
            if (mounted) {
              setState(() {
                movieList!.addAll(value);
                isLoading = false;
                pageNum++;
              });
            }
          });
        }
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
                          tr('movie_recommendations'),
                          style: kTextHeaderStyle,
                          maxLines: 2,
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
            child: movieList == null || widget.includeAdult == null
                ? scrollingMoviesAndTVShimmer(themeMode)
                : movieList!.isEmpty
                    ? Center(
                        child: Text(
                          tr('no_recommendations_movie'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: HorizontalScrollingMoviesList(
                                scrollController: _scrollController,
                                movieList: movieList,
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

class SimilarMoviesTab extends StatefulWidget {
  final String api;
  final int movieId;
  final String movieName;
  final bool? includeAdult;
  const SimilarMoviesTab(
      {super.key,
      required this.api,
      required this.movieId,
      required this.movieName,
      required this.includeAdult});

  @override
  SimilarMoviesTabState createState() => SimilarMoviesTabState();
}

class SimilarMoviesTabState extends State<SimilarMoviesTab>
    with AutomaticKeepAliveClientMixin {
  List<Movie>? movieList;
  final _scrollController = ScrollController();
  int pageNum = 2;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchMovies('${widget.api}&include_adult=${widget.includeAdult}',
            isProxyEnabled, proxyUrl)
        .then((value) {
      if (mounted) {
        setState(() {
          movieList = value;
        });
      }
    });
    getMoreData();
  }

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
        if (mounted) {
          fetchMovies(
                  '${widget.api}&include_adult=${widget.includeAdult}&page=$pageNum',
                  isProxyEnabled,
                  proxyUrl)
              .then((value) {
            if (mounted) {
              setState(() {
                movieList!.addAll(value);
                isLoading = false;
                pageNum++;
              });
            }
          });
        }
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
                          tr('movies_similar_with',
                              namedArgs: {'movie': widget.movieName}),
                          style: kTextHeaderStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
            child: movieList == null || widget.includeAdult == null
                ? scrollingMoviesAndTVShimmer(themeMode)
                : movieList!.isEmpty
                    ? Center(
                        child: Text(
                          tr('no_similars_movie'),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                              child: HorizontalScrollingMoviesList(
                            imageQuality: imageQuality,
                            themeMode: themeMode,
                            movieList: movieList,
                            scrollController: _scrollController,
                          )),
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

class ParticularGenreMovies extends StatefulWidget {
  final String api;
  final int genreId;
  final String watchRegion;
  final bool? includeAdult;
  const ParticularGenreMovies(
      {super.key,
      required this.api,
      required this.genreId,
      required this.includeAdult,
      required this.watchRegion});
  @override
  ParticularGenreMoviesState createState() => ParticularGenreMoviesState();
}

class ParticularGenreMoviesState extends State<ParticularGenreMovies> {
  List<Movie>? moviesList;
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
    if (isLoading || !hasMore || moviesList == null) return;

    setState(() => isLoading = true);
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final value =
        await fetchMovies(_requestUrl(page: pageNum), isProxyEnabled, proxyUrl);

    if (!mounted) return;
    setState(() {
      moviesList!.addAll(value);
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
    fetchMovies(_requestUrl(), isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          moviesList = value;
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
    return moviesList == null && viewType == 'grid'
        ? const AppMediaGridShimmer()
        : moviesList == null && viewType == 'list'
            ? const AppMediaListShimmer()
            : moviesList!.isEmpty
                ? AppEmptyState(
                    icon: PhosphorIcons.filmSlate(),
                    title: tr('movies'),
                    message: tr('no_genre_movie'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: viewType == 'grid'
                            ? MovieGridView(
                                scrollController: _scrollController,
                                moviesList: moviesList,
                                imageQuality: imageQuality,
                                themeMode: themeMode)
                            : MovieListView(
                                scrollController: _scrollController,
                                moviesList: moviesList,
                                themeMode: themeMode,
                                imageQuality: imageQuality),
                      ),
                      AppLoadingFooter(visible: isLoading),
                    ],
                  );
  }
}

class ParticularStreamingServiceMovies extends StatefulWidget {
  final String api;
  final int providerID;
  final bool? includeAdult;
  final String watchRegion;
  const ParticularStreamingServiceMovies({
    super.key,
    required this.api,
    required this.providerID,
    required this.includeAdult,
    required this.watchRegion,
  });
  @override
  ParticularStreamingServiceMoviesState createState() =>
      ParticularStreamingServiceMoviesState();
}

class ParticularStreamingServiceMoviesState
    extends State<ParticularStreamingServiceMovies> {
  List<Movie>? moviesList;
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
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    _scrollController.addListener(() async {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoading) {
        setState(() {
          isLoading = true;
        });
        if (mounted) {
          fetchMovies(_requestUrl(pageNum), isProxyEnabled, proxyUrl)
              .then((value) {
            if (mounted) {
              setState(() {
                moviesList!.addAll(value);
                isLoading = false;
                pageNum++;
              });
            }
          });
        }
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
    fetchMovies(_requestUrl(1), isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          moviesList = value;
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
    return moviesList == null && viewType == 'grid'
        ? const AppMediaGridShimmer()
        : moviesList == null && viewType == 'list'
            ? const AppMediaListShimmer()
            : moviesList!.isEmpty
                ? AppEmptyState(
                    icon: PhosphorIcons.playCircle(),
                    title: tr('streaming_services'),
                    message: tr('no_watchprovider_movie'),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: viewType == 'grid'
                            ? MovieGridView(
                                scrollController: _scrollController,
                                moviesList: moviesList,
                                imageQuality: imageQuality,
                                themeMode: themeMode)
                            : MovieListView(
                                scrollController: _scrollController,
                                moviesList: moviesList,
                                themeMode: themeMode,
                                imageQuality: imageQuality),
                      ),
                      AppLoadingFooter(visible: isLoading),
                    ],
                  );
  }
}

class StreamingServicesWidget extends StatelessWidget {
  final String imagePath;
  final String title;
  final int providerID;
  const StreamingServicesWidget({
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
            builder: (_) => StreamingServicesMovies(
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

class GenreListGrid extends StatefulWidget {
  final String api;
  const GenreListGrid({
    super.key,
    required this.api,
  });

  @override
  GenreListGridState createState() => GenreListGridState();
}

class GenreListGridState extends State<GenreListGrid>
    with AutomaticKeepAliveClientMixin<GenreListGrid> {
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
                icon: PhosphorIcons.filmStrip(),
                label: genre.genreName ?? '',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GenreMovies(genres: genre),
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
  @override
  bool get wantKeepAlive => true;
}

class TopButton extends StatefulWidget {
  final String buttonText;
  const TopButton({
    super.key,
    required this.buttonText,
  });

  @override
  TopButtonState createState() => TopButtonState();
}

class TopButtonState extends State<TopButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: TextButton(
        style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            maximumSize: WidgetStateProperty.all(const Size(200, 60)),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    )))),
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text(
          widget.buttonText,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class WatchProvidersButton extends StatefulWidget {
  final Function()? onTap;
  final String api;
  final String country;
  const WatchProvidersButton({
    super.key,
    this.onTap,
    required this.api,
    required this.country,
  });

  @override
  State<WatchProvidersButton> createState() => _WatchProvidersButtonState();
}

class _WatchProvidersButtonState extends State<WatchProvidersButton> {
  WatchProviders? watchProviders;
  @override
  void initState() {
    super.initState();
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
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: TextButton(
        style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            maximumSize: WidgetStateProperty.all(const Size(200, 60)),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    )))),
        onPressed: () {
          widget.onTap!();
        },
        child: Text(
          tr('watch_providers'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class MoviesFromWatchProviders extends StatefulWidget {
  const MoviesFromWatchProviders({super.key});

  @override
  MoviesFromWatchProvidersState createState() =>
      MoviesFromWatchProvidersState();
}

class MoviesFromWatchProvidersState extends State<MoviesFromWatchProviders> {
  @override
  Widget build(BuildContext context) {
    return AppStreamingServicesRail(
      onSelected: (service) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StreamingServicesMovies(
            providerId: service.providerId,
            providerName: service.name,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
}

class CollectionMovies extends StatefulWidget {
  final String? api;
  const CollectionMovies({
    super.key,
    this.api,
  });
  @override
  CollectionMoviesState createState() => CollectionMoviesState();
}

class CollectionMoviesState extends State<CollectionMovies> {
  List<Movie>? moviesList;
  @override
  void initState() {
    super.initState();
    final isProxyEnabled =
        Provider.of<SettingsProvider>(context, listen: false).enableProxy;
    final proxyUrl =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    fetchCollectionMovies(widget.api!, isProxyEnabled, proxyUrl).then((value) {
      if (mounted) {
        setState(() {
          moviesList = value;
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
    return moviesList == null
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : moviesList!.isEmpty
            ? Center(
                child: Text(
                  tr('no_watchprovider_movie'),
                  style: const TextStyle(fontFamily: 'Figtree'),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: moviesList!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MovieDetailPage(
                                        movie: moviesList![index],
                                        heroId: '${moviesList![index].id}')));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(
                                      width: 85,
                                      height: 130,
                                      child: Hero(
                                        tag: '${moviesList![index].id}',
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(AppUI.cardRadius),
                                          child: moviesList![index]
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
                                                      moviesList![index]
                                                          .posterPath!,
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
                                                      scrollingImageShimmer(
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
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              moviesList![index].title!,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                  fontFamily: 'Figtree'),
                                            ),
                                            Row(
                                              children: <Widget>[
                                                Text(
                                                  moviesList![index]
                                                      .voteAverage!
                                                      .toStringAsFixed(1),
                                                  style: const TextStyle(
                                                      fontFamily: 'Figtree'),
                                                ),
                                                Icon(
                                                  PhosphorIcons.star(
                                                      PhosphorIconsStyle.fill),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 24.0),
                                  child: Divider(
                                    color: Colors.white,
                                  ),
                                )
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
}
