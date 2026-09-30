import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/media_badge.dart';
import '../playback.dart';
import 'media_art.dart';
import 'title_sheet.dart';

/// What a screen reader says for a card: "Dune, 2024, movie, 7.6 rating".
String mediaSemanticLabel(MediaItem item) => <String>[
      item.title,
      if (item.year case final year?) year,
      tr(item.kind == MediaKind.movie ? 'movie' : 'series_one'),
      if (item.rating case final rating? when rating > 0)
        '${rating.toStringAsFixed(1)} ★',
    ].join(', ');

/// Something a thumb can press: it sinks a touch while held, and a long press
/// gives a light tick.
class Pressable extends StatefulWidget {
  const Pressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _press(bool down) {
    if (down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final onLongPress = widget.onLongPress;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onLongPressHint: onLongPress == null ? null : tr('details'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        onLongPress: onLongPress == null
            ? null
            : () {
                _press(false);
                HapticFeedback.lightImpact();
                onLongPress();
              },
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A 2:3 poster on a browse row: artwork only, with a corner badge.
/// Tap opens details; a long press offers Play, My List and Details.
class PosterCard extends StatelessWidget {
  const PosterCard({
    required this.item,
    required this.width,
    this.badge,
    this.onTap,
    super.key,
  });

  final MediaItem item;
  final double width;
  final String? badge;
  final VoidCallback? onTap;

  static const aspectRatio = 2 / 3;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final badge = this.badge;
    return Pressable(
      semanticLabel: mediaSemanticLabel(item),
      onTap: onTap ?? () => MobilePlayback.openDetails(context, item),
      onLongPress: () => showTitleSheet(context, item),
      child: SizedBox(
        width: width,
        height: width / aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MediaArt(
                item: item,
                path: item.posterPath ?? item.backdropPath,
                width: width,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: palette.hairline, width: .5),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              ),
              if (badge != null)
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  end: 6,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: MediaBadge(label: badge),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
