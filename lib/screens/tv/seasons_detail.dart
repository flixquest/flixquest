import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../functions/function.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../widgets/common_widgets.dart';
import '/api/endpoints.dart';
import '/constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '/models/tv.dart';
import '/widgets/tv_widgets.dart';
import 'package:flutter/material.dart';
import 'package:readmore/readmore.dart';
import '/widgets/movie_widgets.dart';
import '../../ui_components/app_ui_components.dart';
import '../../functions/network.dart';
import '../../models/credits.dart';
import '../../models/images.dart';
import '../../models/videos.dart';
import '../../services/ambient_theme_service.dart';
import 'episode_detail.dart';
import 'tvseason_castandcrew.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../video_providers/scraper_api.dart';
import '../../widgets/hosted_ads_banner.dart';

class SeasonsDetail extends StatefulWidget {
  final Seasons seasons;
  final String heroId;
  final int? tvId;
  final String? seriesName;
  final TVDetails tvDetails;

  const SeasonsDetail({
    super.key,
    required this.seasons,
    required this.heroId,
    required this.tvDetails,
    this.seriesName,
    this.tvId,
  });

  @override
  SeasonsDetailState createState() => SeasonsDetailState();
}

class SeasonsDetailState extends State<SeasonsDetail>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<SeasonsDetail> {
  late TabController tabController;
  final scrollController = ScrollController();
  late Future<TVDetails> _seasonDetails;
  late Future<Credits> _credits;
  late Future<Images> _images;
  late Future<Videos> _videos;
  final AmbientThemeScopeController _ambientTheme =
      AmbientThemeScopeController();

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    _loadData();
    _ambientTheme.attach(
      context,
      widget.seasons.posterPath ?? widget.tvDetails.backdropPath,
    );
    mixpanelUpload(context);
  }

  void _loadData() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final proxy =
        Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
    final id = widget.tvId!;
    final season = widget.seasons.seasonNumber!;
    _seasonDetails = fetchTVDetails(
      Endpoints.getSeasonDetails(id, season, settings.appLanguage),
      settings.enableProxy,
      proxy,
    );
    _credits = fetchCredits(
      Endpoints.getTVSeasonCreditsUrl(id, season, settings.appLanguage),
      settings.enableProxy,
      proxy,
    );
    _images = fetchImages(
      Endpoints.getTVSeasonImagesUrl(id, season),
      settings.enableProxy,
      proxy,
    );
    _videos = fetchVideos(
      Endpoints.getTVSeasonVideosUrl(id, season),
      settings.enableProxy,
      proxy,
    );
  }

  void mixpanelUpload(BuildContext context) {
    Provider.of<SettingsProvider>(context, listen: false)
        .analytics
        .trackSeasonDetailView(
          tvName: widget.seriesName,
          seasonNumber: widget.seasons.seasonNumber,
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final year = DateTime.tryParse(widget.seasons.airDate ?? '')?.year;
    final title = widget.seasons.name ?? tr('seasons');
    return Scaffold(
      body: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leadingWidth: 68,
            leading: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _SeasonHeroButton(
                onPressed: () => Navigator.pop(context),
              ),
            ),
            title: AnimatedBuilder(
              animation: scrollController,
              builder: (context, _) => AnimatedOpacity(
                opacity:
                    scrollController.hasClients && scrollController.offset > 135
                        ? 1
                        : 0,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  year == null ? title : '$title  •  $year',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            expandedHeight: 240,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _SeasonBackdrop(
                path: widget.tvDetails.backdropPath,
                images: _images,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AppResponsiveContent(
              padding: EdgeInsets.fromLTRB(
                AppUI.pagePadding(context),
                18,
                AppUI.pagePadding(context),
                36,
              ),
              child: _SeasonContent(
                season: widget.seasons,
                seriesName: widget.seriesName,
                tvId: widget.tvId!,
                heroId: widget.heroId,
                details: _seasonDetails,
                credits: _credits,
                images: _images,
                videos: _videos,
                onRetry: () => setState(_loadData),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: RemoteHostedAdsBanner(
              placement: 'season_detail',
              loadAds: () => ScraperApi(
                context.read<AppDependencyProvider>().flixquestAPIURL,
              ).getAds(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _ambientTheme.dispose();
    tabController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

class _SeasonHeroButton extends StatelessWidget {
  const _SeasonHeroButton({required this.onPressed});

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
            icon: Icon(PhosphorIcons.caretLeft(), size: 21),
          ),
        ),
      ),
    );
  }
}

class _SeasonBackdrop extends StatelessWidget {
  const _SeasonBackdrop({required this.path, required this.images});

  final String? path;
  final Future<Images> images;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return FutureBuilder<Images>(
      future: images,
      builder: (context, snapshot) {
        final paths = <String>{
          if ((path ?? '').isNotEmpty) path!,
          ...?snapshot.data?.backdrop
              ?.map((item) => item.filePath)
              .whereType<String>(),
          ...?snapshot.data?.poster
              ?.map((item) => item.posterPath)
              .whereType<String>(),
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
                      '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxy, settings.enableProxy, context)}original${paths[index]}',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const AppShimmerBlock(radius: 0),
                  errorWidget: (_, __, ___) => Image.asset(
                      'assets/images/na_logo.png',
                      fit: BoxFit.cover),
                ),
              ),
            // const AppDetailHeroGradient(),
          ],
        );
      },
    );
  }
}

class _SeasonContent extends StatelessWidget {
  const _SeasonContent({
    required this.season,
    required this.seriesName,
    required this.tvId,
    required this.heroId,
    required this.details,
    required this.credits,
    required this.images,
    required this.videos,
    required this.onRetry,
  });

  final Seasons season;
  final String? seriesName;
  final int tvId;
  final String heroId;
  final Future<TVDetails> details;
  final Future<Credits> credits;
  final Future<Images> images;
  final Future<Videos> videos;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final year = DateTime.tryParse(season.airDate ?? '')?.year;
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
                  width: 108,
                  height: 162,
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    season.name ?? tr('seasons'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'FigtreeSB',
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    seriesName ?? '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (year != null) ...[
                    const SizedBox(height: 12),
                    _SeasonMetadataPill(
                      icon: PhosphorIcons.calendar(),
                      label: '$year',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if ((season.overview ?? '').isNotEmpty) ...[
          const SizedBox(height: 18),
          ReadMoreText(
            season.overview!,
            trimLines: 4,
            trimMode: TrimMode.Line,
            trimCollapsedText: ' ${tr('read_more')}',
            trimExpandedText: ' ${tr('read_less')}',
            colorClickableText: Theme.of(context).colorScheme.primary,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
        const SizedBox(height: 28),
        _SeasonCastRail(
          credits: credits,
          onRetry: onRetry,
          tvId: tvId,
          seasonNumber: season.seasonNumber ?? 0,
        ),
        const SizedBox(height: 28),
        _SeasonHeading(
          title: tr('episodes'),
          trailing: (season.episodeCount ?? 0) > 0
              ? Text(
                  tr(
                    'episodes_count',
                    namedArgs: {'count': season.episodeCount.toString()},
                  ),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        FutureBuilder<TVDetails>(
          future: details,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              final episodeCount = season.episodeCount ?? 0;
              return _EpisodeListShimmer(
                itemCount: episodeCount > 0 ? episodeCount : 3,
              );
            }
            if (snapshot.hasError) return _SeasonError(onRetry: onRetry);
            final episodes = snapshot.data?.episodes ?? const <EpisodeList>[];
            if (episodes.isEmpty) {
              return Center(child: Text(tr('not_available')));
            }
            // One shared slot width keeps every title left-aligned once the
            // season crosses episode 9.
            var digits = 1;
            for (final item in episodes) {
              final width = (item.episodeNumber ?? 0).toString().length;
              if (width > digits) digits = width;
            }
            final numberSlot = 18.0 + ((digits - 1) * 10);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < episodes.length; index++) ...[
                  _EpisodeRow(
                    episode: episodes[index],
                    episodes: episodes,
                    tvId: tvId,
                    seriesName: seriesName,
                    posterPath: season.posterPath,
                    numberSlot: numberSlot,
                  ),
                  if (index != episodes.length - 1) const _EpisodeDivider(),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _SeasonMedia(videos: videos, images: images, onRetry: onRetry),
      ],
    );
  }
}

class _SeasonMetadataPill extends StatelessWidget {
  const _SeasonMetadataPill({required this.icon, required this.label});

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

/// A single episode, rendered as a flat list row.
///
/// Deliberately carries no card chrome — no fill, no border, no shadow, no
/// outer radius. The still is the only rounded element; rows are separated by
/// an [_EpisodeDivider] hairline so a long season reads as one continuous list
/// instead of a stack of floating panels.
class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.episodes,
    required this.tvId,
    required this.seriesName,
    required this.posterPath,
    this.numberSlot = 18,
  });

  final EpisodeList episode;
  final List<EpisodeList> episodes;
  final int tvId;
  final String? seriesName;
  final String? posterPath;
  final double numberSlot;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    final date = DateTime.tryParse(episode.airDate ?? '');
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rating = episode.voteAverage ?? 0;
    final metaStyle = theme.textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final thumbWidth = isWide
            ? (constraints.maxWidth * .26).clamp(210.0, 272.0)
            : (constraints.maxWidth * .38).clamp(128.0, 176.0);

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EpisodeDetailPage(
                episodeList: episode,
                episodes: episodes,
                tvId: tvId,
                seriesName: seriesName,
                posterPath: posterPath,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: isWide ? 16 : 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: thumbWidth,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppUI.cardRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if ((episode.stillPath ?? '').isEmpty)
                            Image.asset(
                              'assets/images/na_rect.png',
                              fit: BoxFit.cover,
                            )
                          else
                            CachedNetworkImage(
                              cacheManager: cacheProp(),
                              imageUrl:
                                  '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxy, settings.enableProxy, context)}${settings.imageQuality}${episode.stillPath}',
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  const AppShimmerBlock(radius: 7),
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/images/na_rect.png',
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
                                  Color(0x4D000000),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: isWide ? 38 : 32,
                              height: isWide ? 38 : 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .42),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .55),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                PhosphorIcons.play(PhosphorIconsStyle.fill),
                                color: Colors.white,
                                size: isWide ? 17 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isWide ? 18 : 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: numberSlot,
                            child: Text(
                              episode.episodeNumber?.toString() ?? '',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: 'FigtreeSB',
                                height: 1.16,
                                color: colors.onSurfaceVariant
                                    .withValues(alpha: .55),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              episode.name ?? tr('episodes'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: 'FigtreeSB',
                                height: 1.16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rating > 0 || date != null) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            if (rating > 0) ...[
                              Icon(
                                PhosphorIcons.star(PhosphorIconsStyle.fill),
                                size: 13,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(rating.toStringAsFixed(1), style: metaStyle),
                            ],
                            if (rating > 0 && date != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 7),
                                child: Text('·', style: metaStyle),
                              ),
                            if (date != null)
                              Flexible(
                                child: Text(
                                  DateFormat.yMMMd(context.locale.toString())
                                      .format(date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaStyle,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if ((episode.overview ?? '').isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          episode.overview!,
                          maxLines: isWide ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EpisodeDivider extends StatelessWidget {
  const _EpisodeDivider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45),
      );
}

class _SeasonCastRail extends StatelessWidget {
  const _SeasonCastRail({
    required this.credits,
    required this.onRetry,
    required this.tvId,
    required this.seasonNumber,
  });

  final Future<Credits> credits;
  final VoidCallback onRetry;
  final int tvId;
  final int seasonNumber;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Credits>(
      future: credits,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SeasonHeading(title: tr('cast')),
              const SizedBox(height: 14),
              const _SeasonCastShimmer(),
            ],
          );
        }
        if (snapshot.hasError) return _SeasonError(onRetry: onRetry);
        final cast = snapshot.data?.cast ?? const <Cast>[];
        if (cast.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SeasonHeading(
              title: tr('cast'),
              actionLabel: tr('see_all_cast_crew'),
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TVSeasonCastAndCrew(
                    id: tvId,
                    seasonNumber: seasonNumber,
                    passedFrom: 'season_detail',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 126,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cast.take(16).length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = cast[index];
                  final settings = Provider.of<SettingsProvider>(context);
                  final proxy =
                      Provider.of<AppDependencyProvider>(context).tmdbProxy;
                  return SizedBox(
                    width: 82,
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: 68,
                          child: ClipOval(
                            child: (item.profilePath ?? '').isEmpty
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
                                        item.profilePath!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) =>
                                        const AppShimmerBlock(radius: 40),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeasonMedia extends StatelessWidget {
  const _SeasonMedia({
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
        FutureBuilder<Videos>(
          future: videos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SeasonVideoShimmer();
            }
            if (snapshot.hasError) return _SeasonError(onRetry: onRetry);
            final items = snapshot.data?.result ?? const <Results>[];
            if (items.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SeasonHeading(title: tr('videos')),
                const SizedBox(height: 14),
                SizedBox(
                  height: 218,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final video = items[index];
                      return SizedBox(
                        width:
                            MediaQuery.sizeOf(context).width >= 700 ? 310 : 272,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppUI.cardRadius),
                          onTap: () => launchUrl(
                            Uri.parse('$YOUTUBE_BASE_URL${video.videoLink}'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppUI.cardRadius),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        cacheManager: cacheProp(),
                                        imageUrl:
                                            '$YOUTUBE_THUMBNAIL_URL${video.videoLink}/hqdefault.jpg',
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            const AppShimmerBlock(),
                                        errorWidget: (_, __, ___) =>
                                            Image.asset(
                                          'assets/images/na_rect.png',
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
                                              Color(0x68000000),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            shape: BoxShape.circle,
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            PhosphorIcons.play(),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                            size: 31,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                video.name ?? tr('videos'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
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
          },
        ),
        FutureBuilder<Images>(
          future: images,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SeasonImageShimmer();
            }
            if (snapshot.hasError) return _SeasonError(onRetry: onRetry);
            if (!snapshot.hasData) return const SizedBox.shrink();
            final items = <({String path, bool poster})>[
              ...?snapshot.data?.backdrop
                  ?.map((item) => item.filePath)
                  .whereType<String>()
                  .map((path) => (path: path, poster: false)),
              ...?snapshot.data?.poster
                  ?.map((item) => item.posterPath)
                  .whereType<String>()
                  .map((path) => (path: path, poster: true)),
            ];
            if (items.isEmpty) return const SizedBox.shrink();
            final settings = Provider.of<SettingsProvider>(context);
            final proxy = Provider.of<AppDependencyProvider>(context).tmdbProxy;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                _SeasonHeading(title: tr('images')),
                const SizedBox(height: 14),
                SizedBox(
                  height: 224,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.take(16).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(AppUI.cardRadius),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              cacheManager: cacheProp(),
                              width: item.poster ? 148 : 310,
                              height: 224,
                              imageUrl: buildImageUrl(
                                    TMDB_BASE_IMAGE_URL,
                                    proxy,
                                    settings.enableProxy,
                                    context,
                                  ) +
                                  settings.imageQuality +
                                  item.path,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const AppShimmerBlock(),
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/images/na_rect.png',
                                width: item.poster ? 148 : 310,
                                fit: BoxFit.cover,
                              ),
                            ),
                            PositionedDirectional(
                              start: 10,
                              bottom: 9,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .58),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      PhosphorIcons.image(),
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${index + 1} / ${items.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'FigtreeSB',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SeasonVideoShimmer extends StatelessWidget {
  const _SeasonVideoShimmer();

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.sizeOf(context).width >= 700 ? 310.0 : 272.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeasonHeading(title: tr('videos')),
        const SizedBox(height: 14),
        SizedBox(
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => SizedBox(
              width: cardWidth,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: AppShimmerBlock()),
                  SizedBox(height: 9),
                  SizedBox(
                    width: 210,
                    height: 16,
                    child: AppShimmerBlock(radius: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonImageShimmer extends StatelessWidget {
  const _SeasonImageShimmer();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          _SeasonHeading(title: tr('images')),
          const SizedBox(height: 14),
          SizedBox(
            height: 224,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => SizedBox(
                width: index.isEven ? 148 : 310,
                child: const AppShimmerBlock(),
              ),
            ),
          ),
        ],
      );
}

class _SeasonHeading extends StatelessWidget {
  const _SeasonHeading({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'FigtreeSB',
                  ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          if (trailing != null) trailing!,
        ],
      );
}

class _SeasonError extends StatelessWidget {
  const _SeasonError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .errorContainer
              .withValues(alpha: .4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.cloudSlash()),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('check_connection'))),
            TextButton(onPressed: onRetry, child: Text(tr('retry'))),
          ],
        ),
      );
}

class _SeasonCastShimmer extends StatelessWidget {
  const _SeasonCastShimmer();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 126,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, __) => const SizedBox(
            width: 82,
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 68,
                  child: AppShimmerBlock(radius: 40),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 72,
                  height: 13,
                  child: AppShimmerBlock(radius: 4),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EpisodeListShimmer extends StatelessWidget {
  const _EpisodeListShimmer({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < itemCount; index++) ...[
          const _EpisodeRowShimmer(),
          if (index != itemCount - 1) const _EpisodeDivider(),
        ],
      ],
    );
  }
}

class _EpisodeRowShimmer extends StatelessWidget {
  const _EpisodeRowShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final thumbWidth = isWide
            ? (constraints.maxWidth * .26).clamp(210.0, 272.0)
            : (constraints.maxWidth * .38).clamp(128.0, 176.0);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isWide ? 16 : 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: thumbWidth,
                child: const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AppShimmerBlock(radius: 7),
                ),
              ),
              SizedBox(width: isWide ? 18 : 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FractionallySizedBox(
                      widthFactor: .74,
                      child: SizedBox(
                        height: 16,
                        child: AppShimmerBlock(radius: 5),
                      ),
                    ),
                    SizedBox(height: 11),
                    Row(
                      children: [
                        SizedBox(
                          width: 46,
                          height: 12,
                          child: AppShimmerBlock(radius: 4),
                        ),
                        SizedBox(width: 11),
                        SizedBox(
                          width: 86,
                          height: 12,
                          child: AppShimmerBlock(radius: 4),
                        ),
                      ],
                    ),
                    SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      height: 11,
                      child: AppShimmerBlock(radius: 4),
                    ),
                    SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: .62,
                      child: SizedBox(
                        height: 11,
                        child: AppShimmerBlock(radius: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TVSeasonDetailQuickInfo extends StatelessWidget {
  const TVSeasonDetailQuickInfo({
    super.key,
    required this.tvSeries,
    required this.heroId,
    required this.season,
  });

  final TVDetails tvSeries;
  final Seasons season;
  final String heroId;

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
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
                                child: TopButton(
                                  buttonText: tr('open_show'),
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
                child: Row(children: [
                  // poster
                  Hero(
                    tag: heroId,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppUI.cardRadius),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppUI.cardRadius),
                            child: SizedBox(
                              width: 94,
                              height: 140,
                              child: season.posterPath == null
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
                                          season.posterPath!,
                                    ),
                            ),
                          ),
                        )),
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                season.airDate == null || season.airDate == ''
                                    ? season.name!
                                    : '${season.name!} (${DateTime.parse(season.airDate!).year})',
                                style: kTextSmallHeaderStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 15.0),
                                child: Column(
                                  children: [
                                    Text(
                                      tvSeries.originalTitle!,
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

class TVSeasonAbout extends StatefulWidget {
  const TVSeasonAbout({
    super.key,
    required this.season,
    required this.tvDetails,
    required this.seriesName,
  });

  final Seasons season;
  final TVDetails tvDetails;
  final String? seriesName;

  @override
  State<TVSeasonAbout> createState() => _TVSeasonAboutState();
}

class _TVSeasonAboutState extends State<TVSeasonAbout> {
  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<SettingsProvider>(context).appLanguage;
    return SingleChildScrollView(
      child: Container(
        decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0))),
        child: Column(
          children: [
            const SizedBox(
              height: 5,
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 3),
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
                widget.season.overview!.isEmpty
                    ? tr('no_season_overview')
                    : widget.season.overview!,
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
                      widget.season.airDate == null
                          ? tr('no_first_episode_air_date')
                          : tr('first_episode_air_date', namedArgs: {
                              'day': DateTime.parse(widget.season.airDate!)
                                  .day
                                  .toString(),
                              'date': DateFormat('MMMM').format(
                                  DateTime.parse(widget.season.airDate!)),
                              'year': DateTime.parse(widget.season.airDate!)
                                  .year
                                  .toString()
                            }),
                      style: const TextStyle(
                        fontFamily: 'FigtreeSB',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ScrollingTVArtists(
              id: widget.tvDetails.id!,
              seasonNumber: widget.season.seasonNumber,
              passedFrom: 'seasons_detail',
              api: Endpoints.getTVSeasonCreditsUrl(
                  widget.tvDetails.id!, widget.season.seasonNumber!, lang),
              title: 'Cast',
            ),
            EpisodeListWidget(
              seriesName: widget.seriesName,
              tvId: widget.tvDetails.id,
              api: Endpoints.getSeasonDetails(
                  widget.tvDetails.id!, widget.season.seasonNumber!, lang),
              posterPath: widget.season.posterPath,
            ),
            TVSeasonImagesDisplay(
              title: tr('images'),
              name: '${widget.seriesName}_season_${widget.season.seasonNumber}',
              api: Endpoints.getTVSeasonImagesUrl(
                  widget.tvDetails.id!, widget.season.seasonNumber!),
            ),
            // TVVideosDisplay(
            //   api: Endpoints.getTVSeasonVideosUrl(
            //       widget.tvDetails.id!, widget.season.seasonNumber!),
            //   title: 'Videos',
            // ),

            // TVCastTab(
            //   api: Endpoints.getFullTVSeasonCreditsUrl(
            //       widget.tvDetails.id!, widget.season.seasonNumber!),
            // ),
            // TVCrewTab(
            //   api: Endpoints.getFullTVSeasonCreditsUrl(
            //       widget.tvDetails.id!, widget.season.seasonNumber!),
            // ),
          ],
        ),
      ),
    );
  }
}
