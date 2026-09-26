import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../api/endpoints.dart';
import '../../constants/api_constants.dart';
import '../../constants/app_constants.dart';
import '../../functions/function.dart';
import '../../functions/network.dart';
import '../../models/tv.dart';
import '../../models/tv_stream_metadata.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../ui_components/app_ui_components.dart';
import '../common/player/player_sheet_ui.dart';

Future<TVStreamMetadata?> showTVEpisodePickerSheet(
  BuildContext context, {
  required TV series,
}) {
  return showModalBottomSheet<TVStreamMetadata>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
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

      final seasons = (details.seasons ?? const <Seasons>[])
          .where(
            (season) =>
                season.seasonNumber != null && (season.episodeCount ?? 0) > 0,
          )
          .toList()
        ..sort(
          (a, b) => a.seasonNumber!.compareTo(b.seasonNumber!),
        );
      if (seasons.isEmpty) {
        setState(() {
          _seasons = const [];
          _loadingSeries = false;
          _errorMessage = tr('no_season_tv');
        });
        return;
      }

      final initialSeason = seasons.firstWhere(
        (season) => season.seasonNumber == 1,
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
    final selectedSeason = _selectedSeason;
    return PlayerSheetScaffold(
      icon: PhosphorIcons.playlist(),
      title: widget.series.name ?? tr('tv_series'),
      subtitle: selectedSeason == null
          ? tr('select_season')
          : tr(
              'season_episodes',
              namedArgs: {'season': '${selectedSeason.seasonNumber}'},
            ),
      actions: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.pop(context),
          icon: Icon(PhosphorIcons.x()),
        ),
      ],
      child: _loadingSeries
          ? const Center(child: CircularProgressIndicator())
          : _seasons.isEmpty
              ? _PickerMessage(
                  message: _errorMessage ?? tr('no_season_tv'),
                  onRetry: _loadSeries,
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 66,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                        itemCount: _seasons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final season = _seasons[index];
                          final selected = season.seasonNumber ==
                              _selectedSeason?.seasonNumber;
                          return _SeasonSelector(
                            season: season,
                            selected: selected,
                            enabled: !_loadingEpisodes,
                            onTap: () => _loadSeason(season),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildEpisodeList()),
                  ],
                ),
    );
  }

  Widget _buildEpisodeList() {
    if (_loadingEpisodes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_episodes.isEmpty) {
      return _PickerMessage(
        message: _errorMessage ?? tr('no_episodes'),
        onRetry: _selectedSeason == null
            ? null
            : () => _loadSeason(_selectedSeason!),
      );
    }

    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      itemCount: _episodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final episode = _episodes[index];
        final details = <String>[
          episodeSeasonFormatter(
            episode.episodeNumber!,
            episode.seasonNumber!,
          ),
          if (episode.voteAverage != null && episode.voteAverage! > 0)
            '\u2605 ${episode.voteAverage!.toStringAsFixed(1)}',
          if ((episode.airDate ?? '').isNotEmpty) episode.airDate!,
        ];
        return PlayerChoiceCard(
          title: episode.name ?? '${tr('episodes')} ${episode.episodeNumber}',
          subtitle: details.join('  \u2022  '),
          description: episode.overview,
          onTap: () => _selectEpisode(episode),
          trailing: Icon(
            PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
            color: Theme.of(context).colorScheme.primary,
          ),
          thumbnail: PlayerThumbnail(
            width: 124,
            height: 76,
            child: _EpisodeImage(path: episode.stillPath),
          ),
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

class _EpisodeImage extends StatelessWidget {
  const _EpisodeImage({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) return Icon(PhosphorIcons.filmStrip());
    final settings = context.watch<SettingsProvider>();
    final proxy = context.watch<AppDependencyProvider>().tmdbProxy;
    return CachedNetworkImage(
      cacheManager: cacheProp(),
      imageUrl:
          '${buildImageUrl(TMDB_BASE_IMAGE_URL, proxy, settings.enableProxy, context)}w300$path',
      fit: BoxFit.cover,
      placeholder: (_, __) => const AppCachedImagePlaceholder(),
      errorWidget: (_, __, ___) => Icon(PhosphorIcons.filmStrip()),
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  const _SeasonSelector({
    required this.season,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Seasons season;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final seasonNumber = season.seasonNumber ?? 0;
    final title = season.name?.trim().isNotEmpty == true
        ? season.name!.trim()
        : '${tr('seasons')} $seasonNumber';
    final background = selected
        ? colors.primary
        : colors.surfaceContainerHighest.withValues(alpha: .7);
    final foreground = selected ? colors.onPrimary : colors.onSurface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? colors.primary
              : colors.outlineVariant.withValues(alpha: .7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled && !selected ? onTap : null,
        child: SizedBox(
          width: 142,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (selected ? colors.onPrimary : colors.primary)
                        .withValues(alpha: selected ? .18 : .12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$seasonNumber',
                    style: TextStyle(
                      color: selected ? colors.onPrimary : colors.primary,
                      fontFamily: 'FigtreeSB',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontFamily: 'FigtreeSB',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${season.episodeCount ?? 0} ${tr('episodes')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: .72),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                    color: colors.onPrimary,
                    size: 17,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.warningCircle(),
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: Icon(PhosphorIcons.arrowClockwise()),
                label: Text(tr('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
