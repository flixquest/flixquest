import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';
import '../../../models/tv_stream_metadata.dart';
import '../../../ui_components/app_ui_components.dart';
import '../../tv/tv_video_loader.dart';
import 'player_sheet_ui.dart';

class PlayerNextEpisodeWidget {
  Widget buildNextEpisodeFloatingButton({
    required BuildContext context,
    required TVStreamMetadata tvMetadata,
    required bool showNextEpisodeButton,
    required bool controlsVisible,
    required Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
  }) {
    final episodes = tvMetadata.seasonEpisodes;
    if (episodes == null) {
      debugPrint(
        '[NextEpisodeDebug][floating_build_skipped] reason=no_episodes',
      );
      return const SizedBox.shrink();
    }
    final currentIndex = episodes.indexWhere(
      (episode) =>
          episode.episodeNumber == tvMetadata.episodeNumber &&
          episode.seasonNumber == tvMetadata.seasonNumber,
    );
    if (currentIndex < 0 || currentIndex >= episodes.length - 1) {
      debugPrint(
        '[NextEpisodeDebug][floating_build_skipped] '
        'reason=no_matching_next current=S${tvMetadata.seasonNumber}'
        'E${tvMetadata.episodeNumber} currentIndex=$currentIndex '
        'episodes=${episodes.length}',
      );
      return const SizedBox.shrink();
    }
    final nextEpisode = episodes[currentIndex + 1];
    debugPrint(
      '[NextEpisodeDebug][floating_build] '
      'currentIndex=$currentIndex next=S${nextEpisode.seasonNumber}'
      'E${nextEpisode.episodeNumber} show=$showNextEpisodeButton '
      'controlsVisible=$controlsVisible',
    );
    final navigator = Navigator.of(context);
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonSurface = Color.alphaBlend(
      colors.primary.withValues(alpha: .10),
      colors.surfaceContainerHigh,
    );

    void playNextEpisode() {
      onSaveProgress();
      closePlayer();
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => TVVideoLoader(
            download: false,
            useTvPlayer: useTvPlayer,
            metadata: _metadataForEpisode(nextEpisode, tvMetadata),
          ),
        ),
      );
    }

    return AnimatedPositioned(
      key: const ValueKey('next_episode_teaser_position'),
      right: 16,
      top: safeTop + (controlsVisible ? 72 : 16),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: !showNextEpisodeButton,
        child: AnimatedSlide(
          offset: showNextEpisodeButton ? Offset.zero : const Offset(.2, 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: showNextEpisodeButton ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: Material(
              key: const ValueKey('next_episode_teaser'),
              color: buttonSurface,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shadowColor: colors.shadow.withValues(alpha: .45),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: .38),
                ),
              ),
              child: InkWell(
                onTap: playNextEpisode,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          PhosphorIcons.skipForward(PhosphorIconsStyle.fill),
                          color: colors.primary,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${tr('next_episode')} · E${nextEpisode.episodeNumber}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                          fontFamily: 'FigtreeSB',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showNextEpisodeCountdown({
    required BuildContext context,
    required EpisodeMetadata nextEpisode,
    required List<Color> colors,
    required TVStreamMetadata tvMetadata,
    required Function() onSaveProgress,
    required Function() closePlayer,
    bool useTvPlayer = false,
  }) {
    var countdown = 10;
    Timer? timer;
    var dismissed = false;
    final navigator = Navigator.of(context);

    debugPrint(
      '[Player] Opening next-episode countdown for '
      'S${nextEpisode.seasonNumber}E${nextEpisode.episodeNumber}',
    );

    void play(BuildContext dialogContext) {
      if (dismissed) return;
      dismissed = true;
      timer?.cancel();
      if (Navigator.canPop(dialogContext)) Navigator.pop(dialogContext);
      onSaveProgress();
      closePlayer();
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => TVVideoLoader(
            download: false,
            useTvPlayer: useTvPlayer,
            metadata: _metadataForEpisode(nextEpisode, tvMetadata),
          ),
        ),
      );
    }

    final dialog = showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (timer == null) {
            debugPrint(
              '[NextEpisodeDebug][countdown_builder] '
              'mounted=${dialogContext.mounted} '
              'context=${identityHashCode(dialogContext)}',
            );
          }
          timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (dismissed) return;
            if (countdown <= 1) {
              play(dialogContext);
            } else if (dialogContext.mounted) {
              setDialogState(() => countdown--);
            }
          });
          return Dialog(
            alignment: Alignment.bottomCenter,
            insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            PhosphorIcons.skipForward(
                              PhosphorIconsStyle.fill,
                            ),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            tr('next_episode'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    PlayerChoiceCard(
                      title:
                          '${nextEpisode.episodeNumber}. ${nextEpisode.episodeName}',
                      subtitle: tr(
                        'playing_in_seconds',
                        namedArgs: {'seconds': '$countdown'},
                      ),
                      description: nextEpisode.overview,
                      selected: true,
                      onTap: null,
                      thumbnail: PlayerThumbnail(
                        width: 112,
                        height: 70,
                        child: nextEpisode.stillPath == null
                            ? Icon(PhosphorIcons.filmStrip())
                            : CachedNetworkImage(
                                cacheManager: cacheProp(),
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w300${nextEpisode.stillPath}',
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const AppCachedImagePlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    Icon(PhosphorIcons.filmStrip()),
                              ),
                      ),
                      trailing: SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          value: countdown / 10,
                          strokeWidth: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            dismissed = true;
                            timer?.cancel();
                            Navigator.pop(dialogContext);
                          },
                          child: Text(tr('cancel')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => play(dialogContext),
                          icon: Icon(PhosphorIcons.play()),
                          label: Text(tr('play_now')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    dialog.then(
      (_) {
        debugPrint('[NextEpisodeDebug][countdown_closed]');
        dismissed = true;
        timer?.cancel();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '[NextEpisodeDebug][countdown_error] '
          'type=${error.runtimeType} error=$error',
        );
        debugPrintStack(
          label: '[NextEpisodeDebug][countdown_stack]',
          stackTrace: stackTrace,
        );
        dismissed = true;
        timer?.cancel();
      },
    );
  }

  TVStreamMetadata _metadataForEpisode(
    EpisodeMetadata episode,
    TVStreamMetadata current,
  ) {
    return TVStreamMetadata(
      elapsed: null,
      episodeId: episode.episodeId,
      episodeName: episode.episodeName,
      episodeNumber: episode.episodeNumber,
      posterPath: current.posterPath,
      backdropPath: episode.stillPath ?? current.backdropPath,
      seasonNumber: episode.seasonNumber,
      seriesName: current.seriesName,
      tvId: current.tvId,
      airDate: episode.airDate,
      seasonEpisodes: current.seasonEpisodes,
      allSeasons: current.allSeasons,
    );
  }
}
