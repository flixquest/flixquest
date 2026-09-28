import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/continue_watching.dart';
import '../../catalog/details_controller.dart';
import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../functions/function.dart';
import '../../models/tv.dart';
import '../../provider/recently_watched_provider.dart';
import '../../screens/tv/tv_episode_picker_sheet.dart';
import '../../screens/tv/tv_video_loader.dart';
import '../playback.dart';
import 'media_art.dart';
import 'pill_button.dart';

/// "S2:E4 · 23m left", "S2:E5 · Next episode", or "1h 04m left".
String continueSubtitle(MediaItem item) {
  final next = item.upNext;
  if (next != null) return '${next.label}  ·  ${tr('next_episode')}';
  final remaining =
      item.recentMovie?.remaining ?? item.recentEpisode?.remaining;
  final left = remaining != null && remaining > 0
      ? tr(
          'time_left',
          namedArgs: <String, String>{
            'time': formatRuntime(Duration(seconds: remaining)),
          },
        )
      : null;
  final season = item.recentEpisode?.seasonNum;
  final episode = item.recentEpisode?.episodeNum;
  return <String>[
    if (season != null && episode != null) 'S$season:E$episode',
    if (left != null) left,
  ].join('  ·  ');
}

/// What the main button says: "Play S2:E5" for a next episode, "Resume" for
/// one in progress.
String continueAction(MediaItem item) {
  final next = item.upNext;
  if (next != null) {
    return tr('play_episode',
        namedArgs: <String, String>{'episode': next.label});
  }
  return tr('resume_title');
}

/// A Continue Watching title's options, from its ⋮ or a long press: resume
/// it, pick an episode, open its details, or take it off the row (with Undo).
Future<void> showContinueSheet(BuildContext context, MediaItem item) {
  final palette = AppPalette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // Sized to its options, and scrolling when a short screen can't fit
    // them.
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (_) => _ContinueSheet(item: item, host: context),
  );
}

class _ContinueSheet extends StatelessWidget {
  const _ContinueSheet({required this.item, required this.host});

  final MediaItem item;

  /// The page the sheet opened over, which outlives the sheet: routes and
  /// the Undo snackbar go there.
  final BuildContext host;

  Future<void> _remove(BuildContext context) async {
    final recent = context.read<RecentProvider>();
    final messenger = ScaffoldMessenger.maybeOf(host);
    Navigator.of(context).pop();
    final undo = await removeFromContinueWatching(recent, item);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('removed_from_row')),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: tr('undo'), onPressed: undo),
        ),
      );
  }

  Future<void> _episodes(BuildContext context) async {
    Navigator.of(context).pop();
    final picked = await showTVEpisodePickerSheet(
      host,
      series: item.series ?? TV(id: item.id, name: item.title),
    );
    if (picked == null || !host.mounted) return;
    if (!await checkConnection() || !host.mounted) return;
    await Navigator.of(host).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TVVideoLoader(download: false, metadata: picked),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final progress = item.upNext == null ? item.progress ?? 0 : 0.0;
    final canPlay = MobilePlayback.canPlay(context);
    Widget option(IconData icon, String label, VoidCallback onTap) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(icon, color: palette.foreground),
          title: Text(
            label,
            style: AppType.body.copyWith(
              fontFamily: AppType.semiBold,
              fontSize: 15,
              color: palette.foreground,
            ),
          ),
          onTap: onTap,
        );
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: SizedBox(
                      width: 112,
                      height: 63,
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          MediaArt(
                            item: item,
                            path: item.backdropPath ?? item.posterPath,
                            width: 112,
                            size: item.backdropPath == null
                                ? null
                                : ArtSize.still,
                            placeholder: MediaArt.darkPlaceholder,
                          ),
                          if (progress > 0)
                            Align(
                              alignment: AlignmentDirectional.bottomStart,
                              child: FractionallySizedBox(
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(height: 3, color: accent),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sectionHeader.copyWith(
                            fontFamily: AppType.bold,
                            fontSize: 17,
                            color: palette.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          continueSubtitle(item),
                          style: AppType.metadata.copyWith(
                            color: palette.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canPlay)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: PillButton(
                  primary: true,
                  icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                  label: continueAction(item),
                  onPressed: () {
                    Navigator.of(context).pop();
                    MobilePlayback.play(host, item);
                  },
                ),
              ),
            if (item.kind == MediaKind.series && canPlay)
              option(
                PhosphorIcons.listNumbers(),
                tr('episodes'),
                () => _episodes(context),
              ),
            option(PhosphorIcons.info(), tr('details'), () {
              Navigator.of(context).pop();
              MobilePlayback.openDetails(host, item);
            }),
            option(
              PhosphorIcons.xCircle(),
              tr('remove_from_row'),
              () => _remove(context),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
  }
}
