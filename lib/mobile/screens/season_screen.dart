import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/details_play.dart';
import '../../catalog/media_item.dart';
import '../../catalog/season_source.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../models/credits.dart';
import '../../models/genres.dart';
import '../../models/images.dart';
import '../../models/tv.dart';
import '../../models/videos.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/photoview.dart';
import '../../services/ambient_theme_service.dart';
import '../episode_playback.dart';
import '../widgets/details_header.dart';
import '../widgets/details_parts.dart';
import '../widgets/episode_row.dart';
import '../widgets/media_art.dart';
import '../widgets/section_header.dart';
import 'credits_screen.dart';
import 'episode_screen.dart';
import 'home_screen.dart' show HomeAdSlot;

/// A season's page: the series' artwork, the season's name (tapped, the
/// other seasons), what to play, its synopsis, then its episodes, cast,
/// videos and posters. Episodes play and look as they do on the series'
/// page.
class SeasonScreen extends StatefulWidget {
  const SeasonScreen({
    required this.series,
    required this.seasons,
    required this.seasonNumber,
    this.source,
    this.history,
    this.adBuilder,
    this.now,
    super.key,
  });

  final MediaItem series;

  /// The series' seasons in the order offered (specials last), to switch
  /// between.
  final List<Seasons> seasons;
  final int seasonNumber;

  /// Where the page's parts come from; TMDB by default.
  final SeasonSource? source;

  /// What the viewer has watched; the recently watched store by default.
  final WatchHistory? history;
  final WidgetBuilder? adBuilder;
  final DateTime Function()? now;

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen>
    with CollapsingHeader<SeasonScreen> {
  late SeasonSource _source;
  late int _season = widget.seasonNumber;
  late Future<TVDetails> _series;
  late Future<List<Genres>> _genres;
  late Future<Credits> _credits;
  late Future<Videos> _videos;
  late Future<Images> _images;
  final Map<int, Future<List<EpisodeList>>> _episodes =
      <int, Future<List<EpisodeList>>>{};
  final AmbientThemeScopeController _ambient = AmbientThemeScopeController();
  bool _started = false;
  bool _starting = false;
  bool _overviewOpen = false;

  int get _seriesId => widget.series.id;

  Seasons get _current => widget.seasons.firstWhere(
        (season) => season.seasonNumber == _season,
        orElse: () => Seasons(seasonNumber: _season),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _source = widget.source ??
        TmdbSeasonSource(
          settings: context.read<SettingsProvider>(),
          dependencies: context.read<AppDependencyProvider>(),
        );
    _series = _source.series(_seriesId)..ignore();
    _genres = _source.genres(_seriesId)..ignore();
    _loadSeason();
    _ambient.attach(context, widget.series.posterPath);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  void _loadSeason() {
    _credits = _source.seasonCredits(_seriesId, _season)..ignore();
    _videos = _source.seasonVideos(_seriesId, _season)..ignore();
    _images = _source.seasonImages(_seriesId, _season)..ignore();
    context.read<SettingsProvider>().analytics.trackSeasonDetailView(
          tvName: widget.series.title,
          seasonNumber: _season,
        );
  }

  /// A season's episodes, fetched once; a failure is forgotten so Retry
  /// asks again.
  Future<List<EpisodeList>> _seasonEpisodes(int season) {
    final cached = _episodes[season];
    if (cached != null) return cached;
    final load = _source.episodes(_seriesId, season);
    _episodes[season] = load;
    load.then<void>((_) {}, onError: (Object _) => _episodes.remove(season));
    return load;
  }

  Future<void> _pickSeason() async {
    final picked = await showSeasonSheet(
      context,
      seasons: widget.seasons,
      current: _season,
    );
    if (picked == null || picked == _season || !mounted) return;
    setState(() {
      _season = picked;
      _overviewOpen = false;
      _loadSeason();
    });
  }

  WatchHistory _history(BuildContext context) {
    final given = widget.history;
    if (given != null) return given;
    final recent = context.watch<RecentProvider?>();
    if (recent == null) return const WatchHistory();
    return WatchHistory(
      movies: recent.movies,
      episodes: recent.episodes,
      upNext: recent.upNext,
    );
  }

  Future<InsightsMetadata> _insights() async {
    Future<T?> quietly<T>(Future<T> future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final genres = await quietly(_genres) ?? const <Genres>[];
    return insightsMetadata(
      genres: genres.map((genre) => genre.genreName ?? '').toList(),
      series: await quietly(_series),
      originalLanguage: widget.series.series?.originalLanguage,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _play(
    EpisodeList episode,
    List<EpisodeList> seasonEpisodes, {
    bool download = false,
  }) async {
    final insights = await _insights();
    if (!mounted) return;
    await playEpisode(
      context,
      series: widget.series,
      episode: episode,
      seasonEpisodes: seasonEpisodes,
      allSeasons: widget.seasons,
      insights: insights,
      download: download,
    );
  }

  void _openEpisode(EpisodeList episode, List<EpisodeList> seasonEpisodes) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeScreen(
          series: widget.series,
          episode: episode,
          seasonEpisodes: seasonEpisodes,
          seasons: widget.seasons,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final history = _history(context);
    final current = _current;
    return Scaffold(
      backgroundColor: palette.page,
      body: CustomScrollView(
        controller: scroll,
        slivers: <Widget>[
          DetailsSliverHeader(
            title: seasonDisplayName(current),
            collapsed: collapsed,
            artwork: MediaArt(
              item: widget.series,
              path: widget.series.backdropPath ?? current.posterPath,
              width: MediaQuery.sizeOf(context).width,
              size: ArtSize.backdrop,
              alignment: Alignment.topCenter,
            ),
          ),
          SliverToBoxAdapter(child: _summary(context, current, history)),
          SliverToBoxAdapter(
            child: widget.adBuilder?.call(context) ??
                HomeAdSlot(placement: 'season_detail'),
          ),
          SliverToBoxAdapter(child: _episodeList(context, history)),
          SliverToBoxAdapter(child: _cast(context)),
          SliverToBoxAdapter(child: _videoList(context)),
          SliverToBoxAdapter(child: _posters(context)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, Seasons season, WatchHistory history) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final year = DateTime.tryParse(season.airDate ?? '')?.year;
    final count = season.episodeCount;
    final overview = season.overview?.trim() ?? '';
    final switchable = widget.seasons.length > 1;
    final title = Text(
      seasonDisplayName(season),
      style: AppType.scaled(context, AppType.pageTitle)
          .copyWith(color: palette.foreground),
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.series.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.kicker.copyWith(color: palette.mutedText),
          ),
          const SizedBox(height: AppSpace.xs),
          if (!switchable)
            title
          else
            Semantics(
              button: true,
              hint: tr('choose_season'),
              child: InkWell(
                onTap: _pickSeason,
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: title),
                    const SizedBox(width: AppSpace.sm),
                    Icon(
                      PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                      size: 20,
                      color: palette.foreground,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpace.sm),
          FactsLine(
            facts: <String>[
              if (year != null) '$year',
              if (count != null && count > 0)
                tr(
                  'episodes_count',
                  namedArgs: <String, String>{'count': '$count'},
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          _playButton(context, history),
          if (overview.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpace.lg),
            Semantics(
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
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playButton(BuildContext context, WatchHistory history) {
    final dependencies = context.watch<AppDependencyProvider?>();
    if (!(dependencies?.displayWatchNowButton ?? true)) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<List<EpisodeList>>(
      future: _seasonEpisodes(_season),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SkeletonBlock(height: 48, radius: AppRadii.button);
        }
        final episodes = snapshot.data ?? const <EpisodeList>[];
        final plan = seasonPlayFor(
          episodes,
          history,
          seriesId: _seriesId,
          now: widget.now?.call(),
        );
        if (plan == null) return const SizedBox.shrink();
        final label = <String, String>{'episode': plan.label};
        return DetailsPlayButton(
          label: plan.resuming
              ? tr('resume_episode', namedArgs: label)
              : tr('play_episode', namedArgs: label),
          resume: plan.resume,
          busy: _starting,
          onPressed: () => _run(() => _play(plan.episode, episodes)),
        );
      },
    );
  }

  Widget _episodeList(BuildContext context, WatchHistory history) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final dependencies = context.watch<AppDependencyProvider?>();
    final season = _season;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 0),
            child: Text(
              tr('episodes'),
              style: AppType.scaled(context, AppType.sectionHeader)
                  .copyWith(color: palette.foreground),
            ),
          ),
          FutureBuilder<List<EpisodeList>>(
            key: ValueKey<int>(season),
            future: _seasonEpisodes(season),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const EpisodeListSkeleton(count: 4);
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
                  child: DetailsMessage(
                    message: tr('episodes_load_failed'),
                    onRetry: () => setState(() {}),
                  ),
                );
              }
              final episodes = snapshot.data ?? const <EpisodeList>[];
              if (episodes.isEmpty) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
                  child: DetailsMessage(message: tr('nothing_here_yet')),
                );
              }
              final now = widget.now?.call() ?? DateTime.now();
              return Column(
                children: <Widget>[
                  for (final episode in episodes)
                    EpisodeRow(
                      series: widget.series,
                      episode: episode,
                      aired: hasAired(episode, now: now),
                      progress: episodeProgress(
                        history.episodes,
                        seriesId: _seriesId,
                        season: episode.seasonNumber ?? season,
                        episode: episode.episodeNumber ?? -1,
                      ),
                      canPlay: dependencies?.displayWatchNowButton ?? true,
                      canDownload: dependencies?.displayDownloadButton ?? false,
                      onPlay: () => _run(() => _play(episode, episodes)),
                      onDownload: () => _run(
                        () => _play(episode, episodes, download: true),
                      ),
                      onOpen: () => _openEpisode(episode, episodes),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cast(BuildContext context) => FutureBuilder<Credits>(
        future: _credits,
        builder: (context, snapshot) {
          final credits = snapshot.data;
          final cast = credits?.cast ?? const <Cast>[];
          if (snapshot.connectionState != ConnectionState.done) {
            return const CastRowSkeleton();
          }
          if (cast.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: tr('cast'),
                  onSeeAll: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CreditsScreen(
                        title: seasonDisplayName(_current),
                        kicker: widget.series.title,
                        credits: _credits,
                      ),
                    ),
                  ),
                ),
                CastRow(cast: cast),
              ],
            ),
          );
        },
      );

  Widget _videoList(BuildContext context) => FutureBuilder<Videos>(
        future: _videos,
        builder: (context, snapshot) {
          final videos = (snapshot.data?.result ?? const <Results>[])
              .where((video) => (video.videoLink ?? '').isNotEmpty)
              .toList(growable: false);
          if (videos.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: tr('videos')),
                VideoRow(videos: videos),
              ],
            ),
          );
        },
      );

  Widget _posters(BuildContext context) => FutureBuilder<Images>(
        future: _images,
        builder: (context, snapshot) {
          final posters = (snapshot.data?.poster ?? const <Posters>[])
              .where((poster) => poster.posterPath != null)
              .toList(growable: false);
          if (posters.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: tr('posters')),
                ImageRow(
                  paths: <String>[
                    for (final poster in posters) poster.posterPath!,
                  ],
                  aspectRatio: 2 / 3,
                  onOpen: (index) => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => HeroPhotoView(
                        imageType: 'poster',
                        posters: posters,
                        name: seasonDisplayName(_current),
                        initialIndex: index,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
