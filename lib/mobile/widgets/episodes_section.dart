import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/details_play.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/recently_watched.dart';
import '../../models/tv.dart';
import 'details_parts.dart';
import 'episode_row.dart';
import 'filter_chips.dart';

typedef EpisodeAction = void Function(
  EpisodeList episode,
  List<EpisodeList> seasonEpisodes,
);

/// A series' episodes, one season at a time: the season in a pill that
/// opens the list of seasons, then each episode with its still, runtime and
/// air date. The episode in progress shows how far in it is; episodes not
/// out yet are dimmed with the date they arrive.
class EpisodesSection extends StatefulWidget {
  const EpisodesSection({
    required this.series,
    required this.seasons,
    required this.initialSeason,
    required this.loadSeason,
    required this.watched,
    required this.canPlay,
    required this.canDownload,
    required this.onPlay,
    required this.onDownload,
    required this.onOpen,
    required this.onSeasonInfo,
    this.now,
    super.key,
  });

  final MediaItem series;

  /// In the order offered: regular seasons, then specials.
  final List<Seasons> seasons;
  final int? initialSeason;
  final Future<List<EpisodeList>> Function(int seasonNumber) loadSeason;

  /// Episodes the viewer has started, for their progress bars.
  final List<RecentEpisode> watched;
  final bool canPlay;
  final bool canDownload;
  final EpisodeAction onPlay;
  final void Function(EpisodeList episode) onDownload;

  /// The episode's own page, with its cast and images.
  final EpisodeAction onOpen;

  /// The season's own page.
  final void Function(Seasons season) onSeasonInfo;
  final DateTime Function()? now;

  @override
  State<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends State<EpisodesSection> {
  late int? _season = widget.initialSeason;
  final Map<int, Future<List<EpisodeList>>> _episodes =
      <int, Future<List<EpisodeList>>>{};

  Seasons? get _current => widget.seasons
      .where((season) => season.seasonNumber == _season)
      .firstOrNull;

  Future<List<EpisodeList>> _load(int season, {bool retry = false}) {
    if (retry) _episodes.remove(season);
    return _episodes.putIfAbsent(season, () => widget.loadSeason(season));
  }

  Future<void> _pickSeason() async {
    final picked = await showSeasonSheet(
      context,
      seasons: widget.seasons,
      current: _season,
    );
    if (picked != null && mounted) setState(() => _season = picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final current = _current;
    final season = _season;
    if (current == null || season == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          // Side by side when they fit; the link drops under the pill on a
          // narrow screen or with large text.
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: ChoicePill(
                      spec: FilterChipSpec(
                        label: seasonDisplayName(current),
                        dropdown: widget.seasons.length > 1,
                        onTap: widget.seasons.length > 1 ? _pickSeason : () {},
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: palette.mutedText,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => widget.onSeasonInfo(current),
                  child: Text(
                    tr('about_season'),
                    style: AppType.metadata.copyWith(color: palette.mutedText),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        FutureBuilder<List<EpisodeList>>(
          key: ValueKey<int>(season),
          future: _load(season),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const EpisodeListSkeleton();
            }
            if (snapshot.hasError) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: DetailsMessage(
                  message: tr('episodes_load_failed'),
                  onRetry: () => setState(() => _load(season, retry: true)),
                ),
              );
            }
            final episodes = snapshot.data ?? const <EpisodeList>[];
            if (episodes.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
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
                      widget.watched,
                      seriesId: widget.series.id,
                      season: episode.seasonNumber ?? season,
                      episode: episode.episodeNumber ?? -1,
                    ),
                    canPlay: widget.canPlay,
                    canDownload: widget.canDownload,
                    onPlay: () => widget.onPlay(episode, episodes),
                    onDownload: () => widget.onDownload(episode),
                    onOpen: () => widget.onOpen(episode, episodes),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
