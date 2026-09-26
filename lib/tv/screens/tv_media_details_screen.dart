import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/tv.dart';
import '../../models/tv_stream_metadata.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/movie/movie_video_loader.dart';
import '../../screens/tv/tv_video_loader.dart';
import '../../ui_components/app_ui_components.dart';
import '../app/tv_design.dart';
import '../controllers/tv_media_details_controller.dart';
import '../focus/tv_focusable.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_content_row.dart';
import '../widgets/tv_dialog.dart';
import '../widgets/tv_media_card.dart';
import '../widgets/tv_state_panel.dart';

class TvMediaDetailsScreen extends StatefulWidget {
  const TvMediaDetailsScreen({required this.item, super.key});

  final TvMediaItem item;

  @override
  State<TvMediaDetailsScreen> createState() => _TvMediaDetailsScreenState();
}

class _TvMediaDetailsScreenState extends State<TvMediaDetailsScreen> {
  static const _controller = TvMediaDetailsController();
  Future<TvMediaDetailsData>? _details;
  Future<bool>? _bookmarked;
  Future<List<EpisodeList>>? _episodes;
  int? _selectedSeason;
  String? _configurationKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final dependencies = context.watch<AppDependencyProvider>();
    final key = '${settings.appLanguage}|${settings.enableProxy}|'
        '${dependencies.tmdbProxy}|${widget.item.stableId}';
    if (_configurationKey != key) {
      _configurationKey = key;
      _details = _controller.load(
        item: widget.item,
        settings: settings,
        dependencies: dependencies,
      );
      _bookmarked = _controller.isBookmarked(widget.item);
    }
  }

  void _retry() {
    setState(() {
      _details = _controller.load(
        item: widget.item,
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );
    });
  }

  void _selectSeason(int seasonNumber) {
    setState(() {
      _selectedSeason = seasonNumber;
      _episodes = _controller.loadSeason(
        seriesId: widget.item.id,
        seasonNumber: seasonNumber,
        settings: context.read<SettingsProvider>(),
        dependencies: context.read<AppDependencyProvider>(),
      );
    });
  }

  Future<void> _toggleBookmark(bool current) async {
    final updated = await _controller.toggleBookmark(widget.item, current);
    if (mounted) {
      setState(() => _bookmarked = Future<bool>.value(updated));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated ? 'Added to My List' : 'Removed from My List'),
        ),
      );
    }
  }

  void _restoreFocusAfterRoute(FocusNode? previousFocus) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          previousFocus == null ||
          previousFocus.context == null ||
          !previousFocus.canRequestFocus) {
        return;
      }
      previousFocus.requestFocus();
    });
  }

  Future<void> _openRecommendation(TvMediaItem item) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TvMediaDetailsScreen(item: item),
      ),
    );
    _restoreFocusAfterRoute(previousFocus);
  }

  Future<void> _playMovie() async {
    final movie = widget.item.movie;
    if (movie == null || movie.id == null) return;
    if (!await checkConnection()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your internet connection.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final previousFocus = FocusManager.instance.primaryFocus;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MovieVideoLoader(
          download: false,
          useTvPlayer: true,
          onTvPlayerExit: () => _restoreFocusAfterRoute(previousFocus),
          metadata: MovieStreamMetadata(
            backdropPath: movie.backdropPath,
            elapsed: null,
            movieId: movie.id,
            movieName: movie.title,
            posterPath: movie.posterPath,
            releaseYear: int.tryParse(widget.item.year ?? '') ?? 0,
            isAdult: movie.adult,
            releaseDate: movie.releaseDate,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: FutureBuilder<TvMediaDetailsData>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return SafeArea(child: TvStatePanel.error(onRetry: _retry));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final metrics = TvShellMetrics.fromConstraints(constraints);
              return _DetailsBody(
                data: snapshot.data!,
                metrics: metrics,
                bookmarked: _bookmarked!,
                selectedSeason: _selectedSeason,
                episodes: _episodes,
                onBack: () => Navigator.of(context).pop(),
                onToggleBookmark: _toggleBookmark,
                onSelectSeason: _selectSeason,
                onOpenRecommendation: _openRecommendation,
                onPlayMovie: _playMovie,
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.data,
    required this.metrics,
    required this.bookmarked,
    required this.selectedSeason,
    required this.episodes,
    required this.onBack,
    required this.onToggleBookmark,
    required this.onSelectSeason,
    required this.onOpenRecommendation,
    required this.onPlayMovie,
  });

  final TvMediaDetailsData data;
  final TvShellMetrics metrics;
  final Future<bool> bookmarked;
  final int? selectedSeason;
  final Future<List<EpisodeList>>? episodes;
  final VoidCallback onBack;
  final ValueChanged<bool> onToggleBookmark;
  final ValueChanged<int> onSelectSeason;
  final ValueChanged<TvMediaItem> onOpenRecommendation;
  final VoidCallback onPlayMovie;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final appDependency = context.watch<AppDependencyProvider>();
    final proxy = appDependency.tmdbProxy;
    final showPlay = data.item.kind == TvMediaKind.movie &&
        appDependency.displayWatchNowButton;
    final path = data.item.backdropPath ?? data.item.posterPath;
    final imageUrl = path == null
        ? null
        : '${buildImageUrl(
            TMDB_BASE_IMAGE_URL,
            proxy,
            settings.enableProxy,
            context,
          )}original/$path';
    final colors = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (imageUrl != null)
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: metrics.compact ? 340 : 520,
              width: double.infinity,
              child: CachedNetworkImage(
                cacheManager: cacheProp(),
                imageUrl: imageUrl,
                memCacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => const AppCachedImagePlaceholder(),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                const Color(0x36000000),
                Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.88),
                  TvDesign.surfaceFor(context),
                ),
                TvDesign.surfaceFor(context),
              ],
              stops: <double>[0, 0.52, 0.78],
            ),
          ),
        ),
        SafeArea(
          minimum: EdgeInsets.all(metrics.safeInset),
          child: SingleChildScrollView(
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.all(TvDesign.focusOutset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DetailAction(
                    label: 'Back',
                    icon: PhosphorIcons.caretLeft(),
                    onActivate: onBack,
                    autofocus: true,
                  ),
                ),
                SizedBox(height: metrics.compact ? 86 : 150),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        data.item.kind == TvMediaKind.movie
                            ? 'MOVIE'
                            : 'SERIES',
                        style: TextStyle(
                          color: colors.primary,
                          fontFamily: 'FigtreeSB',
                          fontSize: 16,
                          letterSpacing: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        data.item.title,
                        style: TextStyle(
                          color: TvDesign.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: metrics.compact ? 42 : 58,
                          height: 1.02,
                          letterSpacing: -0.8,
                        ),
                      ),
                      if (data.tagline case final tagline?
                          when tagline.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          tagline,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 20,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      if (data.facts.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 15),
                        Text(
                          data.facts,
                          style: TextStyle(
                            color: colors.primary,
                            fontFamily: 'FigtreeSB',
                            fontSize: 18,
                          ),
                        ),
                      ],
                      if (data.item.overview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          data.item.overview,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 20,
                            height: 1.42,
                          ),
                        ),
                      ],
                      const SizedBox(height: 23),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: <Widget>[
                          if (showPlay)
                            _DetailAction(
                              label: 'Play',
                              icon: PhosphorIcons.play(
                                PhosphorIconsStyle.fill,
                              ),
                              onActivate: onPlayMovie,
                              primary: true,
                            ),
                          FutureBuilder<bool>(
                            future: bookmarked,
                            builder: (context, snapshot) {
                              final saved = snapshot.data ?? false;
                              return _DetailAction(
                                label: saved
                                    ? 'Remove from My List'
                                    : 'Add to My List',
                                icon: saved
                                    ? PhosphorIcons.bookmarkSimple(
                                        PhosphorIconsStyle.fill,
                                      )
                                    : PhosphorIcons.bookmarkSimple(),
                                onActivate: () => onToggleBookmark(saved),
                                primary: !showPlay,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (data.seriesDetails?.seasons case final seasons?
                    when seasons.isNotEmpty) ...<Widget>[
                  SizedBox(height: metrics.compact ? 30 : 44),
                  _SeasonSection(
                    seasons: seasons,
                    selectedSeason: selectedSeason,
                    episodes: episodes,
                    onSelectSeason: onSelectSeason,
                    onOpenEpisode: (episode, seasonEpisodes) =>
                        _showEpisode(context, episode, seasonEpisodes),
                  ),
                ],
                if (data.recommendations.isNotEmpty) ...<Widget>[
                  SizedBox(height: metrics.compact ? 30 : 44),
                  TvContentRow<TvMediaItem>(
                    title: 'More like this',
                    scopeId: 'details-recommendations:${data.item.stableId}',
                    items:
                        data.recommendations.take(16).toList(growable: false),
                    itemId: (item) => item.stableId,
                    semanticLabel: (item) => item.title,
                    itemBuilder: (_, item) => TvMediaCard(
                      item: item,
                      width: metrics.mediaCardWidth,
                    ),
                    onItemActivated: onOpenRecommendation,
                  ),
                ],
                const SizedBox(height: TvDesign.focusOutset),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showEpisode(
    BuildContext context,
    EpisodeList episode,
    List<EpisodeList> seasonEpisodes,
  ) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    final canPlay = episode.episodeId != null &&
        context.read<AppDependencyProvider>().displayWatchNowButton;
    final facts = <String>[
      if (episode.seasonNumber != null && episode.episodeNumber != null)
        'S${episode.seasonNumber!.toString().padLeft(2, '0')}  •  '
            'E${episode.episodeNumber!.toString().padLeft(2, '0')}',
      if (episode.airDate?.trim().isNotEmpty ?? false) episode.airDate!,
      if (episode.voteAverage != null)
        '${episode.voteAverage!.toStringAsFixed(1)} / 10',
    ].join('  •  ');
    final playEpisode = await showTvDialog<bool>(
      context: context,
      title: episode.name ?? 'Episode information',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (facts.isNotEmpty) ...<Widget>[
            Text(facts),
            const SizedBox(height: 13),
          ],
          Text(
            episode.overview?.trim().isNotEmpty ?? false
                ? episode.overview!
                : 'No episode overview is available.',
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: <TvDialogAction>[
        if (canPlay)
          TvDialogAction(
            label: 'Play episode',
            autofocus: true,
            isPrimary: true,
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        TvDialogAction(
          label: 'Close',
          autofocus: !canPlay,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
    if (playEpisode == true && context.mounted) {
      await _playEpisode(
        context,
        episode,
        seasonEpisodes,
        returnFocus: previousFocus,
      );
    }
  }

  Future<void> _playEpisode(
    BuildContext context,
    EpisodeList episode,
    List<EpisodeList> seasonEpisodes, {
    FocusNode? returnFocus,
  }) async {
    if (!await checkConnection()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your internet connection.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TVVideoLoader(
          download: false,
          useTvPlayer: true,
          onTvPlayerExit: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (returnFocus?.context != null &&
                  returnFocus?.canRequestFocus == true) {
                returnFocus?.requestFocus();
              }
            });
          },
          metadata: TVStreamMetadata(
            elapsed: null,
            episodeId: episode.episodeId,
            episodeName: episode.name,
            episodeNumber: episode.episodeNumber,
            posterPath: data.item.posterPath,
            backdropPath: episode.stillPath ?? data.item.backdropPath,
            seasonNumber: episode.seasonNumber,
            seriesName: data.item.title,
            tvId: data.item.id,
            airDate: episode.airDate,
            seasonEpisodes: seasonEpisodes
                .where((item) => item.episodeId != null)
                .map(EpisodeMetadata.fromEpisodeList)
                .toList(growable: false),
            allSeasons: data.seriesDetails?.seasons
                ?.where((season) => season.seasonNumber != null)
                .map(SeasonMetadata.fromSeason)
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    required this.label,
    required this.icon,
    required this.onActivate,
    this.autofocus = false,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onActivate;
  final bool autofocus;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TvFocusable(
      semanticLabel: label,
      autofocus: autofocus,
      onActivate: onActivate,
      focusScale: 1.025,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          gradient: primary
              ? LinearGradient(
                  colors: <Color>[
                    colors.primary,
                    Color.lerp(
                      colors.primary,
                      colors.primaryContainer,
                      0.34,
                    )!,
                  ],
                )
              : null,
          color: primary ? null : TvDesign.raisedSurface,
          border: Border.all(
            color: primary
                ? colors.primary.withValues(alpha: 0.5)
                : colors.onSurface.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon,
                color: primary ? colors.onPrimary : colors.onSurface, size: 23),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: primary ? colors.onPrimary : colors.onSurface,
                fontFamily: 'FigtreeSB',
                fontSize: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonSection extends StatelessWidget {
  const _SeasonSection({
    required this.seasons,
    required this.selectedSeason,
    required this.episodes,
    required this.onSelectSeason,
    required this.onOpenEpisode,
  });

  final List<Seasons> seasons;
  final int? selectedSeason;
  final Future<List<EpisodeList>>? episodes;
  final ValueChanged<int> onSelectSeason;
  final void Function(EpisodeList episode, List<EpisodeList> seasonEpisodes)
      onOpenEpisode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final usableSeasons = seasons
        .where((season) => season.seasonNumber != null)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Seasons & episodes',
          style: TextStyle(
            color: colors.onSurface,
            fontFamily: 'FigtreeBold',
            fontSize: 26,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.all(TvDesign.focusOutset),
          child: Row(
            children: <Widget>[
              for (final season in usableSeasons) ...<Widget>[
                TvFocusable(
                  semanticLabel: season.name ?? 'Season ${season.seasonNumber}',
                  onActivate: () => onSelectSeason(season.seasonNumber!),
                  focusScale: 1.025,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: selectedSeason == season.seasonNumber
                          ? LinearGradient(
                              colors: <Color>[
                                colors.primary,
                                Color.lerp(
                                  colors.primary,
                                  colors.primaryContainer,
                                  0.3,
                                )!,
                              ],
                            )
                          : null,
                      color: selectedSeason == season.seasonNumber
                          ? null
                          : TvDesign.raisedSurface,
                      border: Border.all(
                        color: selectedSeason == season.seasonNumber
                            ? colors.primary.withValues(alpha: 0.5)
                            : colors.onSurface.withValues(alpha: 0.09),
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      season.name ?? 'Season ${season.seasonNumber}',
                      style: TextStyle(
                        color: selectedSeason == season.seasonNumber
                            ? colors.onPrimary
                            : colors.onSurface,
                        fontFamily: 'FigtreeSB',
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
              ],
            ],
          ),
        ),
        if (episodes != null) ...<Widget>[
          const SizedBox(height: 10),
          FutureBuilder<List<EpisodeList>>(
            future: episodes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Episodes could not be loaded.',
                  style: TextStyle(color: colors.error),
                );
              }
              final items = snapshot.data ?? const <EpisodeList>[];
              return Column(
                children: <Widget>[
                  for (final episode in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TvFocusable(
                        semanticLabel:
                            'Episode ${episode.episodeNumber ?? ''}, '
                            '${episode.name ?? 'Untitled episode'}',
                        onActivate: () => onOpenEpisode(episode, items),
                        focusScale: 1.01,
                        child: _EpisodeTile(episode: episode),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode});

  final EpisodeList episode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final number = episode.episodeNumber?.toString().padLeft(2, '0') ?? '--';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: TvDesign.surfaceFor(context, emphasis: 0.02),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.07),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'E$number',
            style: TextStyle(
              color: colors.primary,
              fontFamily: 'FigtreeSB',
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  episode.name ?? 'Untitled episode',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontFamily: 'FigtreeSB',
                    fontSize: 18,
                  ),
                ),
                if (episode.overview?.trim().isNotEmpty ?? false) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    episode.overview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
