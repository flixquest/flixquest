import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/photoview.dart';
import '../../services/ambient_theme_service.dart';
import '../../services/media_link.dart';
import '../episode_playback.dart';
import '../playback.dart';
import '../widgets/details_header.dart';
import '../widgets/details_parts.dart';
import '../widgets/episode_row.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart' show ReadableWidth;
import '../widgets/section_header.dart';
import 'credits_screen.dart';
import '../../widgets/hosted_ads_banner.dart' show HostedBannerVariant;
import 'home_screen.dart' show HomeAdSlot;

/// An episode's page: its still, its name and facts, Play (or Resume) and
/// Download, the synopsis and who made it, the rest of its season to move
/// between, its cast and its stills.
class EpisodeScreen extends StatefulWidget {
  const EpisodeScreen({
    required this.series,
    required this.episode,
    this.seasonEpisodes,
    this.seasons,
    this.source,
    this.history,
    this.adBuilder,
    this.now,
    super.key,
  });

  final MediaItem series;
  final EpisodeList episode;

  /// Its season's episodes, for the player and the row of the season;
  /// fetched when not given.
  final List<EpisodeList>? seasonEpisodes;

  /// The series' seasons, for the player; fetched when not given.
  final List<Seasons>? seasons;

  /// Where the page's parts come from; TMDB by default.
  final SeasonSource? source;

  /// What the viewer has watched; the recently watched store by default.
  final WatchHistory? history;
  final WidgetBuilder? adBuilder;
  final DateTime Function()? now;

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen>
    with CollapsingHeader<EpisodeScreen> {
  late SeasonSource _source;
  late EpisodeList _episode = widget.episode;
  late Future<TVDetails> _series;
  late Future<List<Genres>> _genres;
  late Future<List<EpisodeList>> _season;
  late Future<EpisodeList> _details;
  late Future<Credits> _credits;
  late Future<Images> _images;
  final AmbientThemeScopeController _ambient = AmbientThemeScopeController();
  final ScrollController _seasonScroll = ScrollController();
  bool _seasonPlaced = false;
  bool _started = false;
  bool _starting = false;
  bool _overviewOpen = false;

  int get _seriesId => widget.series.id;
  int? get _seasonNumber => _episode.seasonNumber;
  int? get _number => _episode.episodeNumber;

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
    final given = widget.seasonEpisodes;
    final season = _seasonNumber;
    _season = given != null && given.isNotEmpty
        ? Future<List<EpisodeList>>.value(given)
        : season == null
            ? Future<List<EpisodeList>>.value(const <EpisodeList>[])
            : (_source.episodes(_seriesId, season)..ignore());
    _loadEpisode();
    _ambient.attach(context, _episode.stillPath ?? widget.series.posterPath);
  }

  @override
  void dispose() {
    _ambient.dispose();
    _seasonScroll.dispose();
    super.dispose();
  }

  void _loadEpisode() {
    final season = _seasonNumber;
    final number = _number;
    if (season == null || number == null) {
      _details = Future<EpisodeList>.value(_episode);
      _credits = Future<Credits>.value(Credits());
      _images = Future<Images>.value(Images());
    } else {
      _details = _source.episode(_seriesId, season, number)..ignore();
      _credits = _source.episodeCredits(_seriesId, season, number)..ignore();
      _images = _source.episodeImages(_seriesId, season, number)..ignore();
    }
    context.read<SettingsProvider>().analytics.trackEpisodeDetailView(
          tvName: widget.series.title,
          episodeName: _episode.name,
        );
  }

  /// Moves to another episode of the season in place.
  void _show(EpisodeList episode) {
    if (episode.episodeNumber == _number) return;
    setState(() {
      _episode = episode;
      _overviewOpen = false;
      _loadEpisode();
    });
    if (scroll.hasClients) {
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
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

  Future<T?> _quietly<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
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

  Future<void> _play({bool download = false}) async {
    final episode = _episode;
    final series = await _quietly(_series);
    final genres = await _quietly(_genres) ?? const <Genres>[];
    final seasonEpisodes = await _quietly(_season) ?? <EpisodeList>[episode];
    if (!mounted) return;
    await playEpisode(
      context,
      series: widget.series,
      episode: episode,
      seasonEpisodes: seasonEpisodes,
      allSeasons: widget.seasons ?? series?.seasons,
      insights: insightsMetadata(
        genres: genres.map((genre) => genre.genreName ?? '').toList(),
        series: series,
        originalLanguage: widget.series.series?.originalLanguage,
      ),
      download: download,
    );
  }

  Future<void> _share() async {
    context.read<SettingsProvider>().analytics.trackShare(
          shareType: 'Episode',
          mediaName: '${widget.series.title} ${_label ?? ''}'.trim(),
        );
    final url = MediaLink.episodeUrl(
      _seriesId,
      _seasonNumber ?? 0,
      _number ?? 0,
    );
    await Share.share(
      tr(
        'share_episode',
        namedArgs: <String, String>{
          'et': _episode.name ?? '',
          'title': widget.series.title,
          'rating': (_episode.voteAverage ?? 0).toStringAsFixed(1),
          'url': '$url',
        },
      ),
    );
  }

  /// "S2:E4".
  String? get _label {
    final season = _seasonNumber;
    final number = _number;
    return season == null || number == null ? null : 'S$season:E$number';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final history = _history(context);
    final title = (_episode.name ?? '').trim().isEmpty
        ? (_label ?? widget.series.title)
        : _episode.name!.trim();
    return Scaffold(
      backgroundColor: palette.page,
      body: CustomScrollView(
        controller: scroll,
        slivers: <Widget>[
          DetailsSliverHeader(
            title: title,
            collapsed: collapsed,
            artwork: MediaArt(
              key: ValueKey<int?>(_number),
              item: widget.series,
              path: _episode.stillPath,
              width: MediaQuery.sizeOf(context).width,
              size: ArtSize.still,
              alignment: Alignment.topCenter,
            ),
          ),
          SliverToBoxAdapter(
              child: ReadableWidth(child: _summary(context, title, history))),
          SliverToBoxAdapter(
            child: widget.adBuilder?.call(context) ??
                HomeAdSlot(
                  placement: 'episode_detail',
                  variant: HostedBannerVariant.tall,
                ),
          ),
          SliverToBoxAdapter(
              child: ReadableWidth(child: _seasonRow(context, history))),
          SliverToBoxAdapter(
              child: ReadableWidth(child: _cast(context, title))),
          SliverToBoxAdapter(
              child: ReadableWidth(child: _stills(context, title))),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, String title, WatchHistory history) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final dependencies = context.watch<AppDependencyProvider?>();
    final locale = Localizations.localeOf(context).toString();
    final now = widget.now?.call() ?? DateTime.now();
    final aired = hasAired(_episode, now: now);
    final airDate = DateTime.tryParse(_episode.airDate ?? '');
    final canPlay = (dependencies?.displayWatchNowButton ?? true) && aired;
    final canDownload = (dependencies?.displayDownloadButton ?? false) && aired;
    final resume = episodeResume(
      history.episodes,
      seriesId: _seriesId,
      episode: _episode,
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
          Text(
            title,
            style: AppType.scaled(context, AppType.pageTitle)
                .copyWith(color: palette.foreground),
          ),
          const SizedBox(height: AppSpace.sm),
          FutureBuilder<EpisodeList>(
            future: _details,
            builder: (context, snapshot) {
              final runtime = snapshot.data?.runtime ?? _episode.runtime;
              return FactsLine(
                facts: <String>[
                  if (_label case final label?) label,
                  if (airDate != null)
                    aired
                        ? DateFormat.yMMMd(locale).format(airDate)
                        : tr('coming_date', namedArgs: <String, String>{
                            'date': DateFormat.MMMd(locale).format(airDate),
                          }),
                  if (runtime != null && runtime > 0)
                    formatRuntime(Duration(minutes: runtime)),
                ],
                rating: (_episode.voteAverage ?? 0).toDouble(),
              );
            },
          ),
          if (canPlay || canDownload) const SizedBox(height: AppSpace.lg),
          if (canPlay)
            DetailsPlayButton(
              label: resume == null ? tr('play') : tr('resume_title'),
              resume: resume,
              busy: _starting,
              onPressed: () => _run(_play),
            ),
          if (canDownload)
            DetailsSecondaryButton(
              label: tr('download_action'),
              icon: PhosphorIcons.downloadSimple(),
              onPressed:
                  _starting ? null : () => _run(() => _play(download: true)),
            ),
          if ((_episode.overview ?? '').trim().isNotEmpty) ...<Widget>[
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
                    _episode.overview!.trim(),
                    maxLines: _overviewOpen ? null : 4,
                    overflow: _overviewOpen ? null : TextOverflow.ellipsis,
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                ),
              ),
            ),
          ],
          _creditLines(context),
          const SizedBox(height: AppSpace.md),
          Row(
            children: <Widget>[
              Expanded(
                child: DetailsAction(
                  icon: PhosphorIcons.television(),
                  label: tr('series'),
                  onPressed: () =>
                      MobilePlayback.openDetails(context, widget.series),
                ),
              ),
              Expanded(
                child: DetailsAction(
                  icon: PhosphorIcons.shareNetwork(),
                  label: tr('share'),
                  onPressed: _share,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creditLines(BuildContext context) {
    final palette = AppPalette.of(context);
    Widget line(String key, List<String> names) => Padding(
          padding: const EdgeInsets.only(top: AppSpace.sm),
          child: Text(
            tr(key, namedArgs: <String, String>{'names': names.join(', ')}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.metadata.copyWith(
              color: palette.mutedText,
              fontSize: 13,
            ),
          ),
        );
    return FutureBuilder<Credits>(
      future: _credits,
      builder: (context, snapshot) {
        final credits = snapshot.data;
        final guests = <String>[
          for (final guest in credits?.episodeGuestStars ?? const [])
            if ((guest.name ?? '').trim().isNotEmpty) guest.name!.trim(),
        ].take(3).toList();
        final directed = crewWith(credits, const <String>{'Director'});
        final written = crewWith(
          credits,
          const <String>{'Writer', 'Screenplay', 'Teleplay', 'Story'},
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (guests.isNotEmpty) line('guest_stars_line', guests),
            if (directed.isNotEmpty) line('director_line', directed),
            if (written.isNotEmpty) line('writers_line', written),
          ],
        );
      },
    );
  }

  /// The rest of the season as stills, this one marked, to move between.
  Widget _seasonRow(BuildContext context, WatchHistory history) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final width = posterWidth(context) * 1.6;
    return FutureBuilder<List<EpisodeList>>(
      future: _season,
      builder: (context, snapshot) {
        final episodes = (snapshot.data ?? const <EpisodeList>[])
            .where((episode) => episode.episodeNumber != null)
            .toList(growable: false);
        if (snapshot.connectionState != ConnectionState.done) {
          return Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, 0, 0),
            child: SkeletonBlock(width: width, height: width * 9 / 16),
          );
        }
        if (episodes.length < 2) return const SizedBox.shrink();
        final current = episodes.indexWhere(
          (episode) => episode.episodeNumber == _number,
        );
        final scale = MediaQuery.textScalerOf(context);
        // Opens at this episode, or the one before it, once.
        if (!_seasonPlaced && current > 0) {
          _seasonPlaced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_seasonScroll.hasClients) return;
            final position = _seasonScroll.position;
            _seasonScroll.jumpTo(
              ((current - 1) * (width + 10))
                  .clamp(0.0, position.maxScrollExtent),
            );
          });
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(
                title: tr('season_number', namedArgs: <String, String>{
                  'number': '${_seasonNumber ?? ''}',
                }),
              ),
              SizedBox(
                height: width * 9 / 16 + AppSpace.sm + scale.scale(36),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  controller: _seasonScroll,
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    final selected = index == current;
                    final progress = episodeProgress(
                      history.episodes,
                      seriesId: _seriesId,
                      season: episode.seasonNumber ?? _seasonNumber ?? 0,
                      episode: episode.episodeNumber ?? -1,
                    );
                    return SizedBox(
                      width: width,
                      child: Semantics(
                        selected: selected,
                        button: true,
                        child: InkWell(
                          onTap: () => _show(episode),
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              DecoratedBox(
                                position: DecorationPosition.foreground,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.card),
                                  border: selected
                                      ? Border.all(
                                          color: palette.foreground,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.card),
                                  child: SizedBox(
                                    width: width,
                                    height: width * 9 / 16,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[
                                        MediaArt(
                                          item: widget.series,
                                          path: episode.stillPath,
                                          width: width,
                                          size: 'w300/',
                                          placeholder: MediaArt.darkPlaceholder,
                                        ),
                                        if (progress != null)
                                          PositionedDirectional(
                                            start: 0,
                                            end: 0,
                                            bottom: 0,
                                            child: EpisodeProgressBar(
                                              value: progress,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.sm),
                              Text(
                                '${episode.episodeNumber}. '
                                '${(episode.name ?? '').trim()}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.metadata.copyWith(
                                  fontFamily: AppType.semiBold,
                                  fontSize: 13,
                                  color: selected
                                      ? palette.foreground
                                      : palette.secondaryText,
                                ),
                              ),
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
        );
      },
    );
  }

  Widget _cast(BuildContext context, String title) => FutureBuilder<Credits>(
        future: _credits,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const CastRowSkeleton();
          }
          final cast = episodeCast(snapshot.data);
          if (cast.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: tr('cast'),
                  onSeeAll: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CreditsScreen(
                        kicker: widget.series.title,
                        title: title,
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

  Widget _stills(BuildContext context, String title) => FutureBuilder<Images>(
        future: _images,
        builder: (context, snapshot) {
          final stills = (snapshot.data?.still ?? const <Stills>[])
              .where((still) => still.stillPath != null)
              .toList(growable: false);
          if (stills.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: tr('images')),
                ImageRow(
                  paths: <String>[for (final still in stills) still.stillPath!],
                  aspectRatio: 16 / 9,
                  onOpen: (index) => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => HeroPhotoView(
                        imageType: 'still',
                        stills: stills,
                        name: title,
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
