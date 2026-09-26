// ignore_for_file: avoid_unnecessary_containers

import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readmore/readmore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '/provider/settings_provider.dart';
import 'package:provider/provider.dart';
import '/models/tv.dart';
import '/widgets/tv_widgets.dart';
import 'package:flutter/material.dart';
import '/api/endpoints.dart';
import '../../ui_components/app_ui_components.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../constants/loading_colors.dart';
import '../../functions/function.dart';
import '../../provider/app_dependency_provider.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../provider/bookmark_provider.dart';
import '../../services/ambient_theme_service.dart';
import '../../functions/network.dart';
import '../../models/credits.dart';
import '../../models/images.dart';
import '../../models/videos.dart';
import '../../models/genres.dart';
import '../person/cast_detail.dart';
import 'genre_tv.dart';
import 'seasons_detail.dart';
import 'tvdetail_castandcrew.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

class TVDetailPage extends StatefulWidget {
  final TV tvSeries;
  final String heroId;

  const TVDetailPage({
    super.key,
    required this.tvSeries,
    required this.heroId,
  });
  @override
  TVDetailPageState createState() => TVDetailPageState();
}

class TVDetailPageState extends State<TVDetailPage>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<TVDetailPage> {
  late TabController tabController;
  final scrollController = ScrollController();
  final TVDatabaseController _database = TVDatabaseController();
  late Future<TVDetails> _details;
  late Future<Images> _images;
  late Future<Videos> _videos;
  late Future<Credits> _credits;
  late Future<List<Genres>> _genres;
  bool? _isBookmarked;
  bool _bookmarkBusy = false;
  final AmbientThemeScopeController _ambientTheme =
      AmbientThemeScopeController();

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _loadData();
    _ambientTheme.attach(
      context,
      widget.tvSeries.posterPath ?? widget.tvSeries.backdropPath,
    );
    _checkBookmark();
    mixpanelUpload(context);
  }

  void _loadData() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final proxy =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final id = widget.tvSeries.id!;
    _details = fetchTVDetails(
      Endpoints.tvDetailsUrl(id, settings.appLanguage),
      settings.enableProxy,
      proxy,
    );
    _images = fetchImages(
      Endpoints.getTVImages(id),
      settings.enableProxy,
      proxy,
    );
    _videos = fetchVideos(
      Endpoints.getTVVideos(id),
      settings.enableProxy,
      proxy,
    );
    _credits = fetchCredits(
      Endpoints.getTVCreditsUrl(id, settings.appLanguage),
      settings.enableProxy,
      proxy,
    );
    _genres = fetchGenre(
      Endpoints.tvDetailsUrl(id, settings.appLanguage),
      settings.enableProxy,
      proxy,
    );
  }

  void _onTabChanged() {
    if (!tabController.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _checkBookmark() async {
    final value = await _database.contain(widget.tvSeries.id!);
    if (mounted) setState(() => _isBookmarked = value);
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked == null || _bookmarkBusy) return;
    setState(() => _bookmarkBusy = true);
    final provider = Provider.of<BookmarkProvider>(context, listen: false);
    if (_isBookmarked!) {
      await provider.removeTV(widget.tvSeries.id!);
    } else {
      await provider.addTV(widget.tvSeries);
    }
    if (!mounted) return;
    setState(() {
      _isBookmarked = !_isBookmarked!;
      _bookmarkBusy = false;
    });
  }

  void mixpanelUpload(BuildContext context) {
    Provider.of<SettingsProvider>(context, listen: false)
        .analytics
        .trackTVPageView(
          tvName: widget.tvSeries.name,
          tvId: widget.tvSeries.id,
          isAdult: widget.tvSeries.adult,
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.sizeOf(context);
    final heroHeight = (size.height * .36).clamp(240.0, 340.0);
    final year = DateTime.tryParse(widget.tvSeries.firstAirDate ?? '')?.year;
    final title = widget.tvSeries.name ?? tr('not_available');
    return Scaffold(
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: heroHeight,
            toolbarHeight: 64,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 68,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _TVHeroButton(
                icon: PhosphorIcons.caretLeft(),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: AnimatedBuilder(
              animation: scrollController,
              builder: (context, _) => AnimatedOpacity(
                opacity: scrollController.hasClients &&
                        scrollController.offset > heroHeight - 110
                    ? 1
                    : 0,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  year == null ? title : '$title  •  $year',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'FigtreeSB',
                      ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _TVBackdrop(tv: widget.tvSeries, images: _images),
            ),
          ),
          SliverToBoxAdapter(
            child: AppResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                22,
                AppUI.pagePadding(context),
                8,
              ),
              child: _TVSummary(
                tv: widget.tvSeries,
                heroId: widget.heroId,
                details: _details,
                credits: _credits,
                genres: _genres,
                isBookmarked: _isBookmarked,
                bookmarkBusy: _bookmarkBusy,
                onBookmark: _toggleBookmark,
                onShare: () => Share.share(tr('share_tv', namedArgs: {
                  'title': title,
                  'rating':
                      (widget.tvSeries.voteAverage ?? 0).toStringAsFixed(1),
                  'id': widget.tvSeries.id.toString(),
                })),
                onProviders: () => modalBottomSheetMenu(
                  Provider.of<SettingsProvider>(context, listen: false)
                      .defaultCountry,
                ),
                onRetry: () => setState(_loadData),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RemoteHostedAdsBanner(
              placement: 'tv_detail',
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TVTabHeader(
              controller: tabController,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          SliverToBoxAdapter(
            child: AppResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                16,
                AppUI.pagePadding(context),
                40 + MediaQuery.paddingOf(context).bottom,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(tabController.index),
                  child: _selectedTab(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _selectedTab() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    switch (tabController.index) {
      case 0:
        return _TVMediaTab(
          videos: _videos,
          images: _images,
          onRetry: () => setState(_loadData),
        );
      case 1:
        return Column(
          children: [
            _TVRail(
              title: tr('tv_recommendations'),
              emptyMessage: tr('no_recommendations_tv'),
              apiBuilder: (page) => Endpoints.getTVRecommendations(
                widget.tvSeries.id!,
                page,
                settings.appLanguage,
              ),
              heroPrefix: 'tv_rec',
            ),
            const SizedBox(height: 30),
            _TVRail(
              title: tr(
                'tv_similar_with',
                namedArgs: {'show': widget.tvSeries.name ?? ''},
              ),
              emptyMessage: tr('no_similars_tv'),
              apiBuilder: (page) => Endpoints.getSimilarTV(
                widget.tvSeries.id!,
                page,
                settings.appLanguage,
              ),
              heroPrefix: 'tv_similar',
            ),
          ],
        );
      default:
        return _TVInfoTab(tv: widget.tvSeries, details: _details);
    }
  }

  void modalBottomSheetMenu(String country) {
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        return TVWatchProvidersDetails(
          api: Endpoints.getTVWatchProviders(widget.tvSeries.id!, lang),
          country: country,
        );
      },
    );
  }

  @override
  void dispose() {
    _ambientTheme.dispose();
    tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    scrollController.dispose();
    super.dispose();
  }
}

class _TVBackdrop extends StatelessWidget {
  const _TVBackdrop({required this.tv, required this.images});

  final TV tv;
  final Future<Images> images;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    // final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Images>(
      future: images,
      builder: (context, snapshot) {
        final paths = <String>{
          if ((tv.backdropPath ?? '').isNotEmpty) tv.backdropPath!,
          ...?snapshot.data?.backdrop
              ?.map((item) => item.filePath)
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
                interval: const Duration(seconds: 6),
                indicatorBottom: 15,
                itemBuilder: (context, index) => CachedNetworkImage(
                  cacheManager: cacheProp(),
                  imageUrl:
                      '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxy, settings.enableProxy, context)}original${paths[index]}',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => const AppShimmerBlock(radius: 0),
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/images/na_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            // const AppDetailHeroGradient(),
            // IgnorePointer(
            //   child: Align(
            //     alignment: Alignment.bottomCenter,
            //     child: Container(
            //       height: 64,
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

class _TVHeroButton extends StatelessWidget {
  const _TVHeroButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 42,
        child: Material(
          color: Colors.black.withValues(alpha: .38),
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            color: Colors.white,
            icon: Icon(icon, size: 21),
          ),
        ),
      ),
    );
  }
}

class _TVSummary extends StatelessWidget {
  const _TVSummary({
    required this.tv,
    required this.heroId,
    required this.onShare,
    required this.onProviders,
    required this.details,
    required this.credits,
    required this.genres,
    required this.isBookmarked,
    required this.bookmarkBusy,
    required this.onBookmark,
    required this.onRetry,
  });

  final TV tv;
  final String heroId;
  final VoidCallback onShare;
  final VoidCallback onProviders;
  final Future<TVDetails> details;
  final Future<Credits> credits;
  final Future<List<Genres>> genres;
  final bool? isBookmarked;
  final bool bookmarkBusy;
  final VoidCallback onBookmark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final year = DateTime.tryParse(tv.firstAirDate ?? '')?.year;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: heroId,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.cardRadius),
                child: SizedBox(
                  width: 104,
                  height: 156,
                  child: (tv.posterPath ?? '').isEmpty
                      ? Image.asset('assets/images/na_logo.png',
                          fit: BoxFit.cover)
                      : CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: buildImageUrl(
                                TMDB_BASE_IMAGE_URL,
                                proxy,
                                settings.enableProxy,
                                context,
                              ) +
                              settings.imageQuality +
                              tv.posterPath!,
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tv.name ?? tr('not_available'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'FigtreeSB',
                          height: 1.12,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppRatingBadge(rating: tv.voteAverage),
                      Text(
                        tr('rating'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      if (year != null)
                        _TVMetadataPill(
                          icon: PhosphorIcons.calendar(),
                          label: '$year',
                        ),
                      if ((tv.originalLanguage ?? '').isNotEmpty)
                        _TVMetadataPill(
                          icon: PhosphorIcons.translate(),
                          label: tv.originalLanguage!.toUpperCase(),
                        ),
                      _TVMetadataPill(
                        icon: PhosphorIcons.users(),
                        label: '${tv.voteCount ?? 0} ${tr('total_ratings')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: tr('bookmarks'),
                        onPressed: isBookmarked == null || bookmarkBusy
                            ? null
                            : onBookmark,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: bookmarkBusy || isBookmarked == null
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                isBookmarked!
                                    ? PhosphorIcons.bookmarkSimple(
                                        PhosphorIconsStyle.fill)
                                    : PhosphorIcons.bookmarkSimple(),
                              ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: tr('shared_the_app'),
                        onPressed: onShare,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(PhosphorIcons.shareNetwork()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<Genres>>(
          future: genres,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _TVGenreShimmer();
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
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
                                  builder: (_) => TVGenre(genres: genre),
                                ),
                              ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        if ((tv.overview ?? '').isNotEmpty)
          ReadMoreText(
            tv.overview!,
            trimLines: 4,
            trimMode: TrimMode.Line,
            trimCollapsedText: ' ${tr('read_more')}',
            trimExpandedText: ' ${tr('read_less')}',
            colorClickableText: Theme.of(context).colorScheme.primary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        const SizedBox(height: 18),
        // "Where to watch" is intentionally hidden from the primary actions.
        // OutlinedButton.icon(...),
        const SizedBox(height: 8),
        _TVCastRail(credits: credits, onRetry: onRetry, tvId: tv.id!),
        const SizedBox(height: 24),
        _TVSeasonsRail(
          details: details,
          tv: tv,
          onRetry: onRetry,
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _TVMetadataPill extends StatelessWidget {
  const _TVMetadataPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
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

class _TVTabHeader extends SliverPersistentHeaderDelegate {
  const _TVTabHeader({required this.controller, required this.backgroundColor});

  final TabController controller;
  final Color backgroundColor;

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: AppResponsiveContent(
        padding: EdgeInsets.symmetric(horizontal: AppUI.pagePadding(context)),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Row(
            children: [
              _TVTabButton(
                label: tr('media'),
                selected: controller.index == 0,
                onTap: () => controller.animateTo(0),
              ),
              _TVTabButton(
                label: tr('tv_recommendations'),
                selected: controller.index == 1,
                onTap: () => controller.animateTo(1),
              ),
              _TVTabButton(
                label: tr('tv_series_info'),
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
  bool shouldRebuild(covariant _TVTabHeader oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _TVTabButton extends StatelessWidget {
  const _TVTabButton({
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

class _TVCastRail extends StatelessWidget {
  const _TVCastRail({
    required this.credits,
    required this.onRetry,
    required this.tvId,
  });

  final Future<Credits> credits;
  final VoidCallback onRetry;
  final int tvId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Credits>(
      future: credits,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TVSectionHeading(title: tr('cast')),
              const SizedBox(height: 14),
              const SizedBox(height: 138, child: _TVCastShimmer()),
            ],
          );
        }
        if (snapshot.hasError) return _TVInlineError(onRetry: onRetry);
        final cast = snapshot.data?.cast ?? const <Cast>[];
        if (cast.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TVSectionHeading(
              title: tr('cast'),
              actionLabel: tr('see_all_cast_crew'),
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TVDetailCastAndCrew(
                    id: tvId,
                    passedFrom: 'tv_detail',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: cast.take(16).length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) => _TVCastCard(cast: cast[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TVCastCard extends StatelessWidget {
  const _TVCastCard({required this.cast});

  final Cast cast;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CastDetailPage(cast: cast, heroId: 'tv_${cast.id}'),
        ),
      ),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Hero(
              tag: 'tv_${cast.id}',
              child: SizedBox.square(
                dimension: 72,
                child: ClipOval(
                  child: (cast.profilePath ?? '').isEmpty
                      ? Image.asset('assets/images/na_rect.png',
                          fit: BoxFit.cover)
                      : CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: buildImageUrl(
                                TMDB_BASE_IMAGE_URL,
                                proxy,
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
            const SizedBox(height: 8),
            Text(
              cast.name ?? tr('not_available'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 2),
            Text(
              cast.roles?.firstOrNull?.character ?? cast.character ?? '',
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

class _TVSeasonsRail extends StatelessWidget {
  const _TVSeasonsRail({
    required this.details,
    required this.tv,
    required this.onRetry,
  });

  final Future<TVDetails> details;
  final TV tv;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TVDetails>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TVSectionHeading(title: tr('seasons')),
              const SizedBox(height: 14),
              const _TVSeasonRailShimmer(),
            ],
          );
        }
        if (snapshot.hasError) return _TVInlineError(onRetry: onRetry);
        final seasons = snapshot.data?.seasons ?? const <Seasons>[];
        if (seasons.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TVSectionHeading(title: tr('seasons')),
            const SizedBox(height: 14),
            SizedBox(
              height: 238,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: seasons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _TVSeasonCard(
                  season: seasons[index],
                  details: snapshot.data!,
                  tv: tv,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TVSeasonCard extends StatelessWidget {
  const _TVSeasonCard(
      {required this.season, required this.details, required this.tv});

  final Seasons season;
  final TVDetails details;
  final TV tv;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final tag = 'season_${tv.id}_${season.seasonNumber}';
    return SizedBox(
      width: 126,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.cardRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeasonsDetail(
              seasons: season,
              heroId: tag,
              tvDetails: details,
              tvId: tv.id,
              seriesName: tv.name,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: tag,
              child: AspectRatio(
                aspectRatio: AppUI.posterAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppUI.cardRadius),
                  child: (season.posterPath ?? '').isEmpty
                      ? Image.asset('assets/images/na_logo.png',
                          fit: BoxFit.cover)
                      : CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: buildImageUrl(
                                TMDB_BASE_IMAGE_URL,
                                proxy,
                                settings.enableProxy,
                                context,
                              ) +
                              settings.imageQuality +
                              season.posterPath!,
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
            const SizedBox(height: 8),
            Text(
              season.name ?? tr('seasons'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              tr('episodes_count', namedArgs: {
                'count': (season.episodeCount ?? 0).toString(),
              }),
              maxLines: 1,
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

class _TVMediaTab extends StatelessWidget {
  const _TVMediaTab({
    required this.videos,
    required this.images,
    required this.onRetry,
  });

  final Future<Videos> videos;
  final Future<Images> images;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TVSectionHeading(title: tr('videos')),
        const SizedBox(height: 14),
        FutureBuilder<Videos>(
          future: videos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _TVVideoShimmer();
            }
            if (snapshot.hasError) return _TVInlineError(onRetry: onRetry);
            final items = snapshot.data?.result ?? const <Results>[];
            if (items.isEmpty) {
              return _TVEmpty(
                icon: PhosphorIcons.filmStrip(),
                message: tr('not_available'),
              );
            }
            return SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => SizedBox(
                  width: MediaQuery.sizeOf(context).width >= 700 ? 310 : 272,
                  child: _TVVideoCard(video: items[index]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
        _TVSectionHeading(title: tr('images')),
        const SizedBox(height: 14),
        FutureBuilder<Images>(
          future: images,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _TVImageRailShimmer();
            }
            if (snapshot.hasError) return _TVInlineError(onRetry: onRetry);
            final paths = <String>[
              ...?snapshot.data?.backdrop
                  ?.map((item) => item.filePath)
                  .whereType<String>(),
              ...?snapshot.data?.poster
                  ?.map((item) => item.posterPath)
                  .whereType<String>(),
            ];
            if (paths.isEmpty) {
              return _TVEmpty(
                icon: PhosphorIcons.images(),
                message: tr('not_available'),
              );
            }
            return SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: paths.take(16).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _TVImageCard(path: paths[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TVVideoCard extends StatelessWidget {
  const _TVVideoCard({required this.video});

  final Results video;

  @override
  Widget build(BuildContext context) {
    final key = video.videoLink;
    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      onTap: (key ?? '').isEmpty
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
                  if ((key ?? '').isEmpty)
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
                  Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12)
                        ],
                      ),
                      child: Icon(
                        PhosphorIcons.play(),
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 31,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
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

class _TVImageCard extends StatelessWidget {
  const _TVImageCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUI.cardRadius),
      child: SizedBox(
        width: 260,
        child: CachedNetworkImage(
          cacheManager: cacheProp(),
          imageUrl: buildImageUrl(
                TMDB_BASE_IMAGE_URL,
                proxy,
                settings.enableProxy,
                context,
              ) +
              settings.imageQuality +
              path,
          fit: BoxFit.cover,
          placeholder: (_, __) => const AppShimmerBlock(),
          errorWidget: (_, __, ___) =>
              Image.asset('assets/images/na_rect.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _TVRail extends StatefulWidget {
  const _TVRail({
    required this.title,
    required this.emptyMessage,
    required this.apiBuilder,
    required this.heroPrefix,
  });

  final String title;
  final String emptyMessage;
  final String Function(int page) apiBuilder;
  final String heroPrefix;

  @override
  State<_TVRail> createState() => _TVRailState();
}

class _TVRailState extends State<_TVRail> {
  static final Map<String, List<TV>> _cache = {};
  List<TV>? _items;
  Object? _error;

  String get _key => widget.apiBuilder(1);

  @override
  void initState() {
    super.initState();
    final cached = _cache[_key];
    if (cached != null) {
      _items = List<TV>.of(cached);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final proxy =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    try {
      final items = await fetchTV(
        widget.apiBuilder(1),
        settings.enableProxy,
        proxy,
      );
      if (!mounted) return;
      _cache[_key] = List<TV>.of(items);
      setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TVSectionHeading(title: widget.title),
        const SizedBox(height: 14),
        if (_items == null && _error == null)
          const _TVPosterRailShimmer()
        else if (_items == null)
          _TVInlineError(onRetry: _load)
        else if (_items!.isEmpty)
          _TVEmpty(
              icon: PhosphorIcons.televisionSimple(),
              message: widget.emptyMessage)
        else
          SizedBox(
            height: 246,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _items!.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _TVPosterCard(
                tv: _items![index],
                heroPrefix: widget.heroPrefix,
              ),
            ),
          ),
      ],
    );
  }
}

class _TVPosterCard extends StatelessWidget {
  const _TVPosterCard({required this.tv, required this.heroPrefix});

  final TV tv;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final tag = '${heroPrefix}_${tv.id}_${tv.posterPath}';
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.cardRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TVDetailPage(tvSeries: tv, heroId: tag)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: tag,
              child: AspectRatio(
                aspectRatio: AppUI.posterAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppUI.cardRadius),
                  child: (tv.posterPath ?? '').isEmpty
                      ? Image.asset('assets/images/na_logo.png',
                          fit: BoxFit.cover)
                      : CachedNetworkImage(
                          cacheManager: cacheProp(),
                          imageUrl: buildImageUrl(
                                TMDB_BASE_IMAGE_URL,
                                proxy,
                                settings.enableProxy,
                                context,
                              ) +
                              settings.imageQuality +
                              tv.posterPath!,
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
            const SizedBox(height: 9),
            Text(
              tv.name ?? tr('not_available'),
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

class _TVInfoTab extends StatelessWidget {
  const _TVInfoTab({required this.tv, required this.details});

  final TV tv;
  final Future<TVDetails> details;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TVDetails>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TVSectionHeading(title: tr('tv_series_info')),
              const SizedBox(height: 14),
              ...List.generate(5, (_) => const _TVInfoRowShimmer()),
            ],
          );
        }
        if (snapshot.hasError) return const SizedBox.shrink();
        final value = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TVSectionHeading(title: tr('tv_series_info')),
            const SizedBox(height: 14),
            _TVInfoRow(
              icon: PhosphorIcons.info(),
              label: tr('status'),
              value: value.status ?? tr('not_available'),
            ),
            _TVInfoRow(
              icon: PhosphorIcons.filmStrip(),
              label: tr('seasons'),
              value: (value.numberOfSeasons ?? 0).toString(),
            ),
            _TVInfoRow(
              icon: PhosphorIcons.playlist(),
              label: tr('episodes'),
              value: (value.numberOfEpisodes ?? 0).toString(),
            ),
            _TVInfoRow(
              icon: PhosphorIcons.translate(),
              label: tr('original_language'),
              value: (tv.originalLanguage ?? tr('not_available')).toUpperCase(),
            ),
            _TVInfoRow(
              icon: PhosphorIcons.calendar(),
              label: tr('first_episode_air'),
              value: tv.firstAirDate ?? tr('not_available'),
            ),
            if ((value.tagline ?? '').isNotEmpty)
              _TVInfoRow(
                icon: PhosphorIcons.quotes(),
                label: tr('tagline'),
                value: value.tagline!,
              ),
          ],
        );
      },
    );
  }
}

class _TVInfoRow extends StatelessWidget {
  const _TVInfoRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 21),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TVSectionHeading extends StatelessWidget {
  const _TVSectionHeading({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'FigtreeSB',
                ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _TVInlineError extends StatelessWidget {
  const _TVInlineError({required this.onRetry});

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

class _TVEmpty extends StatelessWidget {
  const _TVEmpty({required this.icon, required this.message});

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
        children: [
          Icon(icon, size: 34, color: colors.primary),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TVGenreShimmer extends StatelessWidget {
  const _TVGenreShimmer();

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

class _TVCastShimmer extends StatelessWidget {
  const _TVCastShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => const SizedBox(
          width: 92,
          child: Column(
            children: [
              SizedBox.square(
                  dimension: 72, child: AppShimmerBlock(radius: 40)),
              SizedBox(height: 9),
              SizedBox(height: 12, child: AppShimmerBlock(radius: 4)),
              SizedBox(height: 6),
              SizedBox(
                width: 64,
                height: 10,
                child: AppShimmerBlock(radius: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVPosterRailShimmer extends StatelessWidget {
  const _TVPosterRailShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 246,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
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
                  width: 112, height: 13, child: AppShimmerBlock(radius: 4)),
              SizedBox(height: 6),
              SizedBox(
                  width: 72, height: 11, child: AppShimmerBlock(radius: 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVSeasonRailShimmer extends StatelessWidget {
  const _TVSeasonRailShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 238,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(
          width: 126,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: AppUI.posterAspectRatio,
                child: AppShimmerBlock(),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: 108,
                height: 13,
                child: AppShimmerBlock(radius: 4),
              ),
              SizedBox(height: 5),
              SizedBox(
                width: 78,
                height: 10,
                child: AppShimmerBlock(radius: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVVideoShimmer extends StatelessWidget {
  const _TVVideoShimmer();

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width >= 700 ? 310.0 : 272.0;
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, __) => SizedBox(
          width: cardWidth,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: AppShimmerBlock()),
              SizedBox(height: 10),
              SizedBox(
                  width: 210, height: 16, child: AppShimmerBlock(radius: 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVImageRailShimmer extends StatelessWidget {
  const _TVImageRailShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(
          width: 260,
          child: AppShimmerBlock(),
        ),
      ),
    );
  }
}

class _TVInfoRowShimmer extends StatelessWidget {
  const _TVInfoRowShimmer();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 66,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox.square(
            dimension: 21,
            child: AppShimmerBlock(radius: 6),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 92,
                  height: 10,
                  child: AppShimmerBlock(radius: 4),
                ),
                SizedBox(height: 5),
                SizedBox(
                  width: 168,
                  height: 14,
                  child: AppShimmerBlock(radius: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
