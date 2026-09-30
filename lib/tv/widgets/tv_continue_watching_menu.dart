import 'package:flutter/material.dart';

export '../../catalog/continue_watching.dart';

import '../../catalog/continue_watching.dart';
import '../models/tv_media_item.dart';
import 'tv_dialog.dart';

/// The TV's name for the shared removal, in lib/catalog/.
typedef TvContinueWatchingRemoval = ContinueWatchingRemoval;

/// Asks before dropping [item] from the Continue watching row.
///
/// A remote's held OK is easier to hit by accident than a touch long press, and
/// the removal is not undoable, so this stands between the two.
Future<bool> confirmRemoveFromContinueWatching({
  required BuildContext context,
  required TvMediaItem item,
}) async {
  final confirmed = await showTvDialog<bool>(
    context: context,
    title: 'Remove from Continue watching?',
    content: Text(
      '"${item.title}" stops showing up in Continue watching, and its '
      'playback position is discarded.',
    ),
    actions: <TvDialogAction>[
      TvDialogAction(
        label: 'Remove',
        isPrimary: true,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      // The safe action takes focus: someone who only meant to resume playback
      // and held OK a beat too long should not land on a destructive default.
      TvDialogAction(
        label: 'Cancel',
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
  return confirmed == true;
}
