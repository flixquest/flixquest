import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/details_play.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../models/recently_watched.dart';
import '../../models/tv.dart';
import 'details_parts.dart';
import 'filter_chips.dart';
import 'media_art.dart';
import 'pill_button.dart';

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

  String _seasonName(Seasons season) {
    final name = season.name?.trim() ?? '';
    return name.isNotEmpty
        ? name
        : tr('season_number', namedArgs: <String, String>{
            'number': '${season.seasonNumber}',
          });
  }

  Future<void> _pickSeason() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SeasonSheet(
        seasons: widget.seasons,
        current: _season,
        nameOf: _seasonName,
      ),
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
                        label: _seasonName(current),
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
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: const Column(
                  children: <Widget>[
                    _EpisodeSkeleton(),
                    _EpisodeSkeleton(),
                    _EpisodeSkeleton(),
                  ],
                ),
              );
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
                  _EpisodeRow(
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

class _SeasonSheet extends StatelessWidget {
  const _SeasonSheet({
    required this.seasons,
    required this.current,
    required this.nameOf,
  });

  final List<Seasons> seasons;
  final int? current;
  final String Function(Seasons season) nameOf;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          children: <Widget>[
            for (final season in seasons)
              ListTile(
                selected: season.seasonNumber == current,
                onTap: () => Navigator.of(context).pop(season.seasonNumber),
                title: Text(
                  nameOf(season),
                  style: AppType.cardTitle.copyWith(
                    color: palette.foreground,
                    fontSize: 16,
                  ),
                ),
                subtitle: season.episodeCount == null
                    ? null
                    : Text(
                        tr('episodes_count', namedArgs: <String, String>{
                          'count': '${season.episodeCount}',
                        }),
                        style:
                            AppType.metadata.copyWith(color: palette.mutedText),
                      ),
                trailing: season.seasonNumber == current
                    ? Icon(PhosphorIcons.check(), color: palette.foreground)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.series,
    required this.episode,
    required this.aired,
    required this.progress,
    required this.canPlay,
    required this.canDownload,
    required this.onPlay,
    required this.onDownload,
    required this.onOpen,
  });

  final MediaItem series;
  final EpisodeList episode;
  final bool aired;
  final double? progress;
  final bool canPlay;
  final bool canDownload;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onOpen;

  static const _stillWidth = 132.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final locale = Localizations.localeOf(context).toString();
    final airDate = DateTime.tryParse(episode.airDate ?? '');
    final runtime = episode.runtime;
    final playable = aired && canPlay;
    final number = episode.episodeNumber;
    final title = episode.name?.trim() ?? '';
    final facts = aired
        ? <String>[
            if (runtime != null && runtime > 0)
              formatRuntime(Duration(minutes: runtime)),
            if (airDate != null) DateFormat.yMMMd(locale).format(airDate),
          ].join(' · ')
        : airDate == null
            ? tr('coming_soon')
            : tr('coming_date', namedArgs: <String, String>{
                'date': DateFormat.MMMd(locale).format(airDate),
              });
    final progress = this.progress;
    final row = InkWell(
      onTap: playable ? onPlay : onOpen,
      onLongPress: onOpen,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          gutter,
          AppSpace.md,
          canDownload && aired ? gutter - AppSpace.sm : gutter,
          AppSpace.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: SizedBox(
                    width: _stillWidth,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          MediaArt(
                            item: series,
                            path: episode.stillPath ?? series.backdropPath,
                            width: _stillWidth,
                            size: 'w300/',
                            placeholder: MediaArt.darkPlaceholder,
                          ),
                          if (playable)
                            Center(
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0x73000000),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xD9FFFFFF),
                                    width: 1.5,
                                  ),
                                ),
                                child: PlaybackIcon(
                                  PhosphorIcons.play(PhosphorIconsStyle.fill),
                                  size: 16,
                                  color: const Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                          if (progress != null)
                            PositionedDirectional(
                              start: 0,
                              end: 0,
                              bottom: 0,
                              child: _Progress(value: progress),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        number == null || title.isEmpty
                            ? (title.isEmpty ? '$number' : title)
                            : '$number. $title',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle
                            .copyWith(color: palette.foreground),
                      ),
                      if (facts.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          facts,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.metadata
                              .copyWith(color: palette.mutedText),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canDownload && aired)
                  IconButton(
                    tooltip: tr('download_episode'),
                    color: palette.foreground,
                    onPressed: onDownload,
                    icon: Icon(PhosphorIcons.downloadSimple(), size: 22),
                  ),
              ],
            ),
            if ((episode.overview ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpace.sm),
              Text(
                episode.overview!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(color: palette.secondaryText),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      label: number == null ? title : '$number. $title',
      // Not out yet: shown, but quieter.
      child: aired ? row : Opacity(opacity: .5, child: row),
    );
  }
}

/// Progress through an episode, along the bottom of its still.
class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: Color(0x3DFFFFFF)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      );
}

class _EpisodeSkeleton extends StatelessWidget {
  const _EpisodeSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(
          children: <Widget>[
            DetailsBlock(width: _EpisodeRow._stillWidth, height: 74),
            SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DetailsBlock(width: 150, height: 16),
                  SizedBox(height: AppSpace.sm),
                  DetailsBlock(width: 90, height: 12),
                ],
              ),
            ),
          ],
        ),
      );
}
