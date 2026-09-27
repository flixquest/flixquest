import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/details_play.dart';
import '../../catalog/episode_choice.dart';
import '../../catalog/media_item.dart';
import '../../catalog/title_details_source.dart';
import '../../catalog/title_logos.dart';
import '../../controllers/bookmark_database_controller.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/media_badge.dart';
import '../../design/title_logo.dart';
import '../../functions/function.dart';
import '../../models/credits.dart';
import '../../models/genres.dart';
import '../../models/images.dart';
import '../../models/movie.dart';
import '../../models/movie_stream_metadata.dart';
import '../../models/tv.dart';
import '../../models/tv_stream_metadata.dart';
import '../../models/videos.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';
import '../../screens/common/photoview.dart';
import '../../screens/movie/collection_detail.dart';
import '../../screens/movie/movie_castandcrew.dart';
import '../../screens/movie/movie_video_loader.dart';
import '../../screens/tv/episode_detail.dart';
import '../../screens/tv/seasons_detail.dart';
import '../../screens/tv/tv_video_loader.dart';
import '../../screens/tv/tvdetail_castandcrew.dart';
import '../../services/ambient_theme_service.dart';
import '../collections.dart';
import '../my_list.dart';
import '../widgets/details_parts.dart';
import '../widgets/episodes_section.dart';
import '../widgets/filter_chips.dart';
import '../widgets/media_art.dart';
import '../widgets/pill_button.dart';
import '../widgets/poster_card.dart';
import '../widgets/section_header.dart';
import 'home_screen.dart' show HomeAdSlot;

enum DetailsTab { moreLikeThis, trailers, about }

/// A movie's or series' page on the phone: its artwork, then what to do
/// (Play, Download, My List), what it is, a series' episodes, and tabs for
/// titles like it, its videos and images, and everything else.
class TitleDetailsScreen extends StatefulWidget {
  const TitleDetailsScreen({
    required this.item,
    this.source,
    this.history,
    this.showTitleLogos = true,
    this.adBuilder,
    this.now,
    super.key,
  });

  final MediaItem item;

  /// Where the page's parts come from; TMDB by default.
  final TitleDetailsSource? source;

  /// What the viewer has watched; the recently watched store by default.
  final WatchHistory? history;
  final bool showTitleLogos;
  final WidgetBuilder? adBuilder;
  final DateTime Function()? now;

  @override
  State<TitleDetailsScreen> createState() => _TitleDetailsScreenState();
}

class _TitleDetailsScreenState extends State<TitleDetailsScreen> {
  late TitleDetailsSource _source;
  Future<MovieDetails>? _movie;
  Future<TVDetails>? _series;
  late Future<List<Genres>> _genres;
  late Future<Credits> _credits;
  late Future<Videos> _videos;
  late Future<Images> _images;
  late Future<ExternalLinks> _links;
  Future<BelongsToCollection?>? _collection;
  final Map<int, Future<List<EpisodeList>>> _seasons =
      <int, Future<List<EpisodeList>>>{};

  final List<MediaItem> _like = <MediaItem>[];
  int _likePage = 0;
  bool _likeLoading = false;
  bool _likeDone = false;
  bool _likeFailed = false;

  DetailsTab _tab = DetailsTab.moreLikeThis;
  final ScrollController _scroll = ScrollController();
  final AmbientThemeScopeController _ambient = AmbientThemeScopeController();
  TitleLogos? _logos;
  bool _started = false;
  bool _collapsed = false;
  bool _synopsisOpen = false;
  bool _starting = false;

  MediaItem get _item => widget.item;
  bool get _isMovie => _item.kind == MediaKind.movie;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _source = widget.source ??
        TmdbTitleDetailsSource(
          settings: context.read<SettingsProvider>(),
          dependencies: context.read<AppDependencyProvider>(),
        );
    _load();
    _loadMoreLikeThis();
    _ambient.attach(context, _item.posterPath ?? _item.backdropPath);
    _trackView();
    unawaited(_refreshSavedMovie());
  }

  @override
  void dispose() {
    _ambient.dispose();
    _logos?.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _load() {
    final item = _item;
    if (_isMovie) {
      _movie = _source.movie(item.id);
      _collection = _source.collection(item.id);
    } else {
      _series = _source.series(item.id);
    }
    _genres = _source.genres(item);
    _credits = _source.credits(item);
    _videos = _source.videos(item);
    _images = _source.images(item);
    _links = _source.links(item);
    // Each part shows its own failure; none of them is left unhandled.
    for (final Future<Object?>? future in <Future<Object?>?>[
      _movie,
      _series,
      _collection,
      _genres,
      _credits,
      _videos,
      _images,
      _links,
    ]) {
      future?.ignore();
    }
  }

  void _retry() => setState(_load);

  void _onScroll() {
    final collapsed = _scroll.hasClients &&
        _scroll.offset > _backdropHeight(context) - kToolbarHeight - 24;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  double _backdropHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width * 9 / 16;

  void _trackView() {
    final analytics = context.read<SettingsProvider>().analytics;
    if (_isMovie) {
      analytics.trackMoviePageView(
        movieName: _item.title,
        movieId: _item.id,
        isAdult: _item.movie?.adult,
      );
    } else {
      analytics.trackTVPageView(
        tvName: _item.title,
        tvId: _item.id,
        isAdult: _item.series?.adult,
      );
    }
  }

  /// A saved movie's stored copy is brought up to date, as the old page did.
  Future<void> _refreshSavedMovie() async {
    final movie = _item.movie;
    if (movie == null || widget.source != null) return;
    try {
      final database = MovieDatabaseController();
      if (await database.contain(_item.id)) {
        await database.updateMovie(movie, _item.id);
      }
    } catch (_) {}
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
    return _logos = TitleLogos(
      language: settings.appLanguage,
      proxyEnabled: settings.enableProxy,
      proxyUrl: dependencies.tmdbProxy,
    );
  }

  // --- Episodes ------------------------------------------------------------

  /// A season's episodes, fetched once; a failure is forgotten so Retry asks
  /// again.
  Future<List<EpisodeList>> _seasonEpisodes(int season) {
    final cached = _seasons[season];
    if (cached != null) return cached;
    final load = _source.season(_item.id, season);
    _seasons[season] = load;
    load.then<void>((_) {}, onError: (Object _) => _seasons.remove(season));
    return load;
  }

  // --- Actions -------------------------------------------------------------

  Future<bool> _online() async {
    if (await checkConnection()) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('check_connection'))),
      );
    }
    return false;
  }

  /// Genres, languages and countries for Viewing Insights.
  Future<
      ({
        List<String> genres,
        List<String> languages,
        List<String> countries
      })> _insights() async {
    Future<T?> quietly<T>(Future<T>? future) async {
      try {
        return await future;
      } catch (_) {
        return null;
      }
    }

    final genres = await quietly(_genres) ?? const <Genres>[];
    return insightsMetadata(
      genres: genres.map((genre) => genre.genreName ?? '').toList(),
      movie: await quietly(_movie),
      series: await quietly(_series),
      originalLanguage:
          _item.movie?.originalLanguage ?? _item.series?.originalLanguage,
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

  Future<void> _playMovie({int? elapsed, bool download = false}) async {
    if (!await _online() || !mounted) return;
    final insights = await _insights();
    if (!mounted) return;
    final item = _item;
    final queued = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MovieVideoLoader(
          download: download,
          metadata: MovieStreamMetadata(
            backdropPath: item.backdropPath,
            elapsed: elapsed,
            movieId: item.id,
            movieName: item.title,
            posterPath: item.posterPath,
            releaseYear: int.tryParse(item.year ?? '') ?? 0,
            isAdult: item.movie?.adult,
            releaseDate: item.releaseDate,
            genres: insights.genres,
            languages: insights.languages,
            countries: insights.countries,
          ),
        ),
      ),
    );
    if (download && queued == true && mounted) _addedToDownloads();
  }

  void _addedToDownloads() => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('added_to_downloads'))),
      );

  /// Plays the series from where the viewer stands, by the same rules as
  /// the button's label.
  Future<void> _playSeries(WatchHistory history) async {
    final details = await _series;
    if (details == null || !mounted) return;
    try {
      final next = upNextFor(
        _item,
        episodes: history.episodes,
        upNext: history.upNext,
      );
      final choice = await chooseEpisode(
        seasons: _orderedSeasons(details),
        resume: next != null
            ? null
            : ResumePoint.forItem(
                _item,
                movies: history.movies,
                episodes: history.episodes,
              ),
        upNext: next,
        loadSeason: _seasonEpisodes,
        now: widget.now?.call(),
      );
      if (choice == null) return;
      await _playEpisode(
        choice.episode,
        choice.seasonEpisodes,
        elapsed: choice.elapsed,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('episodes_load_failed'))),
        );
      }
    }
  }

  Future<void> _playEpisode(
    EpisodeList episode,
    List<EpisodeList> seasonEpisodes, {
    int? elapsed,
    bool download = false,
  }) async {
    if (!await _online() || !mounted) return;
    final insights = await _insights();
    TVDetails? details;
    try {
      details = await _series;
    } catch (_) {}
    if (!mounted) return;
    final item = _item;
    final queued = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TVVideoLoader(
          download: download,
          metadata: TVStreamMetadata(
            elapsed: elapsed,
            episodeId: episode.episodeId,
            episodeName: episode.name,
            episodeNumber: episode.episodeNumber,
            posterPath: item.posterPath,
            backdropPath: episode.stillPath ?? item.backdropPath,
            seasonNumber: episode.seasonNumber,
            seriesName: item.title,
            tvId: item.id,
            airDate: episode.airDate,
            genres: insights.genres,
            languages: insights.languages,
            countries: insights.countries,
            seasonEpisodes: seasonEpisodes
                .where((episode) => episode.episodeId != null)
                .map(EpisodeMetadata.fromEpisodeList)
                .toList(growable: false),
            allSeasons: details?.seasons
                ?.where((season) => season.seasonNumber != null)
                .map(SeasonMetadata.fromSeason)
                .toList(growable: false),
          ),
        ),
      ),
    );
    if (download && queued == true && mounted) _addedToDownloads();
  }

  void _openEpisode(EpisodeList episode, List<EpisodeList> seasonEpisodes) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EpisodeDetailPage(
          episodeList: episode,
          episodes: seasonEpisodes,
          tvId: _item.id,
          seriesName: _item.title,
          posterPath: _item.posterPath,
        ),
      ),
    );
  }

  Future<void> _openSeason(Seasons season) async {
    TVDetails? details;
    try {
      details = await _series;
    } catch (_) {}
    if (details == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeasonsDetail(
          seasons: season,
          tvDetails: details!,
          tvId: _item.id,
          seriesName: _item.title,
          heroId: 'season_${_item.id}_${season.seasonNumber}',
        ),
      ),
    );
  }

  Future<void> _toggleMyList() async {
    final saved = MyList.contains(context, _item);
    HapticFeedback.lightImpact();
    await MyList.toggle(context, _item);
    if (!mounted) return;
    context.read<SettingsProvider>().analytics.trackBookmarkToggle(
          mediaType: _isMovie ? 'Movie' : 'TV',
          mediaName: _item.title,
          mediaId: _item.id,
          added: !saved,
        );
  }

  Future<void> _share() async {
    context.read<SettingsProvider>().analytics.trackShare(
        shareType: _isMovie ? 'Movie' : 'TV', mediaName: _item.title);
    await Share.share(
      tr(
        _isMovie ? 'share_movie' : 'share_tv',
        namedArgs: <String, String>{
          'title': _item.title,
          'rating': (_item.rating ?? 0).toStringAsFixed(1),
          'id': '${_item.id}',
        },
      ),
    );
  }

  Future<void> _loadMoreLikeThis() async {
    if (_likeLoading || _likeDone) return;
    setState(() {
      _likeLoading = true;
      _likeFailed = false;
    });
    final page = _likePage + 1;
    var failures = 0;
    Future<List<MediaItem>> settle(Future<List<MediaItem>> load) async {
      try {
        return await load;
      } catch (_) {
        failures++;
        return const <MediaItem>[];
      }
    }

    final results = await Future.wait(<Future<List<MediaItem>>>[
      settle(_source.recommendations(_item, page)),
      settle(_source.similar(_item, page)),
    ]);
    if (!mounted) return;
    setState(() {
      _likeLoading = false;
      if (failures == 2) {
        _likeFailed = true;
        return;
      }
      _likePage = page;
      final known = _like.map((item) => item.stableId).toSet();
      final fresh = moreLikeThis(_item, results[0], results[1])
          .where((item) => known.add(item.stableId))
          .toList();
      _like.addAll(fresh);
      _likeDone = fresh.isEmpty;
    });
  }

  static List<Seasons> _orderedSeasons(TVDetails details) => MediaDetailsData(
        item: const MediaItem(
          kind: MediaKind.series,
          id: 0,
          title: '',
          overview: '',
          posterPath: null,
          backdropPath: null,
          rating: null,
          releaseDate: null,
        ),
        seriesDetails: details,
        recommendations: const <MediaItem>[],
      ).seasons;

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final history = _history(context);
    final page = Scaffold(
      backgroundColor: palette.page,
      body: CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          _header(context),
          SliverToBoxAdapter(child: _summary(context, history)),
          SliverToBoxAdapter(
            child: widget.adBuilder?.call(context) ??
                HomeAdSlot(placement: _isMovie ? 'movie_detail' : 'tv_detail'),
          ),
          if (!_isMovie) SliverToBoxAdapter(child: _episodes(context, history)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsHeader(
              tab: _tab,
              background: palette.page,
              hairline: palette.hairline,
              onSelect: (tab) => setState(() => _tab = tab),
            ),
          ),
          ..._tabSlivers(context),
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpace.xxxl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
    return widget.showTitleLogos
        ? TitleLogoScope(logos: _logosFor(context), child: page)
        : page;
  }

  Widget _header(BuildContext context) {
    final palette = AppPalette.of(context);
    final height = _backdropHeight(context);
    final collapsed = _collapsed;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      pinned: true,
      expandedHeight: height,
      backgroundColor: palette.page,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // Light icons over the artwork; the theme's own once it has scrolled
      // away.
      systemOverlayStyle: collapsed && !dark
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppSpace.sm),
        child: Center(
          child: _RoundButton(
            icon: PhosphorIcons.caretLeft(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onArtwork: !collapsed,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      titleSpacing: 0,
      title: AnimatedOpacity(
        opacity: collapsed ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Text(
          _item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.sectionHeader.copyWith(color: palette.foreground),
        ),
      ),
      flexibleSpace: _Backdrop(item: _item),
    );
  }

  Widget _summary(BuildContext context, WatchHistory history) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final item = _item;
    final badge = MediaBadge.recencyOf(item);
    final fallbackTitle = Text(
      item.title,
      style: AppType.scaled(context, AppType.heroTitle)
          .copyWith(color: palette.foreground),
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.showTitleLogos)
            TitleLogo(
              item: item,
              maxHeight: 72,
              alignment: AlignmentDirectional.centerStart,
              fallback: fallbackTitle,
            )
          else
            fallbackTitle,
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _facts(context),
              if (badge != null) MediaBadge(label: badge),
            ],
          ),
          _genrePills(context),
          const SizedBox(height: AppSpace.lg),
          _playButton(context, history),
          if (_isMovie) _downloadButton(context),
          const SizedBox(height: AppSpace.lg),
          _synopsis(context),
          _creditLines(context),
          const SizedBox(height: AppSpace.md),
          _actions(context),
        ],
      ),
    );
  }

  Widget _facts(BuildContext context) {
    final palette = AppPalette.of(context);
    final style = AppType.metadata.copyWith(
      color: palette.mutedText,
      fontSize: 13,
    );
    // Year · ★ 8.3 · 2h 50m, the star drawn as an icon: Figtree has none.
    Widget line(List<String> after) {
      final rating = _item.rating ?? 0;
      final parts = <InlineSpan>[
        if (_item.year != null) TextSpan(text: _item.year),
        if (rating > 0) ...<InlineSpan>[
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 3),
              child: Icon(
                PhosphorIcons.star(PhosphorIconsStyle.fill),
                size: 12,
                color: palette.mutedText,
              ),
            ),
          ),
          TextSpan(text: rating.toStringAsFixed(1)),
        ],
        for (final fact in after) TextSpan(text: fact),
      ];
      final spans = <InlineSpan>[];
      for (final part in parts) {
        // The star and its number are one fact.
        final joinsStar =
            part is TextSpan && spans.isNotEmpty && spans.last is WidgetSpan;
        if (spans.isNotEmpty && !joinsStar) {
          spans.add(const TextSpan(text: ' · '));
        }
        spans.add(part);
      }
      return Text.rich(TextSpan(style: style, children: spans));
    }

    if (_isMovie) {
      return FutureBuilder<MovieDetails>(
        future: _movie,
        builder: (context, snapshot) {
          final runtime = snapshot.data?.runtime ?? 0;
          return line(<String>[
            if (runtime > 0) formatRuntime(Duration(minutes: runtime)),
          ]);
        },
      );
    }
    return FutureBuilder<TVDetails>(
      future: _series,
      builder: (context, snapshot) {
        final seasons = snapshot.data?.numberOfSeasons ?? 0;
        return line(<String>[
          if (seasons == 1) tr('season_one'),
          if (seasons > 1)
            tr('seasons_count',
                namedArgs: <String, String>{'count': '$seasons'}),
        ]);
      },
    );
  }

  Widget _genrePills(BuildContext context) {
    return FutureBuilder<List<Genres>>(
      future: _genres,
      builder: (context, snapshot) {
        final genres = (snapshot.data ?? const <Genres>[])
            .where((genre) => genre.genreID != null && genre.genreName != null)
            .toList(growable: false);
        if (genres.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: <Widget>[
              for (final genre in genres)
                ChoicePill(
                  spec: FilterChipSpec(
                    label: genre.genreName!,
                    onTap: () =>
                        openGenreCollection(context, _item.kind, genre),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _playButton(BuildContext context, WatchHistory history) {
    final dependencies = context.watch<AppDependencyProvider?>();
    if (!(dependencies?.displayWatchNowButton ?? true)) {
      return const SizedBox.shrink();
    }
    if (_isMovie) {
      // A movie with no release date isn't out, and isn't offered.
      if (DateTime.tryParse(_item.releaseDate ?? '') == null) {
        return const SizedBox.shrink();
      }
      final plan = detailsPlayFor(_item, history);
      return _PlayButton(
        label: _playLabel(plan),
        resume: plan.resume,
        busy: _starting,
        onPressed: () => _run(() => _playMovie(elapsed: plan.resume?.elapsed)),
      );
    }
    return FutureBuilder<TVDetails>(
      future: _series,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const DetailsBlock(height: 48, radius: AppRadii.button);
        }
        final details = snapshot.data;
        final seasons =
            details == null ? const <Seasons>[] : _orderedSeasons(details);
        if (seasons.isEmpty) return const SizedBox.shrink();
        final plan = detailsPlayFor(
          _item,
          history,
          firstSeason: seasons.first.seasonNumber,
        );
        return _PlayButton(
          label: _playLabel(plan),
          resume: plan.resume,
          busy: _starting,
          onPressed: () => _run(() => _playSeries(history)),
        );
      },
    );
  }

  String _playLabel(DetailsPlay plan) {
    final episode = <String, String>{'episode': plan.episode ?? ''};
    return switch (plan.kind) {
      DetailsPlayKind.play => tr('play'),
      DetailsPlayKind.resume => tr('resume_title'),
      DetailsPlayKind.playEpisode => tr('play_episode', namedArgs: episode),
      DetailsPlayKind.resumeEpisode => tr('resume_episode', namedArgs: episode),
      DetailsPlayKind.nextEpisode => tr('next_episode'),
    };
  }

  Widget _downloadButton(BuildContext context) {
    final dependencies = context.watch<AppDependencyProvider?>();
    final released = DateTime.tryParse(_item.releaseDate ?? '') != null;
    if (!(dependencies?.displayDownloadButton ?? false) || !released) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: SizedBox(
        width: double.infinity,
        child: PillButton(
          label: tr('download_action'),
          icon: PhosphorIcons.downloadSimple(),
          height: 48,
          onPressed:
              _starting ? null : () => _run(() => _playMovie(download: true)),
        ),
      ),
    );
  }

  Widget _synopsis(BuildContext context) {
    final palette = AppPalette.of(context);
    final overview = _item.overview.trim();
    if (overview.isEmpty) return const SizedBox.shrink();
    return Semantics(
      button: true,
      onTapHint: _synopsisOpen ? tr('read_less') : tr('read_more'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _synopsisOpen = !_synopsisOpen),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: AlignmentDirectional.topStart,
          child: Text(
            overview,
            maxLines: _synopsisOpen ? null : 3,
            overflow: _synopsisOpen ? null : TextOverflow.ellipsis,
            style: AppType.body.copyWith(color: palette.secondaryText),
          ),
        ),
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
        final cast = starring(snapshot.data);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (cast.isNotEmpty) line('starring_line', cast),
            if (_isMovie)
              if (directors(snapshot.data) case final names
                  when names.isNotEmpty)
                line('director_line', names)
              else
                const SizedBox.shrink()
            else
              FutureBuilder<TVDetails>(
                future: _series,
                builder: (context, series) {
                  final names = creators(series.data);
                  return names.isEmpty
                      ? const SizedBox.shrink()
                      : line('creators_line', names);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _actions(BuildContext context) {
    final saved = MyList.contains(context, _item);
    return FutureBuilder<Videos>(
      future: _videos,
      builder: (context, snapshot) {
        final trailer = pickTrailer(snapshot.data);
        return Row(
          children: <Widget>[
            Expanded(
              child: DetailsAction(
                icon: saved
                    ? PhosphorIcons.check(PhosphorIconsStyle.bold)
                    : PhosphorIcons.plus(),
                label: tr('my_list'),
                onPressed: _toggleMyList,
              ),
            ),
            if (trailer != null)
              Expanded(
                child: DetailsAction(
                  icon: PhosphorIcons.filmStrip(),
                  label: tr('trailer'),
                  onPressed: () => openVideo(trailer),
                ),
              ),
            Expanded(
              child: DetailsAction(
                icon: PhosphorIcons.shareNetwork(),
                label: tr('share'),
                onPressed: _share,
              ),
            ),
            Expanded(
              child: DetailsAction(
                icon: PhosphorIcons.television(),
                label: tr('where_to_watch'),
                onPressed: () => showWatchProvidersSheet(
                  context,
                  _source.watchProviders(_item),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _episodes(BuildContext context, WatchHistory history) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final dependencies = context.watch<AppDependencyProvider?>();
    return FutureBuilder<TVDetails>(
      future: _series,
      builder: (context, snapshot) {
        final Widget body;
        if (snapshot.connectionState != ConnectionState.done) {
          body = Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: const DetailsBlock(width: 140, height: 34),
          );
        } else if (snapshot.hasError || snapshot.data == null) {
          body = Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: DetailsMessage(
              message: tr('episodes_load_failed'),
              onRetry: _retry,
            ),
          );
        } else {
          final seasons = _orderedSeasons(snapshot.data!);
          if (seasons.isEmpty) return const SizedBox.shrink();
          final next = upNextFor(
            _item,
            episodes: history.episodes,
            upNext: history.upNext,
          );
          final watching = next != null &&
                  seasons.any((season) => season.seasonNumber == next.season)
              ? next.season
              : initialSeasonNumber(
                  seasons,
                  ResumePoint.forItem(
                    _item,
                    movies: history.movies,
                    episodes: history.episodes,
                  ),
                );
          body = EpisodesSection(
            series: _item,
            seasons: seasons,
            initialSeason: watching,
            loadSeason: _seasonEpisodes,
            watched: history.episodes,
            canPlay: dependencies?.displayWatchNowButton ?? true,
            canDownload: dependencies?.displayDownloadButton ?? false,
            onPlay: (episode, episodes) =>
                _run(() => _playEpisode(episode, episodes)),
            onDownload: (episode) => _run(() async {
              final episodes = await _seasonEpisodes(episode.seasonNumber ?? 0);
              await _playEpisode(episode, episodes, download: true);
            }),
            onOpen: _openEpisode,
            onSeasonInfo: _openSeason,
            now: widget.now,
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  0,
                  gutter,
                  AppSpace.md,
                ),
                child: Text(
                  tr('episodes'),
                  style: AppType.scaled(context, AppType.sectionHeader)
                      .copyWith(color: palette.foreground),
                ),
              ),
              body,
            ],
          ),
        );
      },
    );
  }

  // --- Tabs ----------------------------------------------------------------

  List<Widget> _tabSlivers(BuildContext context) => switch (_tab) {
        DetailsTab.moreLikeThis => _moreLikeThis(context),
        DetailsTab.trailers => _trailers(context),
        DetailsTab.about => _about(context),
      };

  List<Widget> _moreLikeThis(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    const spacing = 10.0;
    const columns = 3;
    final width = (MediaQuery.sizeOf(context).width -
            gutter * 2 -
            spacing * (columns - 1)) /
        columns;
    if (_like.isEmpty) {
      return <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          sliver: SliverToBoxAdapter(
            child: _likeLoading
                ? Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: <Widget>[
                      for (var i = 0; i < 6; i++)
                        DetailsBlock(
                          width: width,
                          height: width / PosterCard.aspectRatio,
                        ),
                    ],
                  )
                : DetailsMessage(
                    message: _likeFailed
                        ? tr('check_connection')
                        : tr('nothing_here_yet'),
                    onRetry: _likeFailed ? _loadMoreLikeThis : null,
                  ),
          ),
        ),
      ];
    }
    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: PosterCard.aspectRatio,
          ),
          itemCount: _like.length,
          itemBuilder: (context, index) =>
              PosterCard(item: _like[index], width: width),
        ),
      ),
      if (!_likeDone)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.lg),
            child: Center(
              child: _likeFailed
                  ? DetailsMessage(
                      message: tr('check_connection'),
                      onRetry: _loadMoreLikeThis,
                    )
                  : PillButton(
                      label: tr('show_more'),
                      busy: _likeLoading,
                      onPressed: _likeLoading ? null : _loadMoreLikeThis,
                    ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _trailers(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverToBoxAdapter(
          child: FutureBuilder<Videos>(
            future: _videos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const DetailsBlock(height: 200);
              }
              if (snapshot.hasError) {
                return DetailsMessage(
                  message: tr('check_connection'),
                  onRetry: _retry,
                );
              }
              final videos = (snapshot.data?.result ?? const <Results>[])
                  .where((video) => (video.videoLink ?? '').isNotEmpty)
                  .toList(growable: false);
              if (videos.isEmpty) {
                return DetailsMessage(message: tr('nothing_here_yet'));
              }
              return Column(
                children: <Widget>[
                  for (final video in videos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      child: VideoTile(video: video),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        sliver: SliverToBoxAdapter(
          child: FutureBuilder<Images>(
            future: _images,
            builder: (context, snapshot) {
              final images = snapshot.data;
              final backdrops = images?.backdrop ?? const <Backdrops>[];
              final posters = images?.poster ?? const <Posters>[];
              if (backdrops.isEmpty && posters.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.md),
                    child: Text(
                      tr('images'),
                      style: AppType.sectionHeader.copyWith(
                        color: AppPalette.of(context).foreground,
                      ),
                    ),
                  ),
                  if (backdrops.isNotEmpty)
                    ArtworkCard(
                      url: tmdbImageUrl(
                        context,
                        backdrops.first.filePath,
                        size: 'w780/',
                      ),
                      icon: PhosphorIcons.images(),
                      title: tr('backdrop_plural', namedArgs: <String, String>{
                        'backdrop': '${backdrops.length}',
                      }),
                      onTap: () => _openGallery(backdrops: backdrops),
                    ),
                  if (backdrops.isNotEmpty && posters.isNotEmpty)
                    const SizedBox(height: AppSpace.md),
                  if (posters.isNotEmpty)
                    ArtworkCard(
                      url: tmdbImageUrl(
                        context,
                        posters.first.posterPath,
                        size: 'w780/',
                      ),
                      icon: PhosphorIcons.images(),
                      title: tr('poster_plural', namedArgs: <String, String>{
                        'poster': '${posters.length}',
                      }),
                      onTap: () => _openGallery(posters: posters),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }

  void _openGallery({List<Backdrops>? backdrops, List<Posters>? posters}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HeroPhotoView(
          backdrops: backdrops,
          posters: posters,
          name: _item.title,
          imageType: backdrops != null ? 'backdrop' : 'poster',
        ),
      ),
    );
  }

  List<Widget> _about(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    Widget heading(String title) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            gutter,
            AppSpace.xl,
            gutter,
            AppSpace.md,
          ),
          child: Text(
            title,
            style: AppType.sectionHeader.copyWith(color: palette.foreground),
          ),
        );
    return <Widget>[
      SliverToBoxAdapter(
        child: FutureBuilder<Credits>(
          future: _credits,
          builder: (context, snapshot) {
            final credits = snapshot.data;
            final cast = credits?.cast ?? const <Cast>[];
            if (snapshot.connectionState != ConnectionState.done) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: const DetailsBlock(height: 120),
              );
            }
            if (cast.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: tr('cast'),
                  onSeeAll:
                      credits == null ? null : () => _openCredits(credits),
                ),
                CastRow(cast: cast),
              ],
            );
          },
        ),
      ),
      if (_isMovie)
        SliverToBoxAdapter(
          child: FutureBuilder<BelongsToCollection?>(
            future: _collection,
            builder: (context, snapshot) {
              final collection = snapshot.data;
              if (collection == null) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  AppSpace.xl,
                  gutter,
                  0,
                ),
                child: ArtworkCard(
                  url: tmdbImageUrl(
                    context,
                    collection.backdropPath ?? collection.posterPath,
                    size: 'w780/',
                  ),
                  aspectRatio: 21 / 9,
                  title: collection.name ?? tr('view_collection'),
                  subtitle: tr('view_collection'),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => CollectionDetailsWidget(
                        belongsToCollection: collection,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            heading(tr(_isMovie ? 'movie_info' : 'tv_series_info')),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _isMovie ? _movieInfo(context) : _seriesInfo(context),
            ),
          ],
        ),
      ),
      SliverToBoxAdapter(
        child: FutureBuilder<ExternalLinks>(
          future: _links,
          builder: (context, snapshot) {
            final links = snapshot.data;
            if (links == null || !SocialLinks.any(links)) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                heading(tr('social_media_links')),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: SocialLinks(links: links),
                ),
              ],
            );
          },
        ),
      ),
    ];
  }

  void _openCredits(Credits credits) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _isMovie
            ? MovieCastAndCrew(credits: credits)
            : TVDetailCastAndCrew(id: _item.id, passedFrom: 'tv_detail'),
      ),
    );
  }

  Widget _info(
    BuildContext context,
    AsyncSnapshot<Object?> snapshot,
    List<(String, String?)> Function() rows,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const DetailsBlock(height: 160);
    }
    if (snapshot.hasError) {
      return DetailsMessage(message: tr('check_connection'), onRetry: _retry);
    }
    return InfoTable(
      rows: <(String, String)>[
        for (final (label, value) in rows())
          if ((value ?? '').trim().isNotEmpty) (label, value!.trim()),
      ],
    );
  }

  String? _date(String? value) {
    final date = DateTime.tryParse(value ?? '');
    if (date == null) return null;
    return DateFormat.yMMMMd(Localizations.localeOf(context).toString())
        .format(date);
  }

  String? _joined(Iterable<String?>? values) {
    final list = (values ?? const <String?>[])
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return list.isEmpty ? null : list.join(', ');
  }

  Widget _movieInfo(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    return FutureBuilder<MovieDetails>(
      future: _movie,
      builder: (context, snapshot) => _info(context, snapshot, () {
        final details = snapshot.data!;
        final runtime = details.runtime ?? 0;
        return <(String, String?)>[
          (tr('original_title'), details.originalTitle),
          (tr('status'), details.status),
          (tr('release_date'), _date(_item.releaseDate)),
          (
            tr('runtime'),
            runtime > 0 ? formatRuntime(Duration(minutes: runtime)) : null,
          ),
          (
            tr('original_language'),
            _item.movie?.originalLanguage?.toUpperCase(),
          ),
          (
            tr('spoken_language'),
            _joined(details.spokenLanguages?.map((l) => l.englishName)),
          ),
          (
            tr('budget'),
            (details.budget ?? 0) > 0 ? currency.format(details.budget) : null,
          ),
          (
            tr('revenue'),
            (details.revenue ?? 0) > 0
                ? currency.format(details.revenue)
                : null,
          ),
          (tr('tagline'), details.tagline),
          (
            tr('production_companies'),
            _joined(details.productionCompanies?.map((c) => c.name)),
          ),
          (
            tr('production_countries'),
            _joined(details.productionCountries?.map((c) => c.name)),
          ),
        ];
      }),
    );
  }

  Widget _seriesInfo(BuildContext context) {
    return FutureBuilder<TVDetails>(
      future: _series,
      builder: (context, snapshot) => _info(context, snapshot, () {
        final details = snapshot.data!;
        return <(String, String?)>[
          (tr('status'), details.status),
          (tr('first_aired'), _date(_item.releaseDate)),
          (
            tr('seasons'),
            (details.numberOfSeasons ?? 0) > 0
                ? '${details.numberOfSeasons}'
                : null,
          ),
          (
            tr('episodes'),
            (details.numberOfEpisodes ?? 0) > 0
                ? '${details.numberOfEpisodes}'
                : null,
          ),
          (
            tr('networks'),
            _joined(details.networks?.map((n) => n.networkName))
          ),
          (
            tr('original_language'),
            _item.series?.originalLanguage?.toUpperCase(),
          ),
          (
            tr('spoken_language'),
            _joined(details.spokenLanguages?.map((l) => l.englishName)),
          ),
          (tr('tagline'), details.tagline),
          (
            tr('production_companies'),
            _joined(details.productionCompanies?.map((c) => c.name)),
          ),
          (
            tr('production_countries'),
            _joined(details.productionCountries?.map((c) => c.name)),
          ),
        ];
      }),
    );
  }
}

/// The title's backdrop, fading into the page at whatever height the header
/// has collapsed to, with a shade at the top for the status bar and the back
/// button. As it collapses the artwork rises a little slower than the page
/// and gives way to the page's colour.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final current = settings?.currentExtent ?? constraints.maxHeight;
        final max = settings?.maxExtent ?? current;
        final min = settings?.minExtent ?? 0;
        final shown =
            max <= min ? 1.0 : ((current - min) / (max - min)).clamp(0.0, 1.0);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: (current - max) / 2,
                left: 0,
                right: 0,
                height: max,
                child: MediaArt(
                  item: item,
                  path: item.backdropPath ?? item.posterPath,
                  width: MediaQuery.sizeOf(context).width,
                  size: ArtSize.backdrop,
                  alignment: Alignment.topCenter,
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0x8C000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0, 0.25),
                    end: Alignment.bottomCenter,
                    // Solid for the last few pixels, so no seam shows where
                    // the artwork meets the page.
                    stops: const <double>[0, .94, 1],
                    colors: <Color>[
                      palette.scrim(0),
                      palette.page,
                      palette.page,
                    ],
                  ),
                ),
              ),
              if (shown < 1) ColoredBox(color: palette.scrim(1 - shown)),
            ],
          ),
        );
      },
    );
  }
}

/// A round button over the artwork: translucent black with a white icon,
/// then the page's own ink once the artwork has scrolled away.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onArtwork,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool onArtwork;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onArtwork
            ? const Color(0x61000000)
            : palette.page.withValues(alpha: 0),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        color: onArtwork ? const Color(0xFFFFFFFF) : palette.foreground,
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

/// The main button, full width, with how far in the viewer is under it.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.label,
    required this.resume,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final ResumePoint? resume;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final resume = this.resume;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: PillButton(
            label: label,
            icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
            primary: true,
            busy: busy,
            height: 48,
            onPressed: busy ? null : onPressed,
          ),
        ),
        if (resume != null) ...<Widget>[
          const SizedBox(height: AppSpace.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: resume.progress,
                    minHeight: 3,
                    backgroundColor: palette.idleFill,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Text(
                tr('time_left', namedArgs: <String, String>{
                  'time': formatRuntime(Duration(seconds: resume.remaining)),
                }),
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader({
    required this.tab,
    required this.background,
    required this.hairline,
    required this.onSelect,
  });

  final DetailsTab tab;
  final Color background;
  final Color hairline;
  final ValueChanged<DetailsTab> onSelect;

  static const _height = FilterChips.height + AppSpace.md * 2;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final labels = <DetailsTab, String>{
      DetailsTab.moreLikeThis: tr('more_like_this'),
      DetailsTab.trailers: tr('trailers_and_more'),
      DetailsTab.about: tr('details'),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent || shrinkOffset > 0 ? hairline : background,
          ),
        ),
      ),
      child: Center(
        child: FilterChips(
          chips: <FilterChipSpec>[
            for (final option in DetailsTab.values)
              FilterChipSpec(
                label: labels[option]!,
                selected: option == tab,
                onTap: () => onSelect(option),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeader oldDelegate) =>
      tab != oldDelegate.tab ||
      background != oldDelegate.background ||
      hairline != oldDelegate.hairline;
}
