import 'package:flutter/material.dart';

import '../catalog/media_item.dart';

/// A card's corner label: small white capitals on a dark plate, legible over
/// any poster without competing with the accent colour.
class MediaBadge extends StatelessWidget {
  const MediaBadge({required this.label, super.key});

  static const top10 = 'TOP 10';
  static const newEpisodes = 'NEW EPISODES';
  static const recent = 'NEW';

  /// How long after release a title still counts as new.
  static const recentWindow = Duration(days: 30);

  final String label;

  /// [recent] for a title released (or, for a series, first aired) within
  /// [recentWindow] of [now]; nothing for older or upcoming titles.
  static String? recencyOf(MediaItem item, {DateTime? now}) {
    final released = DateTime.tryParse(item.releaseDate ?? '');
    if (released == null) return null;
    final today = now ?? DateTime.now();
    if (released.isAfter(today)) return null;
    return today.difference(released) <= recentWindow ? recent : null;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xd9050606),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 5, 3),
        // Shrinks rather than clips when a label (or a longer language)
        // is wider than a narrow poster.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              // On its dark plate over the poster, in every theme.
              color: Color(0xfff7f7f7),
              fontFamily: 'FigtreeBold',
              fontSize: 11,
              height: 1.1,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
