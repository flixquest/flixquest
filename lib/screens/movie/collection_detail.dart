import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../api/endpoints.dart';
import '../../catalog/details_controller.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../functions/network.dart';
import '../../mobile/playback.dart';
import '../../mobile/screens/home_screen.dart' show HomeAdSlot;
import '../../mobile/widgets/details_header.dart';
import '../../mobile/widgets/details_parts.dart';
import '../../mobile/widgets/media_art.dart';
import '../../mobile/widgets/poster_card.dart';
import '../../models/movie.dart';
import '../../models/recently_watched.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../widgets/hosted_ads_banner.dart' show HostedBannerVariant;

/// A movie collection's page: its backdrop, its name and how many films it
/// holds over which years, Play for the next one in order, the synopsis,
/// then every film in release order.
class CollectionDetailsWidget extends StatefulWidget {
  const CollectionDetailsWidget({
    super.key,
    this.belongsToCollection,
  });

  final BelongsToCollection? belongsToCollection;

  @override
  CollectionDetailsWidgetState createState() => CollectionDetailsWidgetState();
}

class CollectionDetailsWidgetState extends State<CollectionDetailsWidget>
    with CollapsingHeader<CollectionDetailsWidget> {
  late Future<CollectionDetails> _details;
  late Future<List<Movie>> _parts;
  bool _started = false;
  bool _overviewOpen = false;

  BelongsToCollection get _collection => widget.belongsToCollection!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  void _load() {
    final settings = context.read<SettingsProvider>();
    final proxy = context.read<AppDependencyProvider>().tmdbProxy;
    final api =
        Endpoints.getCollectionDetails(_collection.id!, settings.appLanguage);
    _details = fetchCollectionDetails(api, settings.enableProxy, proxy)
      ..ignore();
    _parts = fetchCollectionMovies(api, settings.enableProxy, proxy).then(
      (movies) => List<Movie>.of(movies)
        ..sort(
          (a, b) =>
              (a.releaseDate?.isNotEmpty == true ? a.releaseDate! : '9999')
                  .compareTo(
            b.releaseDate?.isNotEmpty == true ? b.releaseDate! : '9999',
          ),
        ),
    )..ignore();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final name = _collection.name ?? '';
    final width = MediaQuery.sizeOf(context).width;
    final backdrop = tmdbImageUrl(
      context,
      _collection.backdropPath ?? _collection.posterPath,
      size: ArtSize.backdrop,
    );
    return Scaffold(
      backgroundColor: palette.page,
      body: CustomScrollView(
        controller: scroll,
        slivers: [
          DetailsSliverHeader(
            title: name,
            collapsed: collapsed,
            artwork: backdrop == null
                ? const ArtPlaceholder()
                : CachedNetworkImage(
                    imageUrl: backdrop,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    memCacheWidth:
                        (width * MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    placeholder: (_, __) =>
                        ColoredBox(color: palette.raisedSurface),
                    errorWidget: (_, __, ___) => const ArtPlaceholder(),
                  ),
          ),
          SliverToBoxAdapter(child: _summary(context, name)),
          SliverToBoxAdapter(
            child: HomeAdSlot(
              placement: 'collection_detail',
              variant: HostedBannerVariant.tall,
            ),
          ),
          SliverToBoxAdapter(child: _films(context)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, String name) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('collection').toUpperCase(),
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            name,
            style: AppType.scaled(context, AppType.pageTitle)
                .copyWith(color: palette.foreground),
          ),
          const SizedBox(height: AppSpace.sm),
          FutureBuilder<List<Movie>>(
            future: _parts,
            builder: (context, snapshot) {
              final movies = snapshot.data;
              if (movies == null) {
                return const SkeletonBlock.line(width: 140);
              }
              final years = movies
                  .map((movie) => DateTime.tryParse(movie.releaseDate ?? ''))
                  .whereType<DateTime>()
                  .map((date) => date.year)
                  .toList();
              return FactsLine(
                facts: [
                  plural('movie_count', movies.length),
                  if (years.isNotEmpty)
                    years.first == years.last
                        ? '${years.first}'
                        : '${years.first}–${years.last}',
                ],
              );
            },
          ),
          const SizedBox(height: AppSpace.lg),
          _playButton(context),
          const SizedBox(height: AppSpace.lg),
          FutureBuilder<CollectionDetails>(
            future: _details,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SkeletonPulse(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock.line(height: 13),
                      SizedBox(height: AppSpace.sm),
                      SkeletonBlock.line(height: 13),
                      SizedBox(height: AppSpace.sm),
                      FractionallySizedBox(
                        widthFactor: .6,
                        child: SkeletonBlock.line(height: 13),
                      ),
                    ],
                  ),
                );
              }
              final overview = snapshot.data?.overview?.trim() ?? '';
              if (overview.isEmpty) return const SizedBox.shrink();
              return Semantics(
                button: true,
                onTapHint: _overviewOpen ? tr('read_less') : tr('read_more'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _overviewOpen = !_overviewOpen),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: AlignmentDirectional.topStart,
                    child: Text(
                      overview,
                      maxLines: _overviewOpen ? null : 3,
                      overflow: _overviewOpen ? null : TextOverflow.ellipsis,
                      style:
                          AppType.body.copyWith(color: palette.secondaryText),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Play the film the viewer is part way through, else the first they
  /// haven't finished, in release order.
  Widget _playButton(BuildContext context) {
    if (!MobilePlayback.canPlay(context)) return const SizedBox.shrink();
    final watched =
        context.watch<RecentProvider?>()?.movies ?? const <RecentMovie>[];
    return FutureBuilder<List<Movie>>(
      future: _parts,
      builder: (context, snapshot) {
        final movies = (snapshot.data ?? const <Movie>[])
            .where(
                (movie) => DateTime.tryParse(movie.releaseDate ?? '') != null)
            .toList();
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonBlock(height: 48, radius: AppRadii.button);
        }
        if (movies.isEmpty) return const SizedBox.shrink();
        final items = movies.map(MediaItem.fromMovie).toList();
        ResumePoint? resumeOf(MediaItem item) => ResumePoint.forItem(
              item,
              movies: watched,
              episodes: const <RecentEpisode>[],
            );
        bool finished(MediaItem item) => watched.any(
              (movie) =>
                  movie.id == item.id &&
                  (movie.remaining ?? 0) <=
                      ResumePoint.finishedWithin.inSeconds,
            );
        final resuming = items.where((item) => resumeOf(item) != null);
        final next = resuming.isNotEmpty
            ? resuming.first
            : items.firstWhere(
                (item) => !finished(item),
                orElse: () => items.first,
              );
        final resume = resumeOf(next);
        return DetailsPlayButton(
          label: '${resume == null ? tr('play') : tr('resume_title')} · '
              '${next.title}',
          resume: resume,
          busy: false,
          onPressed: () => MobilePlayback.play(context, next),
        );
      },
    );
  }

  Widget _films(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsetsDirectional.fromSTEB(gutter, AppSpace.sm, gutter, 0),
          child: Text(
            tr('movies'),
            style: AppType.scaled(context, AppType.sectionHeader)
                .copyWith(color: palette.foreground),
          ),
        ),
        FutureBuilder<List<Movie>>(
          future: _parts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _FilmsSkeleton();
            }
            if (snapshot.hasError) {
              return Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
                child: DetailsMessage(
                  message: tr('check_connection'),
                  onRetry: () => setState(_load),
                ),
              );
            }
            final movies = snapshot.data ?? const <Movie>[];
            if (movies.isEmpty) {
              return Padding(
                padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
                child: DetailsMessage(message: tr('nothing_here_yet')),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < movies.length; i++)
                  _FilmRow(number: i + 1, movie: movies[i]),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One film of the collection: its poster, its place in the order and
/// title, its year and rating, and the start of its synopsis.
class _FilmRow extends StatelessWidget {
  const _FilmRow({required this.number, required this.movie});

  final int number;
  final Movie movie;

  static const _poster = 76.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final item = MediaItem.fromMovie(movie);
    final year = DateTime.tryParse(movie.releaseDate ?? '')?.year;
    final overview = movie.overview?.trim() ?? '';
    return InkWell(
      onTap: () => MobilePlayback.openDetails(context, item),
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: gutter, vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: SizedBox(
                width: _poster,
                height: _poster / PosterCard.aspectRatio,
                child: MediaArt(
                  item: item,
                  path: movie.posterPath,
                  width: _poster,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number. ${item.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.cardTitle.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  FactsLine(
                    facts: [if (year != null) '$year'],
                    rating: (movie.voteAverage ?? 0).toDouble(),
                  ),
                  if (overview.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      overview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppType.body.copyWith(color: palette.secondaryText),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpace.sm),
              child: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? PhosphorIcons.caretLeft()
                    : PhosphorIcons.caretRight(),
                size: 16,
                color: palette.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilmsSkeleton extends StatelessWidget {
  const _FilmsSkeleton();

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SkeletonPulse(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: gutter,
                vertical: AppSpace.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBlock(
                    width: _FilmRow._poster,
                    height: _FilmRow._poster / PosterCard.aspectRatio,
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: i.isEven ? .7 : .55,
                          child: const SkeletonBlock.line(height: 14),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        const SkeletonBlock.line(width: 80, height: 11),
                        const SizedBox(height: AppSpace.md),
                        const SkeletonBlock.line(height: 11),
                        const SizedBox(height: 6),
                        const FractionallySizedBox(
                          widthFactor: .8,
                          child: SkeletonBlock.line(height: 11),
                        ),
                      ],
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
