import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/endpoints.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../constants/loading_colors.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../functions/function.dart';
import '../../functions/network.dart';
import '../../models/credits.dart';
import '../../models/genres.dart';
import '../../models/images.dart';
import '../../models/movie.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/videos.dart';
import '../../models/watch_providers.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../provider/bookmark_provider.dart';
import '../../screens/common/photoview.dart';
import '../../services/globle_method.dart';
import '../../services/ambient_theme_service.dart';
import '../../ui_components/app_ui_components.dart';
import '../person/cast_detail.dart';
import 'collection_detail.dart';
import 'genremovies.dart';
import 'movie_castandcrew.dart';
import 'movie_video_loader.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

class MovieDetailPage extends StatefulWidget {
  const MovieDetailPage({
    super.key,
    required this.movie,
    required this.heroId,
  });

  final Movie movie;
  final String heroId;

  @override
  State<MovieDetailPage> createState() => MovieDetailPageState();
}

class MovieDetailPageState extends State<MovieDetailPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final MovieDatabaseController _database = MovieDatabaseController();
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;

  late Future<List<Genres>> _genres;
  late Future<Credits> _credits;
  late Future<Videos> _videos;
  late Future<Images> _images;
  late Future<MovieDetails> _details;
  late Future<ExternalLinks> _socialLinks;
  late Future<BelongsToCollection> _collection;
  final AmbientThemeScopeController _ambientTheme =
      AmbientThemeScopeController();

  bool? _isBookmarked;
  bool _bookmarkBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _loadPageData();
    _ambientTheme.attach(
      context,
      widget.movie.posterPath ?? widget.movie.backdropPath,
    );
    _checkBookmark();
    _trackPageView();
  }

  void _loadPageData() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);
    final movieId = widget.movie.id!;
    final language = settings.appLanguage;
    final proxyEnabled = settings.enableProxy;
    final proxy = dependencies.tmdbProxy;

    _genres = fetchGenre(
      Endpoints.movieDetailsUrl(movieId, language),
      proxyEnabled,
      proxy,
    );
    _credits = fetchCredits(
      Endpoints.getCreditsUrl(movieId, language),
      proxyEnabled,
      proxy,
    );
    _videos = fetchVideos(
      Endpoints.getVideos(movieId),
      proxyEnabled,
      proxy,
    );
    _images = fetchImages(
      Endpoints.getImages(movieId),
      proxyEnabled,
      proxy,
    );
    _details = fetchMovieDetails(
      Endpoints.movieDetailsUrl(movieId, language),
      proxyEnabled,
      proxy,
    );
    _socialLinks = fetchSocialLinks(
      Endpoints.getExternalLinksForMovie(movieId, language),
      proxyEnabled,
      proxy,
    );
    _collection = fetchBelongsToCollection(
      Endpoints.movieDetailsUrl(movieId, language),
      proxyEnabled,
      proxy,
    ).then((value) => value as BelongsToCollection);
  }

  void _trackPageView() {
    final analytics =
        Provider.of<SettingsProvider>(context, listen: false).analytics;
    analytics.trackMoviePageView(
      movieName: widget.movie.title,
      movieId: widget.movie.id,
      isAdult: widget.movie.adult,
    );
  }

  Future<void> _checkBookmark() async {
    final bookmarked = await _database.contain(widget.movie.id!);
    if (!mounted) return;
    setState(() => _isBookmarked = bookmarked);
    if (bookmarked) {
      await _database.updateMovie(widget.movie, widget.movie.id!);
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked == null || _bookmarkBusy) return;
    setState(() => _bookmarkBusy = true);
    try {
      final provider = Provider.of<BookmarkProvider>(context, listen: false);
      if (_isBookmarked!) {
        await provider.removeMovie(widget.movie.id!);
      } else {
        await provider.addMovie(widget.movie);
      }
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked!);
        Provider.of<SettingsProvider>(context, listen: false)
            .analytics
            .trackBookmarkToggle(
              mediaType: 'Movie',
              mediaName: widget.movie.title,
              mediaId: widget.movie.id,
              added: _isBookmarked!,
            );
      }
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  String get _displayTitle {
    final title = widget.movie.title?.trim();
    return title == null || title.isEmpty ? tr('not_available') : title;
  }

  String? get _releaseYear {
    final date = DateTime.tryParse(widget.movie.releaseDate ?? '');
    return date?.year.toString();
  }

  Future<void> _shareMovie() async {
    Provider.of<SettingsProvider>(context, listen: false)
        .analytics
        .trackShare(shareType: 'Movie', mediaName: _displayTitle);
    await Share.share(
      tr(
        'share_movie',
        namedArgs: {
          'title': _displayTitle,
          'rating': (widget.movie.voteAverage ?? 0).toStringAsFixed(1),
          'id': widget.movie.id.toString(),
        },
      ),
    );
  }

  Future<void> _watchNow() async {
    if (!await checkConnection()) {
      if (!mounted) return;
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(content: Text(tr('check_connection'), maxLines: 3)),
        context,
      );
      return;
    }
    if (!mounted) return;
    final wellnessMetadata = await _wellnessMetadataSnapshot();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MovieVideoLoader(
          download: false,
          metadata: MovieStreamMetadata(
            backdropPath: widget.movie.backdropPath,
            elapsed: null,
            isAdult: widget.movie.adult,
            movieId: widget.movie.id!,
            movieName: widget.movie.title,
            posterPath: widget.movie.posterPath,
            releaseYear: int.tryParse(_releaseYear ?? '') ?? 0,
            releaseDate: widget.movie.releaseDate,
            genres: wellnessMetadata.$1,
            languages: wellnessMetadata.$2,
            countries: wellnessMetadata.$3,
          ),
        ),
      ),
    );
  }

  Future<void> _download() async {
    if (!await checkConnection()) {
      if (!mounted) return;
      GlobalMethods.showCustomScaffoldMessage(
        SnackBar(content: Text(tr('check_connection'), maxLines: 3)),
        context,
      );
      return;
    }
    if (!mounted) return;
    final wellnessMetadata = await _wellnessMetadataSnapshot();
    if (!mounted) return;
    final queued = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MovieVideoLoader(
          download: true,
          metadata: MovieStreamMetadata(
            backdropPath: widget.movie.backdropPath,
            elapsed: null,
            isAdult: widget.movie.adult,
            movieId: widget.movie.id!,
            movieName: widget.movie.title,
            posterPath: widget.movie.posterPath,
            releaseYear: int.tryParse(_releaseYear ?? '') ?? 0,
            releaseDate: widget.movie.releaseDate,
            genres: wellnessMetadata.$1,
            languages: wellnessMetadata.$2,
            countries: wellnessMetadata.$3,
          ),
        ),
      ),
    );
    if (mounted && queued == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to downloads')),
      );
    }
  }

  Future<(List<String>, List<String>, List<String>)>
      _wellnessMetadataSnapshot() async {
    List<Genres>? genres;
    MovieDetails? details;
    try {
      genres = await _genres;
    } catch (_) {}
    try {
      details = await _details;
    } catch (_) {}
    final genreNames = genres
            ?.map((genre) => genre.genreName?.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final languages = details?.spokenLanguages
            ?.map((language) => language.englishName?.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList(growable: false) ??
        <String>[
          if (widget.movie.originalLanguage?.trim().isNotEmpty == true)
            widget.movie.originalLanguage!.trim(),
        ];
    final countries = details?.productionCountries
            ?.map((country) => country.name?.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    return (genreNames, languages, countries);
  }

  void _showWatchProviders() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .82,
        child: _WatchProvidersSheet(
          api: Endpoints.getMovieWatchProviders(
            widget.movie.id!,
            settings.appLanguage,
          ),
          country: settings.defaultCountry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.sizeOf(context);
    final heroHeight = (size.height * .32).clamp(220.0, 320.0);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
            toolbarHeight: 64,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 4,
            title: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) {
                final collapseAt = heroHeight -
                    kToolbarHeight -
                    MediaQuery.paddingOf(context).top -
                    12;
                final visible = _scrollController.hasClients &&
                    _scrollController.offset >= collapseAt;
                return AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    _releaseYear == null
                        ? _displayTitle
                        : '$_displayTitle  •  $_releaseYear',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'FigtreeSB',
                        ),
                  ),
                );
              },
            ),
            leadingWidth: 68,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _HeroIconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: PhosphorIcons.caretLeft(),
              ),
            ),
            actions: [
              // Casting/provider controls belong in the content actions, not on
              // top of the artwork.
              // _HeroIconButton(...),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _MovieBackdrop(
                movie: widget.movie,
                images: _images,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                24,
                AppUI.pagePadding(context),
                0,
              ),
              child: _MovieSummary(
                movie: widget.movie,
                heroId: widget.heroId,
                displayTitle: _displayTitle,
                releaseYear: _releaseYear,
                genres: _genres,
                details: _details,
                credits: _credits,
                isBookmarked: _isBookmarked,
                bookmarkBusy: _bookmarkBusy,
                onBookmark: _toggleBookmark,
                onShare: _shareMovie,
                onWatch: _watchNow,
                onDownload: _download,
                onProviders: _showWatchProviders,
                onRetryGenres: () => setState(_loadPageData),
                onRetryCredits: () => setState(_loadPageData),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RemoteHostedAdsBanner(
              placement: 'movie_detail',
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _MovieTabHeaderDelegate(
              controller: _tabController,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              dividerColor: colors.outlineVariant,
            ),
          ),
          SliverToBoxAdapter(
            child: AppResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                12,
                AppUI.pagePadding(context),
                48 + MediaQuery.paddingOf(context).bottom,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey(_tabController.index),
                  child: _buildSelectedTab(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    switch (_tabController.index) {
      case 0:
        return _MediaTab(
          videos: _videos,
          images: _images,
          movieTitle: _displayTitle,
          onRetry: () => setState(_loadPageData),
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MovieRail(
              title: tr('movie_recommendations'),
              emptyMessage: tr('no_recommendations_movie'),
              movieId: widget.movie.id!,
              includeAdult: settings.isAdult,
              recommendations: true,
            ),
            const SizedBox(height: 30),
            _MovieRail(
              title: tr(
                'movies_similar_with',
                namedArgs: {'movie': _displayTitle},
              ),
              emptyMessage: tr('no_similars_movie'),
              movieId: widget.movie.id!,
              includeAdult: settings.isAdult,
              recommendations: false,
            ),
          ],
        );
      default:
        return _DetailsTab(
          movie: widget.movie,
          details: _details,
          collection: _collection,
          socialLinks: _socialLinks,
          onRetry: () => setState(_loadPageData),
        );
    }
  }

  @override
  void dispose() {
    _ambientTheme.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}

class _MovieBackdrop extends StatelessWidget {
  const _MovieBackdrop({required this.movie, required this.images});

  final Movie movie;
  final Future<Images> images;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    // final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Images>(
      future: images,
      builder: (context, snapshot) {
        final paths = <String>{
          if ((movie.backdropPath ?? '').isNotEmpty) movie.backdropPath!,
          ...?snapshot.data?.backdrop
              ?.map((image) => image.filePath)
              .whereType<String>()
              .where((path) => path.isNotEmpty),
        }.take(8).toList();
        return Stack(
          fit: StackFit.expand,
          children: [
            if (paths.isEmpty)
              Image.asset('assets/images/na_logo.png', fit: BoxFit.cover)
            else
              AppSwipeCarousel(
                itemCount: paths.length,
                indicatorBottom: 15,
                itemBuilder: (context, index) => CachedNetworkImage(
                  cacheManager: cacheProp(),
                  imageUrl:
                      '${buildImageUrl(TMDB_BASE_IMAGE_URL, dependencies.tmdbProxy, settings.enableProxy, context)}original${paths[index]}',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => const AppShimmerBlock(radius: 0),
                  errorWidget: (_, __, ___) => Image.asset(
                      'assets/images/na_logo.png',
                      fit: BoxFit.cover),
                ),
              ),
            // const AppDetailHeroGradient(),
            // IgnorePointer(
            //   child: Align(
            //     alignment: Alignment.bottomCenter,
            //     child: Container(
            //       height: 72,
            //       decoration: BoxDecoration(
            //         gradient: LinearGradient(
            //           begin: Alignment.topCenter,
            //           end: Alignment.bottomCenter,
            //           colors: [Colors.transparent, colors.surface],
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
          ],
        );
      },
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 42,
        child: Material(
          color: Colors.black.withValues(alpha: .38),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: Colors.white,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }
}

class _MovieSummary extends StatelessWidget {
  const _MovieSummary({
    required this.movie,
    required this.heroId,
    required this.displayTitle,
    required this.releaseYear,
    required this.genres,
    required this.details,
    required this.credits,
    required this.isBookmarked,
    required this.bookmarkBusy,
    required this.onBookmark,
    required this.onShare,
    required this.onWatch,
    required this.onDownload,
    required this.onProviders,
    required this.onRetryGenres,
    required this.onRetryCredits,
  });

  final Movie movie;
  final String heroId;
  final String displayTitle;
  final String? releaseYear;
  final Future<List<Genres>> genres;
  final Future<MovieDetails> details;
  final Future<Credits> credits;
  final bool? isBookmarked;
  final bool bookmarkBusy;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onWatch;
  final VoidCallback onDownload;
  final VoidCallback onProviders;
  final VoidCallback onRetryGenres;
  final VoidCallback onRetryCredits;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPoster = constraints.maxWidth >= 650;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(context),
            const SizedBox(height: 14),
            _metadata(context),
            const SizedBox(height: 16),
            _genres(),
            const SizedBox(height: 16),
            _overview(context),
            const SizedBox(height: 14),
            _releaseDate(context),
            const SizedBox(height: 20),
            _actions(context),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPoster)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 190, child: _poster(context)),
                  const SizedBox(width: 28),
                  Expanded(child: content),
                ],
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 108, child: _poster(context)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleRow(context, compact: true),
                        const SizedBox(height: 12),
                        _metadata(context),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _SummaryAction(
                              tooltip: tr('bookmarks'),
                              onPressed: isBookmarked == null || bookmarkBusy
                                  ? null
                                  : onBookmark,
                              child: bookmarkBusy || isBookmarked == null
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      isBookmarked!
                                          ? PhosphorIcons.bookmarkSimple(
                                              PhosphorIconsStyle.fill)
                                          : PhosphorIcons.bookmarkSimple(),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            _SummaryAction(
                              tooltip: tr('shared_the_app'),
                              onPressed: onShare,
                              child: Icon(PhosphorIcons.shareNetwork()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _genres(),
              const SizedBox(height: 16),
              _overview(context),
              const SizedBox(height: 14),
              _releaseDate(context),
              const SizedBox(height: 20),
              _actions(context),
            ],
            const SizedBox(height: 28),
            _CastRail(credits: credits, onRetry: onRetryCredits),
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }

  Widget _poster(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    return Hero(
      tag: heroId,
      child: Material(
        type: MaterialType.transparency,
        child: AspectRatio(
          aspectRatio: AppUI.posterAspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppUI.cardRadius),
            child: movie.posterPath == null
                ? Image.asset('assets/images/na_logo.png', fit: BoxFit.cover)
                : CachedNetworkImage(
                    cacheManager: cacheProp(),
                    imageUrl: buildImageUrl(
                          TMDB_BASE_IMAGE_URL,
                          dependencies.tmdbProxy,
                          settings.enableProxy,
                          context,
                        ) +
                        settings.imageQuality +
                        movie.posterPath!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const AppShimmerBlock(),
                    errorWidget: (_, __, ___) => Image.asset(
                      'assets/images/na_logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow(BuildContext context, {bool compact = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            displayTitle,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 23 : 27,
                  height: 1.12,
                  fontFamily: 'FigtreeSB',
                ),
          ),
        ),
        const SizedBox(width: 8),
        if (!compact)
          _SummaryAction(
            tooltip: tr('bookmarks'),
            onPressed: isBookmarked == null || bookmarkBusy ? null : onBookmark,
            child: bookmarkBusy || isBookmarked == null
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isBookmarked!
                        ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill)
                        : PhosphorIcons.bookmarkSimple(),
                  ),
          ),
        if (!compact)
          _SummaryAction(
            tooltip: tr('shared_the_app'),
            onPressed: onShare,
            child: Icon(PhosphorIcons.shareNetwork()),
          ),
      ],
    );
  }

  Widget _metadata(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rating = movie.voteAverage ?? 0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppRatingBadge(rating: rating),
        Text(
          tr('rating'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        if (releaseYear != null)
          _MetadataPill(icon: PhosphorIcons.calendar(), label: releaseYear!),
        if ((movie.originalLanguage ?? '').isNotEmpty)
          _MetadataPill(
            icon: PhosphorIcons.translate(),
            label: movie.originalLanguage!.toUpperCase(),
          ),
        _MetadataPill(
          icon: PhosphorIcons.users(),
          label:
              '${_compactCount(movie.voteCount ?? 0)} ${tr('total_ratings')}',
        ),
      ],
    );
  }

  Widget _genres() {
    return FutureBuilder<List<Genres>>(
      future: genres,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GenreShimmer();
        }
        if (snapshot.hasError) {
          return _InlineError(onRetry: onRetryGenres);
        }
        final items = snapshot.data ?? const <Genres>[];
        if (items.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (genre) => ActionChip(
                  label: Text(
                    genre.genreName ?? tr('genres'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'FigtreeSB',
                        ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  backgroundColor: Colors.transparent,
                  onPressed: genre.genreID == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GenreMovies(genres: genre),
                            ),
                          ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _overview(BuildContext context) {
    final overview = movie.overview?.trim() ?? '';
    if (overview.isEmpty) {
      return Text(
        tr('no_overview_movie'),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return ReadMoreText(
      overview,
      trimLines: 4,
      trimMode: TrimMode.Line,
      trimCollapsedText: ' ${tr('read_more')}',
      trimExpandedText: ' ${tr('read_less')}',
      colorClickableText: Theme.of(context).colorScheme.primary,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      moreStyle: const TextStyle(fontFamily: 'FigtreeSB'),
      lessStyle: const TextStyle(fontFamily: 'FigtreeSB'),
    );
  }

  Widget _releaseDate(BuildContext context) {
    final date = DateTime.tryParse(movie.releaseDate ?? '');
    final value = date == null
        ? tr('no_release_date')
        : '${tr('release_date')}: ${DateFormat.yMMMMd(context.locale.toString()).format(date)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          PhosphorIcons.calendarCheck(),
          size: 19,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    final appDependency = Provider.of<AppDependencyProvider>(context);
    final hasReleaseDate = DateTime.tryParse(movie.releaseDate ?? '') != null;
    final canWatch = appDependency.displayWatchNowButton && hasReleaseDate;
    final canDownload = appDependency.displayDownloadButton && hasReleaseDate;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (canWatch)
          FilledButton.icon(
            onPressed: onWatch,
            icon: Icon(PhosphorIcons.playCircle(PhosphorIconsStyle.fill)),
            label: Text(tr('watch_now')),
          ),
        if (canDownload)
          OutlinedButton.icon(
            onPressed: onDownload,
            icon: Icon(PhosphorIcons.downloadSimple()),
            label: Text(tr('download')),
          ),
        // "Where to watch" is intentionally hidden from the primary actions.
        // OutlinedButton.icon(...),
      ],
    );
  }
}

class _SummaryAction extends StatelessWidget {
  const _SummaryAction({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
      style: IconButton.styleFrom(
        backgroundColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: .06),
        foregroundColor: Theme.of(context).colorScheme.primary,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: child,
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastRail extends StatelessWidget {
  const _CastRail({required this.credits, required this.onRetry});

  final Future<Credits> credits;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Credits>(
      future: credits,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              title: tr('cast'),
              actionLabel: data == null || (data.cast ?? []).isEmpty
                  ? null
                  : tr('see_all_cast_crew'),
              onAction: data == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MovieCastAndCrew(credits: data),
                        ),
                      ),
            ),
            const SizedBox(height: 14),
            if (snapshot.connectionState != ConnectionState.done)
              const _CastShimmer()
            else if (snapshot.hasError)
              _InlineError(onRetry: onRetry)
            else if ((data?.cast ?? []).isEmpty)
              _CompactEmpty(
                icon: PhosphorIcons.users(),
                message: tr('no_cast_movie'),
              )
            else
              SizedBox(
                height: 138,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: data!.cast!.take(16).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) =>
                      _CastCard(cast: data.cast![index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.cast});

  final Cast cast;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CastDetailPage(
            cast: cast,
            heroId: '${cast.id}${cast.creditId}',
          ),
        ),
      ),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Hero(
              tag: '${cast.id}${cast.creditId}',
              child: SizedBox.square(
                dimension: 72,
                child: ClipOval(
                  child: cast.profilePath == null
                      ? Image.asset('assets/images/na_rect.png',
                          fit: BoxFit.cover)
                      : CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: buildImageUrl(
                                TMDB_BASE_IMAGE_URL,
                                dependencies.tmdbProxy,
                                settings.enableProxy,
                                context,
                              ) +
                              settings.imageQuality +
                              cast.profilePath!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const AppShimmerBlock(radius: 40),
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/images/na_rect.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              cast.name ?? tr('not_available'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 2),
            Text(
              cast.character?.isNotEmpty == true
                  ? cast.character!
                  : cast.department ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _MovieTabHeaderDelegate({
    required this.controller,
    required this.backgroundColor,
    required this.dividerColor,
  });

  final TabController controller;
  final Color backgroundColor;
  final Color dividerColor;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: AppResponsiveContent(
        padding: EdgeInsets.fromLTRB(
          AppUI.pagePadding(context),
          0,
          AppUI.pagePadding(context),
          0,
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Row(
            children: [
              _MovieTabButton(
                label: tr('media'),
                selected: controller.index == 0,
                onTap: () => controller.animateTo(0),
              ),
              _MovieTabButton(
                label: tr('movie_recommendations'),
                selected: controller.index == 1,
                onTap: () => controller.animateTo(1),
              ),
              _MovieTabButton(
                label: tr('movie_info'),
                selected: controller.index == 2,
                onTap: () => controller.animateTo(2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MovieTabHeaderDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor;
  }
}

class _MovieTabButton extends StatelessWidget {
  const _MovieTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 7, 4, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      height: 1.05,
                      fontFamily: selected ? 'FigtreeSB' : null,
                    ),
              ),
              const SizedBox(height: 9),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: selected ? 34 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({
    required this.videos,
    required this.images,
    required this.movieTitle,
    required this.onRetry,
  });

  final Future<Videos> videos;
  final Future<Images> images;
  final String movieTitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: tr('videos')),
        const SizedBox(height: 14),
        FutureBuilder<Videos>(
          future: videos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _VideoShimmer();
            }
            if (snapshot.hasError) return _InlineError(onRetry: onRetry);
            final items = snapshot.data?.result ?? const <Results>[];
            if (items.isEmpty) {
              return _CompactEmpty(
                icon: PhosphorIcons.filmStrip(),
                message: tr('no_video_movie'),
              );
            }
            return SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsetsDirectional.only(end: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => SizedBox(
                  width: MediaQuery.sizeOf(context).width >= 700 ? 310 : 272,
                  child: _VideoCard(video: items[index]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeading(title: tr('images')),
        const SizedBox(height: 14),
        FutureBuilder<Images>(
          future: images,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _GalleryShimmer();
            }
            if (snapshot.hasError) return _InlineError(onRetry: onRetry);
            return _GalleryPreview(
              images: snapshot.data!,
              movieTitle: movieTitle,
            );
          },
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});

  final Results video;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final key = video.videoLink;
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: key == null || key.isEmpty
          ? null
          : () => launchUrl(
                Uri.parse('$YOUTUBE_BASE_URL$key'),
                mode: LaunchMode.externalApplication,
              ),
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
                  if (key == null || key.isEmpty)
                    Image.asset('assets/images/na_rect.png', fit: BoxFit.cover)
                  else
                    CachedNetworkImage(
                      cacheManager: cacheProp(),
                      imageUrl: '$YOUTUBE_THUMBNAIL_URL$key/hqdefault.jpg',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const AppShimmerBlock(),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/images/na_rect.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .48)
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12),
                        ],
                      ),
                      child: Icon(
                        PhosphorIcons.play(),
                        color: colors.onPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            video.name ?? tr('videos'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _GalleryPreview extends StatelessWidget {
  const _GalleryPreview({required this.images, required this.movieTitle});

  final Images images;
  final String movieTitle;

  @override
  Widget build(BuildContext context) {
    final posters = images.poster ?? const <Posters>[];
    final backdrops = images.backdrop ?? const <Backdrops>[];
    if (posters.isEmpty && backdrops.isEmpty) {
      return _CompactEmpty(
        icon: PhosphorIcons.images(),
        message: tr('not_available'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 580;
        final cards = <Widget>[
          if (backdrops.isNotEmpty)
            _GalleryCard(
              path: backdrops.first.filePath,
              label: backdrops.length == 1
                  ? tr('backdrop_singular',
                      namedArgs: {'backdrop': backdrops.length.toString()})
                  : tr('backdrop_plural',
                      namedArgs: {'backdrop': backdrops.length.toString()}),
              aspectRatio: 16 / 9,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HeroPhotoView(
                    backdrops: backdrops,
                    name: movieTitle,
                    imageType: 'backdrop',
                  ),
                ),
              ),
            ),
          if (posters.isNotEmpty)
            _GalleryCard(
              path: posters.first.posterPath,
              label: posters.length == 1
                  ? tr('poster_singular',
                      namedArgs: {'poster': posters.length.toString()})
                  : tr('poster_plural',
                      namedArgs: {'poster': posters.length.toString()}),
              aspectRatio: 16 / 9,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HeroPhotoView(
                    posters: posters,
                    name: movieTitle,
                    imageType: 'poster',
                  ),
                ),
              ),
            ),
        ];
        if (!wide) {
          return Column(
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                cards[index],
                if (index != cards.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.path,
    required this.label,
    required this.aspectRatio,
    required this.onTap,
  });

  final String? path;
  final String label;
  final double aspectRatio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppUI.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              path == null
                  ? Image.asset('assets/images/na_logo.png', fit: BoxFit.cover)
                  : CachedNetworkImage(
                      cacheManager: cacheProp(),
                      imageUrl: buildImageUrl(
                            TMDB_BASE_IMAGE_URL,
                            dependencies.tmdbProxy,
                            settings.enableProxy,
                            context,
                          ) +
                          settings.imageQuality +
                          path!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const AppShimmerBlock(),
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
                    colors: [Colors.transparent, Color(0xB8000000)],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 14,
                end: 14,
                bottom: 12,
                child: Row(
                  children: [
                    Icon(PhosphorIcons.images(), size: 19, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'FigtreeSB',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieRail extends StatefulWidget {
  const _MovieRail({
    required this.title,
    required this.emptyMessage,
    required this.movieId,
    required this.includeAdult,
    required this.recommendations,
  });

  final String title;
  final String emptyMessage;
  final int movieId;
  final bool? includeAdult;
  final bool recommendations;

  @override
  State<_MovieRail> createState() => _MovieRailState();
}

class _MovieRailState extends State<_MovieRail> {
  static final Map<String, _MovieRailCache> _cache = {};
  final ScrollController _controller = ScrollController();
  List<Movie>? _movies;
  Object? _error;
  int _nextPage = 2;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    final cached = _cache[_cacheKey];
    if (cached == null) {
      _load(reset: true);
    } else {
      _movies = List<Movie>.of(cached.movies);
      _nextPage = cached.nextPage;
      _hasMore = cached.hasMore;
    }
  }

  String get _cacheKey =>
      '${widget.movieId}_${widget.recommendations}_${widget.includeAdult}';

  void _saveCache() {
    final movies = _movies;
    if (movies == null) return;
    _cache[_cacheKey] = _MovieRailCache(
      movies: List<Movie>.of(movies),
      nextPage: _nextPage,
      hasMore: _hasMore,
    );
  }

  String _api(int page, String language) {
    return widget.recommendations
        ? Endpoints.getMovieRecommendations(widget.movieId, page, language)
        : Endpoints.getSimilarMovies(widget.movieId, page, language);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _movies = null;
        _error = null;
        _nextPage = 2;
        _hasMore = true;
      });
    } else if (_loadingMore || !_hasMore) {
      return;
    } else {
      setState(() => _loadingMore = true);
    }

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);
    final page = reset ? 1 : _nextPage;
    try {
      final items = await fetchMovies(
        '${_api(page, settings.appLanguage)}&include_adult=${widget.includeAdult ?? false}',
        settings.enableProxy,
        dependencies.tmdbProxy,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _movies = items;
        } else {
          _movies!.addAll(items);
          _nextPage++;
        }
        _hasMore = items.isNotEmpty;
        _error = null;
      });
      _saveCache();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_controller.hasClients &&
        _controller.position.extentAfter < 260 &&
        _movies != null) {
      _load(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: widget.title),
        const SizedBox(height: 14),
        if (_movies == null && _error == null)
          const _MovieRailShimmer()
        else if (_movies == null)
          _InlineError(onRetry: () => _load(reset: true))
        else if (_movies!.isEmpty)
          _CompactEmpty(
            icon: PhosphorIcons.filmStrip(),
            message: widget.emptyMessage,
          )
        else
          SizedBox(
            height: 246,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _movies!.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == _movies!.length) {
                  return const SizedBox(
                    width: 132,
                    child: AppShimmerBlock(),
                  );
                }
                return _MoviePosterCard(
                  movie: _movies![index],
                  heroPrefix: widget.recommendations ? 'rec' : 'similar',
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _saveCache();
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }
}

class _MovieRailCache {
  const _MovieRailCache({
    required this.movies,
    required this.nextPage,
    required this.hasMore,
  });

  final List<Movie> movies;
  final int nextPage;
  final bool hasMore;
}

class _MovieRailShimmer extends StatelessWidget {
  const _MovieRailShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 246,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(
          width: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: AppUI.posterAspectRatio,
                child: AppShimmerBlock(),
              ),
              SizedBox(height: 9),
              SizedBox(
                width: 118,
                height: 13,
                child: AppShimmerBlock(radius: 4),
              ),
              SizedBox(height: 6),
              SizedBox(
                width: 76,
                height: 13,
                child: AppShimmerBlock(radius: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoviePosterCard extends StatelessWidget {
  const _MoviePosterCard({required this.movie, required this.heroPrefix});

  final Movie movie;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    final tag = '${heroPrefix}_${movie.id}_${movie.posterPath}';
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.cardRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailPage(movie: movie, heroId: tag),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: tag,
              child: Material(
                type: MaterialType.transparency,
                child: AspectRatio(
                  aspectRatio: AppUI.posterAspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.cardRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        movie.posterPath == null
                            ? Image.asset('assets/images/na_logo.png',
                                fit: BoxFit.cover)
                            : CachedNetworkImage(
                                cacheManager: cacheProp(),
                                imageUrl: buildImageUrl(
                                      TMDB_BASE_IMAGE_URL,
                                      dependencies.tmdbProxy,
                                      settings.enableProxy,
                                      context,
                                    ) +
                                    settings.imageQuality +
                                    movie.posterPath!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const AppShimmerBlock(),
                                errorWidget: (_, __, ___) => Image.asset(
                                  'assets/images/na_logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                        PositionedDirectional(
                          top: 8,
                          start: 8,
                          child: AppRatingBadge(
                            rating: movie.voteAverage,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              movie.title ?? tr('not_available'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.movie,
    required this.details,
    required this.collection,
    required this.socialLinks,
    required this.onRetry,
  });

  final Movie movie;
  final Future<MovieDetails> details;
  final Future<BelongsToCollection> collection;
  final Future<ExternalLinks> socialLinks;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<BelongsToCollection>(
          future: collection,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _CollectionShimmer();
            }
            if (snapshot.hasError) return _InlineError(onRetry: onRetry);
            final item = snapshot.data;
            if (item?.id == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CollectionBanner(collection: item!),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
        _SectionHeading(title: tr('movie_info')),
        const SizedBox(height: 14),
        FutureBuilder<MovieDetails>(
          future: details,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _InfoShimmer();
            }
            if (snapshot.hasError) return _InlineError(onRetry: onRetry);
            return _MovieInfoGrid(details: snapshot.data!);
          },
        ),
        const SizedBox(height: 32),
        _SectionHeading(title: tr('social_media_links')),
        const SizedBox(height: 14),
        FutureBuilder<ExternalLinks>(
          future: socialLinks,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SocialShimmer();
            }
            if (snapshot.hasError) return _InlineError(onRetry: onRetry);
            return _SocialLinks(links: snapshot.data!);
          },
        ),
      ],
    );
  }
}

class _CollectionBanner extends StatelessWidget {
  const _CollectionBanner({required this.collection});

  final BelongsToCollection collection;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    final path = collection.backdropPath ?? collection.posterPath;
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CollectionDetailsWidget(
            belongsToCollection: collection,
          ),
        ),
      ),
      child: AspectRatio(
        aspectRatio: 3 / 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppUI.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              path == null
                  ? Image.asset('assets/images/na_logo.png', fit: BoxFit.cover)
                  : CachedNetworkImage(
                      cacheManager: cacheProp(),
                      imageUrl: buildImageUrl(
                            TMDB_BASE_IMAGE_URL,
                            dependencies.tmdbProxy,
                            settings.enableProxy,
                            context,
                          ) +
                          settings.imageQuality +
                          path,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const AppShimmerBlock(),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/images/na_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xE6000000), Color(0x26000000)],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 20,
                end: 20,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            collection.name ?? tr('view_collection'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('view_collection'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretRight(), color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieInfoGrid extends StatelessWidget {
  const _MovieInfoGrid({required this.details});

  final MovieDetails details;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    final rows = <(IconData, String, String)>[
      (
        PhosphorIcons.textT(),
        tr('original_title'),
        _value(details.originalTitle)
      ),
      (PhosphorIcons.flag(), tr('status'), _value(details.status)),
      (
        PhosphorIcons.clock(),
        tr('runtime'),
        details.runtime == null || details.runtime == 0
            ? tr('not_available')
            : tr('runtime_mins', namedArgs: {'mins': '${details.runtime}'})
      ),
      (
        PhosphorIcons.translate(),
        tr('spoken_language'),
        _joined(details.spokenLanguages?.map((item) => item.englishName))
      ),
      (
        PhosphorIcons.wallet(),
        tr('budget'),
        details.budget == null || details.budget == 0
            ? tr('not_available')
            : currency.format(details.budget)
      ),
      (
        PhosphorIcons.trendUp(),
        tr('revenue'),
        details.revenue == null || details.revenue == 0
            ? tr('not_available')
            : currency.format(details.revenue)
      ),
      (PhosphorIcons.quotes(), tr('tagline'), _value(details.tagline)),
      (
        PhosphorIcons.buildings(),
        tr('production_companies'),
        _joined(details.productionCompanies?.map((item) => item.name))
      ),
      (
        PhosphorIcons.globe(),
        tr('production_countries'),
        _joined(details.productionCountries?.map((item) => item.name))
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: rows
              .map((row) => SizedBox(
                    width: width,
                    child: _InfoTile(
                      icon: row.$1,
                      label: row.$2,
                      value: row.$3,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String _value(String? value) {
    return value == null || value.trim().isEmpty ? tr('not_available') : value;
  }

  String _joined(Iterable<String?>? values) {
    final cleaned = values
            ?.whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    return cleaned.isEmpty ? tr('not_available') : cleaned.join(', ');
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'FigtreeSB',
                ),
          ),
        ],
      ),
    );
  }
}

class _SocialLinks extends StatelessWidget {
  const _SocialLinks({required this.links});

  final ExternalLinks links;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      if (links.facebookUsername != null)
        (
          PhosphorIcons.facebookLogo(),
          'Facebook',
          '$FACEBOOK_BASE_URL${links.facebookUsername}'
        ),
      if (links.instagramUsername != null)
        (
          PhosphorIcons.instagramLogo(),
          'Instagram',
          '$INSTAGRAM_BASE_URL${links.instagramUsername}'
        ),
      if (links.twitterUsername != null)
        (
          PhosphorIcons.twitterLogo(),
          'X',
          '$TWITTER_BASE_URL${links.twitterUsername}'
        ),
      if (links.imdbId != null)
        (PhosphorIcons.filmSlate(), 'IMDb', '$IMDB_BASE_URL${links.imdbId}'),
    ];
    if (items.isEmpty) {
      return _CompactEmpty(
        icon: PhosphorIcons.linkBreak(),
        message: tr('no_social_link_movie'),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(item.$3),
                mode: LaunchMode.externalApplication,
              ),
              icon: Icon(item.$1, size: 17),
              label: Text(item.$2),
            ),
          )
          .toList(),
    );
  }
}

class _WatchProvidersSheet extends StatefulWidget {
  const _WatchProvidersSheet({required this.api, required this.country});

  final String api;
  final String country;

  @override
  State<_WatchProvidersSheet> createState() => _WatchProvidersSheetState();
}

class _WatchProvidersSheetState extends State<_WatchProvidersSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  late Future<WatchProviders> _providers;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _load();
  }

  void _load() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dependencies =
        Provider.of<AppDependencyProvider>(context, listen: false);
    _providers = fetchWatchProviders(
      widget.api,
      widget.country,
      settings.enableProxy,
      dependencies.tmdbProxy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('watch_providers'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TabBar(
            controller: _controller,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(text: tr('stream')),
              Tab(text: tr('rent')),
              Tab(text: tr('buy')),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<WatchProviders>(
              future: _providers,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _ProviderShimmer();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: _InlineError(
                      onRetry: () => setState(_load),
                    ),
                  );
                }
                return TabBarView(
                  controller: _controller,
                  children: [
                    _ProviderGrid(
                      providers: snapshot.data!.flatRate,
                      emptyMessage: tr('no_stream'),
                    ),
                    _ProviderGrid(
                      providers: snapshot.data!.rent,
                      emptyMessage: tr('no_rent'),
                    ),
                    _ProviderGrid(
                      providers: snapshot.data!.buy,
                      emptyMessage: tr('no_buy'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ProviderGrid extends StatelessWidget {
  const _ProviderGrid({required this.providers, required this.emptyMessage});

  final List<dynamic>? providers;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (providers == null || providers!.isEmpty) {
      return _CompactEmpty(
        icon: PhosphorIcons.television(),
        message: emptyMessage,
      );
    }
    final settings = Provider.of<SettingsProvider>(context);
    final dependencies = Provider.of<AppDependencyProvider>(context);
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 140,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: providers!.length,
      itemBuilder: (context, index) {
        final provider = providers![index];
        return Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUI.cardRadius),
              child: SizedBox.square(
                dimension: 86,
                child: provider.logoPath == null
                    ? Image.asset('assets/images/na_logo.png',
                        fit: BoxFit.cover)
                    : CachedNetworkImage(
                        cacheManager: cacheProp(),
                        imageUrl: buildImageUrl(
                              TMDB_BASE_IMAGE_URL,
                              dependencies.tmdbProxy,
                              settings.enableProxy,
                              context,
                            ) +
                            settings.imageQuality +
                            provider.logoPath,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const AppShimmerBlock(),
                        errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/na_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.providerName ?? tr('not_available'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({this.title, this.actionLabel, this.onAction});

  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.cloudSlash(),
              color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(tr('check_connection'))),
          TextButton(onPressed: onRetry, child: Text(tr('retry'))),
        ],
      ),
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _GenreShimmer extends StatelessWidget {
  const _GenreShimmer();

  @override
  Widget build(BuildContext context) {
    final loadingColors = AppLoadingColors.of(context);
    return Shimmer.fromColors(
      baseColor: loadingColors.shimmerBase,
      highlightColor: loadingColors.shimmerHighlight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildFakeChip(context, 68),
          _buildFakeChip(context, 85),
          _buildFakeChip(context, 55),
        ],
      ),
    );
  }

  Widget _buildFakeChip(BuildContext context, double width) {
    return IgnorePointer(
      child: ActionChip(
        label: Container(
          width: width,
          height: 14,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        backgroundColor: Colors.transparent,
        onPressed: () {},
      ),
    );
  }
}

class _CastShimmer extends StatelessWidget {
  const _CastShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => const SizedBox(
          width: 92,
          child: Column(
            children: [
              SizedBox.square(
                dimension: 72,
                child: AppShimmerBlock(radius: 40),
              ),
              SizedBox(height: 9),
              SizedBox(height: 13, child: AppShimmerBlock(radius: 4)),
              SizedBox(height: 6),
              SizedBox(
                  width: 64, height: 10, child: AppShimmerBlock(radius: 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoShimmer extends StatelessWidget {
  const _VideoShimmer();

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width >= 700 ? 310.0 : 272.0;
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, __) => SizedBox(
          width: cardWidth,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AppShimmerBlock(),
              ),
              SizedBox(height: 10),
              SizedBox(
                width: 180,
                height: 16,
                child: AppShimmerBlock(radius: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryShimmer extends StatelessWidget {
  const _GalleryShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 580) {
          return const Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AppShimmerBlock(),
              ),
              SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AppShimmerBlock(),
              ),
            ],
          );
        }
        return const Row(
          children: [
            Expanded(
              child: AspectRatio(aspectRatio: 16 / 9, child: AppShimmerBlock()),
            ),
            SizedBox(width: 14),
            Expanded(
              child: AspectRatio(aspectRatio: 16 / 9, child: AppShimmerBlock()),
            ),
          ],
        );
      },
    );
  }
}

class _CollectionShimmer extends StatelessWidget {
  const _CollectionShimmer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AspectRatio(aspectRatio: 3 / 1, child: AppShimmerBlock()),
        SizedBox(height: 32),
      ],
    );
  }
}

class _InfoShimmer extends StatelessWidget {
  const _InfoShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            9,
            (_) => SizedBox(
              width: width,
              height: 94,
              child: const AppShimmerBlock(radius: 7),
            ),
          ),
        );
      },
    );
  }
}

class _SocialShimmer extends StatelessWidget {
  const _SocialShimmer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 108, height: 48, child: AppShimmerBlock(radius: 7)),
        SizedBox(width: 10),
        SizedBox(width: 108, height: 48, child: AppShimmerBlock(radius: 7)),
      ],
    );
  }
}

class _ProviderShimmer extends StatelessWidget {
  const _ProviderShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 140,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => const Column(
        children: [
          SizedBox.square(
            dimension: 86,
            child: AppShimmerBlock(radius: 7),
          ),
          SizedBox(height: 8),
          SizedBox(width: 76, height: 12, child: AppShimmerBlock(radius: 4)),
        ],
      ),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return value.toString();
}
