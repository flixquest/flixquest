import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../api/endpoints.dart';
import '../../catalog/details_controller.dart';
import '../../catalog/details_play.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../functions/network.dart';
import '../../mobile/widgets/episode_row.dart';
import '../../mobile/widgets/filter_chips.dart';
import '../../mobile/widgets/page_kit.dart';
import '../../models/recently_watched.dart';
import '../../models/tv.dart';
import '../../models/tv_stream_metadata.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/recently_watched_provider.dart';
import '../../provider/settings_provider.dart';

/// The episodes of [series] to choose one to play, a season at a time.
/// Resolves to what the player needs for the one chosen, or null.
Future<TVStreamMetadata?> showTVEpisodePickerSheet(
  BuildContext context, {
  required TV series,
}) {
  return showAppSheet<TVStreamMetadata>(
    context,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: .84,
      minChildSize: .58,
      maxChildSize: .95,
      expand: false,
      snap: true,
      snapSizes: const [.58, .84, .95],
      builder: (context, scrollController) => _TVEpisodePickerSheet(
        series: series,
        scrollController: scrollController,
      ),
    ),
  );
}

class _TVEpisodePickerSheet extends StatefulWidget {
  const _TVEpisodePickerSheet({
    required this.series,
    required this.scrollController,
  });

  final TV series;
  final ScrollController scrollController;

  @override
  State<_TVEpisodePickerSheet> createState() => _TVEpisodePickerSheetState();
}

class _TVEpisodePickerSheetState extends State<_TVEpisodePickerSheet> {
  List<Seasons> _seasons = const [];
  List<EpisodeList> _episodes = const [];
  Seasons? _selectedSeason;
  bool _loadingSeries = true;
  bool _loadingEpisodes = false;
  String? _errorMessage;
  bool _started = false;
  int _seasonRequest = 0;

  MediaItem get _item => MediaItem.fromSeries(widget.series);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final id = widget.series.id;
    if (id == null) {
      setState(() {
        _loadingSeries = false;
        _errorMessage = tr('no_season_tv');
      });
      return;
    }

    setState(() {
      _loadingSeries = true;
      _errorMessage = null;
    });

    try {
      final settings = context.read<SettingsProvider>();
      final proxy = context.read<AppDependencyProvider>().tmdbProxy;
      final details = await fetchTVDetails(
        Endpoints.tvDetailsUrl(id, settings.appLanguage),
        settings.enableProxy,
        proxy,
      );
      if (!mounted) return;

      // Specials last, as on the series' page; seasons with no episodes
      // aren't offered.
      final seasons = MediaDetailsData(
        item: _item,
        seriesDetails: details,
        recommendations: const <MediaItem>[],
      )
          .seasons
          .where(
            (season) =>
                season.seasonNumber != null && (season.episodeCount ?? 0) > 0,
          )
          .toList(growable: false);
      if (seasons.isEmpty) {
        setState(() {
          _seasons = const [];
          _loadingSeries = false;
          _errorMessage = tr('no_season_tv');
        });
        return;
      }

      // The season being watched, else the first.
      final recent = context.read<RecentProvider?>();
      final watching = initialSeasonNumber(
        seasons,
        ResumePoint.forItem(
          _item,
          movies: const <RecentMovie>[],
          episodes: recent?.episodes ?? const <RecentEpisode>[],
        ),
      );
      final initialSeason = seasons.firstWhere(
        (season) => season.seasonNumber == watching,
        orElse: () => seasons.first,
      );
      setState(() {
        _seasons = seasons;
        _selectedSeason = initialSeason;
        _loadingSeries = false;
      });
      await _loadSeason(initialSeason);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSeries = false;
        _errorMessage = tr('failed_load_season_episodes');
      });
    }
  }

  Future<void> _loadSeason(Seasons season) async {
    final id = widget.series.id;
    final seasonNumber = season.seasonNumber;
    if (id == null || seasonNumber == null) return;

    final request = ++_seasonRequest;
    setState(() {
      _selectedSeason = season;
      _episodes = const [];
      _loadingEpisodes = true;
      _errorMessage = null;
    });

    try {
      final settings = context.read<SettingsProvider>();
      final proxy = context.read<AppDependencyProvider>().tmdbProxy;
      final details = await fetchTVDetails(
        Endpoints.getSeasonDetails(id, seasonNumber, settings.appLanguage),
        settings.enableProxy,
        proxy,
      );
      if (!mounted || request != _seasonRequest) return;

      final episodes = (details.episodes ?? const <EpisodeList>[])
          .where(
            (episode) =>
                episode.episodeId != null &&
                episode.episodeNumber != null &&
                episode.seasonNumber != null,
          )
          .toList()
        ..sort(
          (a, b) => a.episodeNumber!.compareTo(b.episodeNumber!),
        );
      setState(() {
        _episodes = episodes;
        _loadingEpisodes = false;
        _errorMessage = episodes.isEmpty ? tr('no_episodes') : null;
      });
    } catch (_) {
      if (!mounted || request != _seasonRequest) return;
      setState(() {
        _loadingEpisodes = false;
        _errorMessage = tr('failed_load_season_episodes');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                tr('choose_episode').toUpperCase(),
                style: AppType.kicker.copyWith(color: palette.mutedText),
              ),
              const SizedBox(height: 2),
              Text(
                widget.series.name ?? tr('tv_series'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sectionHeader.copyWith(
                  fontFamily: AppType.bold,
                  color: palette.foreground,
                ),
              ),
            ],
          ),
        ),
        if (_loadingSeries)
          const Expanded(child: _PickerSkeleton(seasons: true))
        else if (_seasons.isEmpty)
          Expanded(
            child: EmptyState(
              icon: PhosphorIcons.television(),
              title: _errorMessage ?? tr('no_season_tv'),
              actionLabel: tr('retry'),
              actionIcon: PhosphorIcons.arrowClockwise(),
              onAction: _loadSeries,
            ),
          )
        else ...<Widget>[
          if (_seasons.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: FilterChips(
                chips: <FilterChipSpec>[
                  for (final season in _seasons)
                    FilterChipSpec(
                      label: seasonDisplayName(season),
                      selected:
                          season.seasonNumber == _selectedSeason?.seasonNumber,
                      onTap: () {
                        if (season.seasonNumber ==
                            _selectedSeason?.seasonNumber) {
                          return;
                        }
                        _loadSeason(season);
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: SkeletonSwitcher(
              loading: _loadingEpisodes,
              skeleton: const _PickerSkeleton(seasons: false),
              child: _buildEpisodeList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodeList() {
    if (_episodes.isEmpty) {
      return EmptyState(
        icon: PhosphorIcons.filmStrip(),
        title: _errorMessage ?? tr('no_episodes'),
        actionLabel: _selectedSeason == null ? null : tr('retry'),
        actionIcon: PhosphorIcons.arrowClockwise(),
        onAction: _selectedSeason == null
            ? null
            : () => _loadSeason(_selectedSeason!),
      );
    }
    final watched =
        context.watch<RecentProvider?>()?.episodes ?? const <RecentEpisode>[];
    final item = _item;
    return ListView.builder(
      controller: widget.scrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + AppSpace.xxl,
      ),
      itemCount: _episodes.length,
      itemBuilder: (context, index) {
        final episode = _episodes[index];
        return EpisodeRow(
          series: item,
          episode: episode,
          aired: hasAired(episode),
          progress: episodeProgress(
            watched,
            seriesId: item.id,
            season: episode.seasonNumber ?? 0,
            episode: episode.episodeNumber ?? -1,
          ),
          canPlay: true,
          canDownload: false,
          onPlay: () => _selectEpisode(episode),
        );
      },
    );
  }

  void _selectEpisode(EpisodeList episode) {
    Navigator.pop(
      context,
      TVStreamMetadata(
        elapsed: null,
        episodeId: episode.episodeId,
        episodeName: episode.name,
        episodeNumber: episode.episodeNumber,
        posterPath: widget.series.posterPath,
        backdropPath: episode.stillPath ?? widget.series.backdropPath,
        seasonNumber: episode.seasonNumber,
        seriesName: widget.series.name,
        tvId: widget.series.id,
        airDate: episode.airDate,
        seasonEpisodes: _episodes
            .map(EpisodeMetadata.fromEpisodeList)
            .toList(growable: false),
        allSeasons:
            _seasons.map(SeasonMetadata.fromSeason).toList(growable: false),
      ),
    );
  }
}

/// The sheet's shape while it loads: the season chips (when they're still
/// coming) and the first episodes.
class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton({required this.seasons});

  final bool seasons;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SkeletonPulse(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (seasons)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  gutter,
                  0,
                  gutter,
                  AppSpace.sm,
                ),
                child: Row(
                  children: <Widget>[
                    for (final width in const <double>[86, 86, 86])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: AppSpace.sm,
                        ),
                        child: SkeletonBlock(
                          width: width,
                          height: FilterChips.height,
                          radius: AppRadii.chip,
                        ),
                      ),
                  ],
                ),
              ),
            const EpisodeListSkeleton(count: 5),
          ],
        ),
      ),
    );
  }
}
