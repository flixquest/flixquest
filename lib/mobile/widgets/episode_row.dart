import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/details_controller.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/skeleton.dart';
import '../../models/tv.dart';
import 'media_art.dart';
import 'page_kit.dart';
import 'pill_button.dart';

/// The parts every list of episodes is built from (a series' page, a
/// season's page, the episode picker), so an episode looks and behaves the
/// same wherever it's listed.

/// One episode: its still with a play mark and progress, "3. Title", the
/// runtime and air date, and its synopsis. Tapped, it plays; one not out yet
/// is dimmed, with the date it arrives.
class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    required this.series,
    required this.episode,
    required this.aired,
    required this.progress,
    required this.canPlay,
    required this.canDownload,
    required this.onPlay,
    this.onDownload,
    this.onOpen,
    super.key,
  });

  final MediaItem series;
  final EpisodeList episode;
  final bool aired;
  final double? progress;
  final bool canPlay;
  final bool canDownload;
  final VoidCallback onPlay;
  final VoidCallback? onDownload;

  /// The episode's own page; long press, or tap when it can't be played.
  final VoidCallback? onOpen;

  static const stillWidth = 132.0;

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
    final downloadable = canDownload && aired && onDownload != null;
    final row = InkWell(
      onTap: playable ? onPlay : onOpen,
      onLongPress: onOpen,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          gutter,
          AppSpace.md,
          downloadable ? gutter - AppSpace.sm : gutter,
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
                    width: stillWidth,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          MediaArt(
                            item: series,
                            path: episode.stillPath ?? series.backdropPath,
                            width: stillWidth,
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
                              child: EpisodeProgressBar(value: progress),
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
                if (downloadable)
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

/// Progress through an episode, along the bottom of its still.
class EpisodeProgressBar extends StatelessWidget {
  const EpisodeProgressBar({required this.value, super.key});

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

/// A list of episodes while it loads: [count] rows shaped like
/// [EpisodeRow]s.
class EpisodeListSkeleton extends StatelessWidget {
  const EpisodeListSkeleton({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpace.gutter(context);
    return SkeletonPulse(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Column(
          children: <Widget>[
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const SkeletonBlock(
                          width: EpisodeRow.stillWidth,
                          height: EpisodeRow.stillWidth * 9 / 16,
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              FractionallySizedBox(
                                widthFactor: i.isEven ? .8 : .6,
                                child: const SkeletonBlock.line(height: 14),
                              ),
                              const SizedBox(height: AppSpace.sm),
                              const SkeletonBlock.line(width: 90, height: 11),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    const SkeletonBlock.line(height: 11),
                    const SizedBox(height: 6),
                    const FractionallySizedBox(
                      widthFactor: .7,
                      child: SkeletonBlock.line(height: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A season's name: its own, else "Season 2".
String seasonDisplayName(Seasons season) {
  final name = season.name?.trim() ?? '';
  return name.isNotEmpty
      ? name
      : tr(
          'season_number',
          namedArgs: <String, String>{'number': '${season.seasonNumber}'},
        );
}

/// The seasons to choose from, [current] checked. Resolves to the season
/// number picked, or null.
Future<int?> showSeasonSheet(
  BuildContext context, {
  required List<Seasons> seasons,
  required int? current,
}) =>
    showAppSheet<int>(
      context,
      builder: (context) {
        final palette = AppPalette.of(context);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpace.lg,
            ),
            children: <Widget>[
              for (final season in seasons)
                Semantics(
                  selected: season.seasonNumber == current,
                  child: ListRow(
                    label: seasonDisplayName(season),
                    subtitle: season.episodeCount == null
                        ? null
                        : tr(
                            'episodes_count',
                            namedArgs: <String, String>{
                              'count': '${season.episodeCount}',
                            },
                          ),
                    showsNext: false,
                    trailing: season.seasonNumber == current
                        ? Icon(
                            PhosphorIcons.check(PhosphorIconsStyle.bold),
                            size: 18,
                            color: palette.foreground,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(season.seasonNumber),
                  ),
                ),
            ],
          ),
        );
      },
    );
