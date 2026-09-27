import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../my_list.dart';
import '../playback.dart';
import 'media_art.dart';
import 'pill_button.dart';

/// "2024 · Movie · ★ 7.6": what a title is, in one short line.
String mediaFacts(MediaItem item) => <String>[
      if (item.year case final year?) year,
      tr(item.kind == MediaKind.movie ? 'movie' : 'series_one'),
      if (item.rating case final rating? when rating > 0)
        '★ ${rating.toStringAsFixed(1)}',
    ].join('  ·  ');

/// A title's quick actions, from a long press on its card: Play, My List and
/// Details, under its poster and synopsis.
Future<void> showTitleSheet(BuildContext context, MediaItem item) {
  final palette = AppPalette.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    builder: (sheetContext) => _TitleSheet(item: item, host: context),
  );
}

class _TitleSheet extends StatelessWidget {
  const _TitleSheet({required this.item, required this.host});

  final MediaItem item;

  /// The page the sheet opened over, which outlives the sheet and so is
  /// where routes are pushed from.
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final saved = MyList.contains(context, item);
    void close() => Navigator.of(context).pop();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: SizedBox(
                    width: 84,
                    height: 126,
                    child: MediaArt(
                      item: item,
                      path: item.posterPath ?? item.backdropPath,
                      width: 84,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.lg),
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
                          color: palette.foreground,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        mediaFacts(item),
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                      if (item.overview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          item.overview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(
                            color: palette.secondaryText,
                            fontSize: 13,
                            height: 18 / 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            Row(
              children: <Widget>[
                if (MobilePlayback.canPlay(context)) ...<Widget>[
                  Expanded(
                    child: PillButton(
                      primary: true,
                      icon: PhosphorIcons.play(PhosphorIconsStyle.fill),
                      label: tr('play'),
                      onPressed: () {
                        close();
                        MobilePlayback.play(host, item);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                ],
                Expanded(
                  child: PillButton(
                    icon: saved ? PhosphorIcons.check() : PhosphorIcons.plus(),
                    label: tr('my_list'),
                    onPressed: () => MyList.toggle(context, item),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: PillButton(
                    icon: PhosphorIcons.info(),
                    label: tr('details'),
                    onPressed: () {
                      close();
                      MobilePlayback.openDetails(host, item);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
