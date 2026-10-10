import 'package:flixquest/widgets/adsterra_playback_gate.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/app_constants.dart';
import '../../../models/recently_watched.dart';
import '../../../models/tv_stream_metadata.dart';
import '../../../provider/app_dependency_provider.dart';
import '../../../provider/recently_watched_provider.dart';
import '../../../provider/settings_provider.dart';
import '../../../ui_components/app_ui_components.dart';
import '../../../api/endpoints.dart';
import '../../../functions/network.dart';
import '../../tv/tv_video_loader.dart';
import 'player_sheet_ui.dart';
import '../../../design/app_palette.dart';
import '../../../design/app_tokens.dart';
import '../../../mobile/widgets/episode_row.dart';

class PlayerEpisodeSelection {
  int? _browsedSeasonNumber;

  PlayerEpisodeSelection(this._browsedSeasonNumber);

  Future<void> showEpisodeSelectionBottomSheet({
    required BuildContext context,
    required List<Color> colors,
    required TVStreamMetadata tvMetadata,
    required Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
  }) {
    final episodes = tvMetadata.seasonEpisodes;
    debugPrint(
      '[PlayerContentMenu] episode sheet requested '
      'contextMounted=${context.mounted} episodes=${episodes?.length ?? 0}',
    );
    if (episodes == null || episodes.isEmpty) {
      debugPrint('[PlayerContentMenu] episode sheet skipped: no episodes');
      return Future.value();
    }
    final playerContext = context;
    final seasonNumber = _browsedSeasonNumber ?? tvMetadata.seasonNumber ?? 0;

    debugPrint(
      '[PlayerContentMenu] pushing episode modal season=$seasonNumber',
    );
    return showPlayerSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) {
        debugPrint(
          '[PlayerContentMenu] episode modal builder '
          'sheetContext=${identityHashCode(sheetContext)}',
        );
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {},
          child: DraggableScrollableSheet(
            initialChildSize: .82,
            minChildSize: .55,
            maxChildSize: .95,
            expand: false,
            snap: true,
            snapSizes: const [.55, .82, .95],
            builder: (context, scrollController) => PlayerSheetScaffold(
              title: tr(
                'season_episodes',
                namedArgs: {'season': '$seasonNumber'},
              ),
              subtitle: tr(
                'episodes_count',
                namedArgs: {'count': '${episodes.length}'},
              ),
              actions: [
                if ((tvMetadata.allSeasons?.length ?? 0) > 1)
                  IconButton(
                    tooltip: tr('select_season'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showSeasonSelectionBottomSheet(
                        context: playerContext,
                        colors: colors,
                        tvMetadata: tvMetadata,
                        onSaveProgress: onSaveProgress,
                        closePlayer: closePlayer,
                        useTvPlayer: useTvPlayer,
                      );
                    },
                    icon: Icon(PhosphorIcons.stack()),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: Icon(PhosphorIcons.x()),
                ),
              ],
              child: Consumer<RecentProvider>(
                builder: (context, recentProvider, _) => ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    final current =
                        episode.episodeNumber == tvMetadata.episodeNumber &&
                            episode.seasonNumber == tvMetadata.seasonNumber;
                    final recent = recentProvider.episodes
                        .cast<RecentEpisode?>()
                        .firstWhere(
                          (item) => item?.id == episode.episodeId,
                          orElse: () => null,
                        );
                    final total =
                        (recent?.elapsed ?? 0) + (recent?.remaining ?? 0);
                    final progress = total <= 0
                        ? null
                        : (recent!.elapsed! / total).clamp(0.0, 1.0);
                    return _buildEpisodeListItem(
                      context,
                      episode,
                      current,
                      progress != null,
                      (progress ?? 0) * 100,
                      colors,
                      current
                          ? null
                          : () {
                              onSaveProgress();
                              Navigator.pop(sheetContext);
                              closePlayer();
                              Navigator.pushReplacement(
                                playerContext,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdsterraPlaybackGate.buildLoader(context,
                                      television: useTvPlayer,
                                      builder: (context) => TVVideoLoader(
                                            download: false,
                                            useTvPlayer: useTvPlayer,
                                            metadata: TVStreamMetadata(
                                              elapsed: null,
                                              episodeId: episode.episodeId,
                                              episodeName: episode.episodeName,
                                              episodeNumber:
                                                  episode.episodeNumber,
                                              posterPath: tvMetadata.posterPath,
                                              backdropPath: episode.stillPath ??
                                                  tvMetadata.backdropPath,
                                              seasonNumber:
                                                  episode.seasonNumber,
                                              seriesName: tvMetadata.seriesName,
                                              tvId: tvMetadata.tvId,
                                              airDate: episode.airDate,
                                              seasonEpisodes: episodes,
                                              allSeasons: tvMetadata.allSeasons,
                                            ),
                                          )),
                                ),
                              );
                            },
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEpisodeListItem(
    BuildContext context,
    EpisodeMetadata episode,
    bool isCurrentEpisode,
    bool hasProgress,
    double progressPercentage,
    List<Color> colors,
    VoidCallback? onTap,
  ) {
    final details = <String>[];
    if (episode.voteAverage != null && episode.voteAverage! > 0) {
      details.add('★ ${episode.voteAverage!.toStringAsFixed(1)}');
    }
    if (episode.runtime != null) details.add('${episode.runtime}m');
    return PlayerChoiceCard(
      title: '${episode.episodeNumber}. ${episode.episodeName}',
      subtitle: details.isEmpty ? null : details.join('  •  '),
      description: episode.overview,
      selected: isCurrentEpisode,
      progress: hasProgress ? progressPercentage / 100 : null,
      onTap: onTap,
      thumbnail: PlayerThumbnail(
        width: 124,
        height: 76,
        child: episode.stillPath == null
            ? Icon(PhosphorIcons.filmStrip())
            : CachedNetworkImage(
                cacheManager: cacheProp(),
                imageUrl: 'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                fit: BoxFit.cover,
                placeholder: (_, __) => const AppCachedImagePlaceholder(),
                errorWidget: (_, __, ___) => Icon(PhosphorIcons.filmStrip()),
              ),
      ),
    );
  }

  void showSeasonSelectionBottomSheet({
    required BuildContext context,
    required List<Color> colors,
    required TVStreamMetadata tvMetadata,
    required Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
  }) {
    final seasons = tvMetadata.allSeasons;
    if (seasons == null || seasons.isEmpty) return;
    final playerContext = context;

    showPlayerSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .5,
        maxChildSize: .92,
        expand: false,
        snap: true,
        snapSizes: const [.5, .72, .92],
        builder: (context, scrollController) => PlayerSheetScaffold(
          title: tr('select_season'),
          subtitle: '${seasons.length} ${tr('select_season')}',
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(sheetContext),
              icon: Icon(PhosphorIcons.x()),
            ),
          ],
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: seasons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final season = seasons[index];
              final current = season.seasonNumber == tvMetadata.seasonNumber;
              return _buildSeasonListItem(
                context,
                season,
                current,
                colors,
                () async {
                  Navigator.pop(sheetContext);
                  final navigator =
                      Navigator.of(playerContext, rootNavigator: true);
                  navigator.push(
                    DialogRoute<void>(
                      context: playerContext,
                      barrierDismissible: false,
                      // The season's episodes, pulsing, until they come.
                      // In the player's theme, like the sheets around it.
                      builder: (_) => PlayerTheme(
                        child: Builder(
                          builder: (context) => PopScope(
                        canPop: false,
                        child: Dialog(
                          backgroundColor:
                              BetterPlayerPanelColors.of(context).panel,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    tr('loading_episodes'),
                                    style: AppType.cardTitle.copyWith(
                                      fontSize: 16,
                                      color: AppPalette.of(context).foreground,
                                    ),
                                  ),
                                ),
                                const EpisodeListSkeleton(count: 2),
                              ],
                            ),
                          ),
                        ),
                        ),
                          ),
                        ),
                    ),
                  );
                  await fetchEpisodesForSeason(
                    playerContext,
                    season.seasonNumber,
                    tvMetadata,
                    colors,
                  );
                  if (navigator.canPop()) navigator.pop();
                  if (!playerContext.mounted) return;
                  await showEpisodeSelectionBottomSheet(
                    context: playerContext,
                    colors: colors,
                    tvMetadata: tvMetadata,
                    onSaveProgress: onSaveProgress,
                    closePlayer: closePlayer,
                    useTvPlayer: useTvPlayer,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonListItem(
    BuildContext context,
    SeasonMetadata season,
    bool isCurrentSeason,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return PlayerChoiceCard(
      title: season.seasonName,
      subtitle: tr(
        'episodes_count',
        namedArgs: {'count': '${season.episodeCount}'},
      ),
      description: season.overview,
      selected: isCurrentSeason,
      onTap: onTap,
      thumbnail: PlayerThumbnail(
        width: 64,
        height: 96,
        child: season.posterPath == null
            ? Icon(PhosphorIcons.television())
            : CachedNetworkImage(
                cacheManager: cacheProp(),
                imageUrl: 'https://image.tmdb.org/t/p/w185${season.posterPath}',
                fit: BoxFit.cover,
                placeholder: (_, __) => const AppCachedImagePlaceholder(),
                errorWidget: (_, __, ___) => Icon(PhosphorIcons.television()),
              ),
      ),
    );
  }

  Future<bool> fetchEpisodesForSeason(
    BuildContext context,
    int seasonNumber,
    TVStreamMetadata tvMetadata,
    List<Color> colors,
  ) async {
    try {
      final isProxyEnabled =
          Provider.of<SettingsProvider>(context, listen: false).enableProxy;
      final proxyUrl =
          Provider.of<AppDependencyProvider>(context, listen: false).tmdbProxy;
      final currentLanguage =
          Provider.of<SettingsProvider>(context, listen: false).appLanguage;

      var loaded = false;
      await fetchTVDetails(
        Endpoints.getSeasonDetails(
          tvMetadata.tvId!,
          seasonNumber,
          currentLanguage,
        ),
        isProxyEnabled,
        proxyUrl,
      ).then((value) {
        if (value.episodes != null && value.episodes!.isNotEmpty) {
          loaded = true;
          // Update the browsed season number to show in the title
          _browsedSeasonNumber = seasonNumber;

          // DON'T update tvMetadata.seasonNumber here!
          // That field represents the CURRENTLY PLAYING episode's season,
          // not the season being browsed in the list.
          // Only update the episodes list.
          tvMetadata.seasonEpisodes = value.episodes!
              .map((episode) => EpisodeMetadata(
                    episodeId: episode.episodeId ?? 0,
                    episodeName:
                        episode.name ?? 'Episode ${episode.episodeNumber}',
                    episodeNumber: episode.episodeNumber ?? 0,
                    seasonNumber: seasonNumber, // Use the fetched season number
                    stillPath: episode.stillPath,
                    airDate: episode.airDate,
                    runtime: null,
                    overview: episode.overview,
                    voteAverage: episode.voteAverage,
                  ))
              .toList();
        }
      });
      return loaded;
    } catch (e) {
      debugPrint('Failed to fetch episodes for season $seasonNumber: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed_load_season_episodes')),
          ),
        );
      }
      return false;
    }
  }
}
